#include <pebble.h>

static Window *s_window;
static TextLayer *s_time_layer;
static GBitmap *s_bitmap;
static GBitmap *s_day_bitmap;
static GBitmap *s_night_bitmap;
static BitmapLayer *s_bitmap_layer;
static bool s_palettes_combined = false;

static void update_background_image(struct tm *utc_time) {
    // It is my understanding that the palette bitmap types allow you to have x many colours from the palette. So 2BitPalette allows for 4 colours.
    // check if day_bitmap and night_bitmap are already loaded, if not load them
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Updating background image for time: %d:%d", utc_time->tm_hour, utc_time->tm_min);
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory START: Free=%lu Used=%lu", 
    //         (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());
    
    if (s_day_bitmap == NULL) {
        s_day_bitmap = gbitmap_create_with_resource(RESOURCE_ID_BLUE_MARBLE);
        s_palettes_combined = false; // reset this flag whenever we load new bitmaps to ensure palettes are combined correctly
    }
    if (s_night_bitmap == NULL) {
        s_night_bitmap = gbitmap_create_with_resource(RESOURCE_ID_BLACK_MARBLE);
        s_palettes_combined = false;
    }

    // Print the palette colours
    int n_colours_per_palette = 8;
    GColor *day_palette = gbitmap_get_palette(s_day_bitmap);

    if (!s_palettes_combined) {
        // Only combine if we are reloading the bitmaps otherwise we garble the palette
        GColor *night_palette = gbitmap_get_palette(s_night_bitmap);
        // combine the two palettes
        for (int i = 0; i < n_colours_per_palette; i++) {
            day_palette[i+n_colours_per_palette] = night_palette[i];
        }

        // logging
        // APP_LOG(APP_LOG_LEVEL_DEBUG, "Day bitmap palette:");
        // for (int i = 0; i < n_colours_per_palette; i++) {
        //     GColor color = day_palette[i];
        //     APP_LOG(APP_LOG_LEVEL_DEBUG, "Color %d: R=%d G=%d B=%d A=%d", i, color.r, color.g, color.b, color.a);
        // }
        // APP_LOG(APP_LOG_LEVEL_DEBUG, "Night bitmap palette:");
        // for (int i = 0; i < n_colours_per_palette; i++) {
        //     GColor color = night_palette[i];
        //     APP_LOG(APP_LOG_LEVEL_DEBUG, "Color %d: R=%d G=%d B=%d A=%d", i, color.r, color.g, color.b, color.a);
        // }
        // APP_LOG(APP_LOG_LEVEL_DEBUG, "Combined bitmap palette:");
        // for (int i = 0; i < n_colours_per_palette*2; i++) {
        //     GColor color = day_palette[i];
        //     APP_LOG(APP_LOG_LEVEL_DEBUG, "Color %d: R=%d G=%d B=%d A=%d", i, color.r, color.g, color.b, color.a);
        // }

        gbitmap_set_palette(s_day_bitmap, day_palette, false);
        gbitmap_set_palette(s_night_bitmap, day_palette, false);
        s_palettes_combined = true;
    }

    // Knitting - combine day and night bitmaps
    // create a copy of day then modify
    uint8_t *night_data = gbitmap_get_data(s_night_bitmap);
    unsigned int bytes_per_row = gbitmap_get_bytes_per_row(s_day_bitmap);
    GRect bounds = gbitmap_get_bounds(s_day_bitmap);
    unsigned int rows = bounds.size.h;
    unsigned int cols = bounds.size.w;

    // Before creating new bitmap, destroy the old one
    if (s_bitmap != NULL) {
        gbitmap_destroy(s_bitmap);
        s_bitmap = NULL;
    }

    // Create the blank bitmap first and use its internal buffer directly to avoid malloc/free issues
    s_bitmap = gbitmap_create_blank(bounds.size, gbitmap_get_format(s_day_bitmap));
    uint8_t *comb_data = gbitmap_get_data(s_bitmap);
    memcpy(comb_data, gbitmap_get_data(s_day_bitmap), bytes_per_row * rows);

    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Bitmap dimensions: %d cols x %d rows, bytes per row: %d", cols, rows, bytes_per_row);

    // Get pregenerated limits array
    ResHandle handle = resource_get_handle(RESOURCE_ID_LIMITS);
    // Limits binary stores every other row (half the display rows) with 3 limit columns
    unsigned int stored_rows = (rows + 1) / 2;  // ceil(rows/2) = 84 for 168
    size_t block_size_bytes = stored_rows * 3 * sizeof(uint8_t);
    uint8_t *s_buffer = (uint8_t*)malloc(block_size_bytes);

    // time_idx: 0-based half-hour index (0..47)
    int time_idx = utc_time->tm_hour * 2 + (utc_time->tm_min >= 30 ? 1 : 0);
    // month: 0-based (tm_mon is already 0-based in C)
    int month = utc_time->tm_mon;
    int block_index = time_idx * 12 + month;
    int byte_offset = block_index * (int)block_size_bytes;
    resource_load_byte_range(handle, byte_offset, (uint8_t*)s_buffer, block_size_bytes);
    // s_buffer layout: [left × stored_rows] [right × stored_rows] [left2 × stored_rows]

    for (unsigned int ii = 0; ii < rows; ii++) {
        unsigned int row_byte_num = ii * bytes_per_row;
        unsigned int stored_row = ii / 2;  // nearest-neighbor: map display row to stored row
        unsigned int left_limit = s_buffer[stored_row];
        unsigned int right_limit = s_buffer[stored_row + stored_rows];
        unsigned int left2_limit = s_buffer[stored_row + 2 * stored_rows];

        for (unsigned int jj = 0; jj < bytes_per_row; jj++) {
            unsigned int px_left = jj * 2;
            unsigned int px_right = jj * 2 + 1;

            // Determine if each pixel in this byte is night
            // Day if: (px >= left && px <= right) || (left2 <= max_col && px >= left2)
            // Night otherwise. left > right means all-night row.
            bool px1_night = true;
            bool px2_night = true;

            // Check primary daylight block (left..right)
            if (left_limit <= right_limit) {
                if (px_left >= left_limit && px_left <= right_limit) px1_night = false;
                if (px_right >= left_limit && px_right <= right_limit) px2_night = false;
            }

            // Check secondary daylight block (left2..end of available pixels)
            // left2 > right_limit signals no second block (sentinel)
            // but we also need left2 to be a valid column
            if (left2_limit > left_limit && left2_limit <= right_limit) {
                // left2 is within the primary block - not a valid second block
            } else if (left2_limit > 0 && left2_limit < cols) {
                // Valid second block from left2 to end of available pixels in row
                if (px_left >= left2_limit) px1_night = false;
                if (px_right >= left2_limit) px2_night = false;
            }

            if (px1_night || px2_night) {
                uint8_t byte_value = night_data[row_byte_num + jj];
                uint8_t pixel1 = (byte_value >> 4) & 0x0F;
                uint8_t pixel2 = byte_value & 0x0F;

                if (px1_night) pixel1 += n_colours_per_palette;
                if (px2_night) pixel2 += n_colours_per_palette;

                comb_data[row_byte_num + jj] = (pixel1 << 4) | pixel2;
            }
        }
    }
   
    // Free the buffer after use
    if (s_buffer) {
        free(s_buffer);
    }
        
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory merged: Free=%lu Used=%lu", 
    //         (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());

    // set the palette on the already-created bitmap
    gbitmap_set_palette(s_bitmap, day_palette, false);
        
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory assigned: Free=%lu Used=%lu", 
    //         (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "I am about to set the bitmap on the layer");
    bitmap_layer_set_bitmap(s_bitmap_layer, s_bitmap);
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "I have set the bitmap on the layer");
    
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory END: Free=%lu Used=%lu", 
    //         (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());
}

