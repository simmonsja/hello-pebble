# Blue Pebble

This project aims to create a pebble watch face from a pixel art earth (inspired by blue marble and now hello, world) that is reactive to sun position and illumination. The idea is a geostationary view of the earth where the pixels are gradually turned dark (black marble) as the day progresses.

Current status:
- [X] Blue marble view png (v0.0.1)
- [X] Black marble view png (v0.0.1)

Current notes:

- I think that I will have to create a lookup
  - Lets say we do 1/2 hour increments, I just create a bool array based on sunrise/sunset times to see if a pixel should be in day or night mode.
  - I would probably then move to doing one of these per month to get seasonality
- I will need a package that can lookup sunrise/sunset times for a given lat/lon
  - This can be done with: https://github.com/adokter/suntools
  - R seems to be fine for this
- I will need some way though to get from my map to lat lon.
  - After some googling I think the easiest way is use an orthogonal projection and probably just eyeball the fit. So setup some R script to plot a view of the earth based on some orthogonal projection, play around a bit until I'm happy enough at the match. Then grab those parameters and use them to project from my xy into lat lon and feed into suntools.
  - Should be able to do as such with good old sf?

## Supported platforms

- Basalt (Pebble Time, 144×168)
- Gabbro (Pebble 2, 260×260 — via Rebble)

## How it works

1. **Pixel art assets** — Hand-drawn blue marble (day) and black marble (night) PNGs for each platform, stored as 4-bit palette bitmaps.
2. **Orthographic projection** — Each pixel in the image is mapped to a latitude/longitude coordinate using a simple orthographic projection.
3. **Sunrise/sunset lookup** — For each pixel, `suntools::sunriset()` computes sunrise and sunset times across 12 months at 30-minute resolution, producing a 4D boolean daylight array (month × time slot × row × col).
4. **Compression to limits** — The boolean array is compressed to left/right daylight boundary columns per row (with a secondary left2 column for wrap-around cases), halved vertically via nearest-neighbour downsampling.
5. **Binary resource** — The limits array is written as a raw binary (`limits_{platform}.bin`) bundled into the app resources.
6. **On-watch rendering** — The C watch app loads the day and night bitmaps, combines their palettes into a single 4-bit palette, then for each pixel swaps the palette index to day or night based on the limits for the current UTC month and half-hour slot.

## Project structure

- `blue_pixel/` — Pebble C app (built with `pebble build`)
  - `src/c/blue_pixel.c` — Watch face source
  - `resources/` — Bitmap assets and precomputed limits binaries
- `R/` — R helper functions (loaded via `devtools::load_all()`)
  - `projection_helpers.R` — Orthographic pixel → lat/lon projection
  - `time_helpers.R` — Sunrise/sunset computation via suntools
  - `bin_writer.R` — Write binary file pebble can read
  - `view_helpers.R` — Visualisation/debugging plots
- `generate_daynight_map.Rmd` — Generate the binary needed for pebble to generate the merged images on the fly
- `resize_images.py` — Resize source images for each platform

