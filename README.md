# Blue Pebble

This project aims to create a pebble watch face from a pixel art earth (blue marble) that is reactive to sun position and illumination. The idea is a geostationary view of the earth where the pixels are gradually turned dark (black marble) as the day progresses.

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




```json
    //   "aplite",
    //   "basalt",
    //   "chalk",
    //   "diorite",
    //   "emery",
    //   "flint",
```