static void update_time(bool force_bgd_update) {
    // Get a time structure
    time_t temp = time(NULL);
    struct tm *tick_time = localtime(&temp);
    struct tm *utc_time = gmtime(&temp);
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Tick time: %d:%d:%d", tick_time->tm_hour, tick_time->tm_min, tick_time->tm_sec);

    // Get the current hours and minutes from tick_time
    static char s_time_buffer[8];
    strftime(s_time_buffer, sizeof(s_time_buffer), clock_is_24h_style() ? "%H:%M" : "%I:%M", tick_time);
    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Formatted time: %s", s_time_buffer);

    // // Display this time on the created TextLayer
    text_layer_set_text(s_time_layer, s_time_buffer);

    // If the time is on the hour or half past
    if (tick_time->tm_min == 0 || tick_time->tm_min == 30 || force_bgd_update) {
        // Update the background image based on the time of day
        update_background_image(utc_time);
    }
}

static void tick_handler(struct tm *tick_time, TimeUnits units_changed) {
    update_time(false);
}

static void prv_window_load(Window *window) {
    // Get the root layer and its bounds for 
    Layer *window_layer = window_get_root_layer(window);
    GRect bounds = layer_get_bounds(window_layer);

    window_set_background_color(window, GColorBlack);

    // Display the time GRect (xul,yul, width, height)
    const int layer_height = 42;
    const int text_padding_buffer = 10;
    s_time_layer = text_layer_create(GRect(0, bounds.size.h/2 - layer_height/2 - text_padding_buffer, bounds.size.w, layer_height));
    // // Style the TextLayer
    text_layer_set_background_color(s_time_layer, GColorClear);//GColorFromRGBA(0, 0, 0, 85)); // Semi-transparent white background
    text_layer_set_text_color(s_time_layer, GColorWhite);
    text_layer_set_font(s_time_layer, fonts_get_system_font(FONT_KEY_BITHAM_42_BOLD));
    text_layer_set_text_alignment(s_time_layer, GTextAlignmentCenter);

    // Create a layer to display the GBitmap
    s_bitmap_layer = bitmap_layer_create(GRect(0, 0, bounds.size.w, bounds.size.h));//)); // Gabbro 260, 260));
    bitmap_layer_set_compositing_mode(s_bitmap_layer, GCompOpSet);
    // // Link the GBitmap to the BitmapLayer
    // bitmap_layer_set_bitmap(s_bitmap_layer, s_bitmap);
    // Add the BitmapLayer to the window's root layer
    layer_add_child(window_get_root_layer(window), bitmap_layer_get_layer(s_bitmap_layer));

    // Update the time immediately when the window loads
    update_time(true);

    // Add the TextLayer to the window's root layer
    layer_add_child(window_layer, text_layer_get_layer(s_time_layer));
}

