#include <pebble.h>

static Window *s_window;
static TextLayer *s_time_layer;
static GBitmap *s_bitmap;
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

static void prv_window_load(Window *window) {
  // Get the root layer and its bounds for 
  Layer *window_layer = window_get_root_layer(window);
  GRect bounds = layer_get_bounds(window_layer);

  // Load the bitmap resource as GBitmap
  s_bitmap = gbitmap_create_with_resource(RESOURCE_ID_BLUE_MARBLE);
  // Create a layer to display the GBitmap
  s_bitmap_layer = bitmap_layer_create(GRect(0, 0, 260, 260));//bounds.size.w, bounds.size.h)); // Gabbro 260, 260));
  bitmap_layer_set_compositing_mode(s_bitmap_layer, GCompOpSet);
  // Link the GBitmap to the BitmapLayer
  bitmap_layer_set_bitmap(s_bitmap_layer, s_bitmap);
  // Add the BitmapLayer to the window's root layer
  layer_add_child(window_get_root_layer(window), bitmap_layer_get_layer(s_bitmap_layer));

  // Display the time
  s_time_layer = text_layer_create(GRect(0, 72, bounds.size.w, 20));
  // // Style the TextLayer
  // text_layer_set_background_color(s_time_layer, GColorClear);
  // text_layer_set_text_color(s_time_layer, GColorWhite);
  // // text_layer_set_font(s_time_layer, fonts_get_system_font(FONT_KEY_BIHAM_42_BOLD));
  // text_layer_set_text_alignment(s_time_layer, GTextAlignmentCenter);
  // Add the TextLayer to the window's root layer
  layer_add_child(window_layer, text_layer_get_layer(s_time_layer));
}

static void update_time() {
  // // Get a time structure
  // time_t temp = time(NULL);
  // struct tm *tick_time = localtime(&temp);

  // // Get the current hours and minutes from tick_time
  // static char s_time_buffer[8];
  // strftime(s_time_buffer, sizeof(s_time_buffer), clock_is_24h_style() ? "%H:%M" : "%I:%M", tick_time);

  // // Display this time on the created TextLayer
  // text_layer_set_text(s_time_layer, s_time_buffer);
}

static void tick_handler(struct tm *tick_time, TimeUnits units_changed) {
  update_time();
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
  
  // // Time
  // // Make sure the time is displayed from the start
  // update_time();
  // // Register with TickTimerService - MINUTE_UNIT means we'll get a callback every minute
  // tick_timer_service_subscribe(MINUTE_UNIT, tick_handler);

  // Show the Window on the watch, with animated=true
  const bool animated = true;
  window_stack_push(s_window, animated);
}

static void prv_deinit(void) {
  // Destroy the Window to free resources
  window_destroy(s_window);
  // Clean up the GBitmap and BitmapLayer resources
  gbitmap_destroy(s_bitmap);
  bitmap_layer_destroy(s_bitmap_layer);
}

int main(void) {
  prv_init();

  APP_LOG(APP_LOG_LEVEL_DEBUG, "Done initializing, pushed window: %p", s_window);

  app_event_loop();
  prv_deinit();
}
