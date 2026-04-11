get_monthly_sunrise_sunset <- function(lat, lon, datetime) {
    # Create a data.frame to store the sunrise/sunset times for each month
    sunrise_sunset_df <- data.frame(
        datetime = datetime,
        sunrise = as.POSIXct(NA),
        sunset = as.POSIXct(NA)
    )
    if (is.na(lat) | is.na(lon)) {
        return(sunrise_sunset_df)
    }

    coords <- matrix(c(lon, lat), ncol = 2)

    sunrise_sunset_df <- sunrise_sunset_df |>
        dplyr::mutate(
            sunrise = purrr::map_vec(
                datetime,
                ~ suntools::sunriset(
                    coords,
                    .x,
                    crs = sf::st_crs(4326),
                    direction = 'sunrise',
                    POSIXct.out = TRUE
                )$time
            ),
            sunset = purrr::map_vec(
                datetime,
                ~ suntools::sunriset(
                    coords,
                    .x,
                    crs = sf::st_crs(4326),
                    direction = 'sunset',
                    POSIXct.out = TRUE
                )$time
            ),
        ) |>
        dplyr::mutate(
            sunrise = lubridate::round_date(sunrise, unit = "30minute") |>
                posixct_to_h(),
            sunset = lubridate::round_date(sunset, unit = "30minute") |>
                posixct_to_h(),
            month = lubridate::month(datetime)
        ) |>
        dplyr::select(-datetime)

    # Handle polar latitudes: sunriset returns NA for both perpetual day
    # and perpetual night. Use solarpos elevation at noon to disambiguate.
    na_rows <- which(
        is.na(sunrise_sunset_df$sunrise) | is.na(sunrise_sunset_df$sunset)
    )
    if (length(na_rows) > 0) {
        for (idx in na_rows) {
            noon_dt <- datetime[idx]
            elev <- suntools::solarpos(
                coords,
                noon_dt,
                crs = sf::st_crs(4326)
            )[, 2]
            if (elev > 0) {
                # Perpetual day: sun never sets
                sunrise_sunset_df$sunrise[idx] <- 0
                sunrise_sunset_df$sunset[idx] <- 23.5
            }
            # Perpetual night (elev <= 0): leave as NA, main loop will skip
        }
    }

    return(sunrise_sunset_df)
}

posixct_to_h <- function(datetime) {
    return(
        lubridate::hour(datetime) + lubridate::minute(datetime) / 60
    )
}