static void prv_window_unload(Window *window) {
    text_layer_destroy(s_time_layer);
}

static void prv_init(void) {
    // Entry point: create the main window and set up handlers
    s_window = window_create();
    // window_set_click_config_provider(s_window, prv_click_config_provider);
    window_set_window_handlers(s_window, (WindowHandlers) {
        .load = prv_window_load,
        .unload = prv_window_unload,
    });
    
    // Time
    // Register with TickTimerService - MINUTE_UNIT means we'll get a callback every minute
    tick_timer_service_subscribe(MINUTE_UNIT, tick_handler);

    // Show the Window on the watch, with animated=true
    const bool animated = true;
    window_stack_push(s_window, animated);
}

static void prv_deinit(void) {
    // Destroy the Window to free resources
    window_destroy(s_window);
    // Clean up the GBitmap and BitmapLayer resources
    bitmap_layer_destroy(s_bitmap_layer);
    if (s_day_bitmap) {
        gbitmap_destroy(s_day_bitmap);
    }
    if (s_night_bitmap) {
        gbitmap_destroy(s_night_bitmap);
    }
}

int main(void) {
    prv_init();

    // APP_LOG(APP_LOG_LEVEL_DEBUG, "Done initializing, pushed window: %p", s_window);

    app_event_loop();
    prv_deinit();
}
