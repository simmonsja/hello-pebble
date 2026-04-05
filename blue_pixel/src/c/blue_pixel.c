#include <pebble.h>

static Window *s_window;
static TextLayer *s_time_layer;
static GBitmap *s_bitmap;
static GBitmap *s_day_bitmap;
static GBitmap *s_night_bitmap;
static BitmapLayer *s_bitmap_layer;

static void prv_select_click_handler(ClickRecognizerRef recognizer, void *context) {
    text_layer_set_text(s_time_layer, "Select");
}

static void prv_up_click_handler(ClickRecognizerRef recognizer, void *context) {
    text_layer_set_text(s_time_layer, "Up");
}

static void prv_down_click_handler(ClickRecognizerRef recognizer, void *context) {
    text_layer_set_text(s_time_layer, "Down");
}

static void prv_click_config_provider(void *context) {
    window_single_click_subscribe(BUTTON_ID_SELECT, prv_select_click_handler);
    window_single_click_subscribe(BUTTON_ID_UP, prv_up_click_handler);
    window_single_click_subscribe(BUTTON_ID_DOWN, prv_down_click_handler);
}

static void update_background_image(struct tm *tick_time) {
    // It is my understanding that the palette bitmap types allow you to have x many colours from the palette. So 2BitPalette allows for 4 colours.
    // check if day_bitmap and night_bitmap are already loaded, if not load them
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Updating background image for time: %d:%d", tick_time->tm_hour, tick_time->tm_min);
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory START: Free=%lu Used=%lu", 
            (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());
    
    if (s_day_bitmap == NULL) {
        s_day_bitmap = gbitmap_create_with_resource(RESOURCE_ID_BLUE_MARBLE);
    }
    if (s_night_bitmap == NULL) {
        s_night_bitmap = gbitmap_create_with_resource(RESOURCE_ID_BLACK_MARBLE);
    }

    // Switching example
    // // The background image will be based on the time of day, for 7pm-7am we will show RESOURCE_ID_BLUE_MARBLE and for 7am-7pm we will show RESOURCE_ID_BLUE_MARBLE
    // // if (tick_time->tm_hour >= 19 || tick_time->tm_hour < 7) {
    // // debug: we'll switch the background every minute instead of every 12 hours
    // if (tick_time->tm_min % 2) {
    //     APP_LOG(APP_LOG_LEVEL_DEBUG, "It's night time, using night bitmap");
    //     // Load the bitmap resource as GBitmap
    //     s_bitmap = s_night_bitmap;
    // } else {
    //     APP_LOG(APP_LOG_LEVEL_DEBUG, "It's day time, using day bitmap");
    //     s_bitmap = s_day_bitmap;
    // }

    // Knitting example - combine day and night bitmaps
    // create a copy of day then modify
    uint8_t *night_data = gbitmap_get_data(s_night_bitmap);
    unsigned int bytes_per_row = gbitmap_get_bytes_per_row(s_day_bitmap);
    GRect bounds = gbitmap_get_bounds(s_day_bitmap);
    unsigned int rows = bounds.size.h;
    unsigned int cols = bounds.size.w;

    // Before creating new bitmap, destroy the old one
    if (s_bitmap != NULL && s_bitmap != s_day_bitmap && s_bitmap != s_night_bitmap) {
        gbitmap_destroy(s_bitmap);
        s_bitmap = NULL;
    }

    uint8_t *comb_data = malloc(bytes_per_row * rows);
    memcpy(comb_data, gbitmap_get_data(s_day_bitmap), bytes_per_row * rows);

    APP_LOG(APP_LOG_LEVEL_DEBUG, "Bitmap dimensions: %d cols x %d rows, bytes per row: %d", cols, rows, bytes_per_row);

    for (unsigned int ii = 0; ii < rows; ii++) {
        unsigned int row_byte_num = ii * bytes_per_row;
        for (unsigned int jj = 0; jj < cols; jj++) {
            if (jj > cols/2) {
                // for a 2Bit palette, each pixel is represented by 2 bits, so we need to calculate the correct location
                unsigned int byte_index = row_byte_num + (jj / 4); // Calculate the byte index for the current pixel
                comb_data[byte_index] = night_data[byte_index];
            }
        }
    }
        
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory merged: Free=%lu Used=%lu", 
            (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());

    // create blank bitmap
    s_bitmap = gbitmap_create_blank(bounds.size, gbitmap_get_format(s_day_bitmap));
    // copy the combined data into the new bitmap
    gbitmap_set_data(s_bitmap, comb_data, gbitmap_get_format(s_day_bitmap), bytes_per_row, true);
    free(comb_data);
        
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory assigned: Free=%lu Used=%lu", 
            (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());
    APP_LOG(APP_LOG_LEVEL_DEBUG, "I am about to set the bitmap on the layer");
    bitmap_layer_set_bitmap(s_bitmap_layer, s_bitmap);
    APP_LOG(APP_LOG_LEVEL_DEBUG, "I have set the bitmap on the layer");
    
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Memory END: Free=%lu Used=%lu", 
            (unsigned long)heap_bytes_free(), (unsigned long)heap_bytes_used());
}

static void update_time(bool force_bgd_update) {
    // Get a time structure
    time_t temp = time(NULL);
    struct tm *tick_time = localtime(&temp);
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Tick time: %d:%d:%d", tick_time->tm_hour, tick_time->tm_min, tick_time->tm_sec);

    // Get the current hours and minutes from tick_time
    static char s_time_buffer[8];
    strftime(s_time_buffer, sizeof(s_time_buffer), clock_is_24h_style() ? "%H:%M" : "%I:%M", tick_time);
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Formatted time: %s", s_time_buffer);

    // // Display this time on the created TextLayer
    text_layer_set_text(s_time_layer, s_time_buffer);

    // If the time is on the hour or half past
    if (tick_time->tm_min == 0 || tick_time->tm_min == 30 || force_bgd_update) {
        // Update the background image based on the time of day
        update_background_image(tick_time);
    }
}

static void tick_handler(struct tm *tick_time, TimeUnits units_changed) {
    // debug: set true
    update_time(true);
}

static void prv_window_load(Window *window) {
    // Get the root layer and its bounds for 
    Layer *window_layer = window_get_root_layer(window);
    GRect bounds = layer_get_bounds(window_layer);

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
    s_bitmap_layer = bitmap_layer_create(GRect(0, 0, 260, 260));//bounds.size.w, bounds.size.h)); // Gabbro 260, 260));
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
    window_set_click_config_provider(s_window, prv_click_config_provider);
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

    APP_LOG(APP_LOG_LEVEL_DEBUG, "Done initializing, pushed window: %p", s_window);

    app_event_loop();
    prv_deinit();
}
