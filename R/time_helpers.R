get_monthly_sunrise_sunset <- function(lat, lon, datetime) {
    # Create a data.frame to store the sunrise/sunset times for each month
    sunrise_sunset_df <- data.frame(
        datetime = datetime,
        sunrise = as.POSIXct(NA),
        sunset = as.POSIXct(NA)
    )

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
    return(sunrise_sunset_df)
}

posixct_to_h <- function(datetime) {
    return(
        lubridate::hour(datetime) + lubridate::minute(datetime) / 60
    )
}
