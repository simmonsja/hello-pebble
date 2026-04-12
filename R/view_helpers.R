plot_daylight_bool <- function(
    daylight_bool,
    month,
    times,
    width,
    height,
    radius,
    tz = "UTC",
    night_colour = "#0a0a2a",
    day_colour = "#87ceeb"
) {
    time_labels <- as.numeric(dimnames(daylight_bool)$time)
    cx <- width / 2
    cy <- height / 2

    base_grid <- expand.grid(
        col = seq_len(width),
        row = seq_len(height)
    ) |>
        dplyr::mutate(
            in_circle = sqrt((col - cx)^2 + (row - cy)^2) <= radius
        )

    utc_times <- sapply(times, function(t) {
        local_dt <- lubridate::make_datetime(
            2026,
            month,
            15,
            hour = as.integer(t),
            min = as.integer(round((t %% 1) * 60)),
            tz = tz
        )
        utc_dt <- lubridate::with_tz(local_dt, "UTC")
        lubridate::hour(utc_dt) + lubridate::minute(utc_dt) / 60
    })

    pixel_df <- lapply(seq_along(times), function(ii) {
        time_idx <- which.min(abs(time_labels - utc_times[ii]))
        # Extract the height x width boolean matrix for this month/time
        slice <- daylight_bool[month, time_idx, , ]

        # Convert to long form
        lit_df <- expand.grid(
            row = seq_len(height),
            col = seq_len(width)
        ) |>
            dplyr::mutate(
                is_day = as.vector(slice)
            )

        base_grid |>
            dplyr::left_join(lit_df, by = c("row", "col")) |>
            dplyr::mutate(
                state = dplyr::case_when(
                    !in_circle ~ NA_character_,
                    is_day ~ "day",
                    TRUE ~ "night"
                ),
                time_label = sprintf("%02d:00", as.integer(times[ii]))
            )
    }) |>
        dplyr::bind_rows()

    pixel_df$time_label <- factor(
        pixel_df$time_label,
        levels = unique(pixel_df$time_label)
    )

    ggplot2::ggplot(pixel_df, ggplot2::aes(x = col, y = -row, fill = state)) +
        ggplot2::geom_raster() +
        ggplot2::scale_fill_manual(
            values = c(night = night_colour, day = day_colour),
            na.value = "transparent",
            name = NULL
        ) +
        ggplot2::coord_fixed() +
        ggplot2::facet_wrap(~time_label) +
        ggplot2::theme_void() +
        ggplot2::labs(title = sprintf("Month %d - tz: %s", month, tz))
}

plot_daylight <- function(
    daylight_limits,
    month,
    times,
    width,
    height,
    radius,
    min_max_coords,
    tz = "UTC",
    night_colour = "#0a0a2a",
    day_colour = "#87ceeb"
) {
    time_labels <- as.numeric(dimnames(daylight_limits)$time)
    cx <- width / 2
    cy <- height / 2
    has_left2 <- dim(daylight_limits)[4] >= 3

    base_grid <- expand.grid(
        col = seq_len(width),
        row = seq_len(height)
    ) |>
        dplyr::mutate(
            in_circle = sqrt((col - cx)^2 + (row - cy)^2) <= radius
        )

    # Convert local hours to UTC decimal hours for array lookup
    utc_times <- sapply(times, function(t) {
        local_dt <- lubridate::make_datetime(
            2026,
            month,
            15,
            hour = as.integer(t),
            min = as.integer(round((t %% 1) * 60)),
            tz = tz
        )
        utc_dt <- lubridate::with_tz(local_dt, "UTC")
        lubridate::hour(utc_dt) + lubridate::minute(utc_dt) / 60
    })

    pixel_df <- lapply(seq_along(times), function(ii) {
        time_idx <- which.min(abs(time_labels - utc_times[ii]))
        time_key <- dimnames(daylight_limits)$time[time_idx]

        left_vec <- daylight_limits[month, time_key, , "left"]
        right_vec <- daylight_limits[month, time_key, , "right"]

        row_limits <- data.frame(
            row = seq_len(height),
            left = as.integer(left_vec),
            right = as.integer(right_vec),
            max_x = as.integer(min_max_coords$max_x)
        )

        if (has_left2) {
            left2_vec <- daylight_limits[month, time_key, , "left2"]
            row_limits$left2 <- as.integer(left2_vec)

            base_grid |>
                dplyr::left_join(row_limits, by = "row") |>
                dplyr::mutate(
                    state = dplyr::case_when(
                        !in_circle ~ NA_character_,
                        !is.na(left) & col >= left & col <= right ~ "day",
                        !is.na(left2) &
                            !is.na(max_x) &
                            left2 <= max_x &
                            col >= left2 &
                            col <= max_x ~ "day",
                        TRUE ~ "night"
                    ),
                    time_label = sprintf("%02d:00", as.integer(times[ii]))
                )
        } else {
            base_grid |>
                dplyr::left_join(row_limits, by = "row") |>
                dplyr::mutate(
                    state = dplyr::case_when(
                        !in_circle ~ NA_character_,
                        !is.na(left) & col >= left & col <= right ~ "day",
                        TRUE ~ "night"
                    ),
                    time_label = sprintf("%02d:00", as.integer(times[ii]))
                )
        }
    }) |>
        dplyr::bind_rows()

    pixel_df$time_label <- factor(
        pixel_df$time_label,
        levels = unique(pixel_df$time_label)
    )

    ggplot2::ggplot(pixel_df, ggplot2::aes(x = col, y = -row, fill = state)) +
        ggplot2::geom_raster() +
        ggplot2::scale_fill_manual(
            values = c(night = night_colour, day = day_colour),
            na.value = "transparent",
            name = NULL
        ) +
        ggplot2::coord_fixed() +
        ggplot2::facet_wrap(~time_label) +
        ggplot2::theme_void() +
        ggplot2::labs(title = sprintf("Month %d - tz: %s", month, tz))
}

plot_daylight_single <- function(
    daylight_limits,
    month,
    time,
    width,
    height,
    radius,
    min_max_coords,
    tz = "UTC",
    night_colour = "#0a0a2a",
    day_colour = "#87ceeb"
) {
    time_labels <- as.numeric(dimnames(daylight_limits)$time)
    cx <- width / 2
    cy <- height / 2
    has_left2 <- dim(daylight_limits)[4] >= 3

    # Convert local time to UTC
    local_dt <- lubridate::make_datetime(
        2026,
        month,
        15,
        hour = as.integer(time),
        min = as.integer(round((time %% 1) * 60)),
        tz = tz
    )
    utc_dt <- lubridate::with_tz(local_dt, "UTC")
    utc_time <- lubridate::hour(utc_dt) + lubridate::minute(utc_dt) / 60

    time_idx <- which.min(abs(time_labels - utc_time))
    time_key <- dimnames(daylight_limits)$time[time_idx]

    left_vec <- daylight_limits[month, time_key, , "left"]
    right_vec <- daylight_limits[month, time_key, , "right"]

    # Create base grid
    base_grid <- expand.grid(
        col = seq_len(width),
        row = seq_len(height)
    ) |>
        dplyr::mutate(
            in_circle = sqrt((col - cx)^2 + (row - cy)^2) <= radius
        )

    row_limits <- data.frame(
        row = seq_len(height),
        left = as.integer(left_vec),
        right = as.integer(right_vec),
        max_x = as.integer(min_max_coords$max_x)
    )

    if (has_left2) {
        left2_vec <- daylight_limits[month, time_key, , "left2"]
        row_limits$left2 <- as.integer(left2_vec)
    }

    # Create pixel states
    pixel_df <- base_grid |>
        dplyr::left_join(row_limits, by = "row")

    if (has_left2) {
        pixel_df <- pixel_df |>
            dplyr::mutate(
                state = dplyr::case_when(
                    !in_circle ~ NA_character_,
                    !is.na(left) & col >= left & col <= right ~ "day",
                    !is.na(left2) &
                        !is.na(max_x) &
                        left2 <= max_x &
                        col >= left2 &
                        col <= max_x ~ "day",
                    TRUE ~ "night"
                )
            )
    } else {
        pixel_df <- pixel_df |>
            dplyr::mutate(
                state = dplyr::case_when(
                    !in_circle ~ NA_character_,
                    !is.na(left) & col >= left & col <= right ~ "day",
                    TRUE ~ "night"
                )
            )
    }

    # Create boundary markers
    boundary_df <- row_limits |>
        dplyr::filter(!is.na(left), !is.na(right)) |>
        tidyr::pivot_longer(
            cols = c("left", "right", if (has_left2) "left2" else NULL),
            names_to = "boundary_type",
            values_to = "col"
        ) |>
        dplyr::filter(!is.na(col))

    # Filter out sentinel values (left2 = max_x+1 means no second block)
    if (has_left2) {
        boundary_df <- boundary_df |>
            dplyr::filter(
                !(boundary_type == "left2" & !is.na(max_x) & col > max_x)
            )
    }

    p <- ggplot2::ggplot() +
        ggplot2::geom_raster(
            data = pixel_df,
            ggplot2::aes(x = col, y = row, fill = state)
        ) +
        ggplot2::scale_fill_manual(
            values = c(night = night_colour, day = day_colour),
            na.value = "transparent",
            name = "State"
        ) +
        ggplot2::geom_point(
            data = boundary_df,
            ggplot2::aes(x = col, y = row, color = boundary_type),
            size = 1.5,
            alpha = 0.8
        ) +
        ggplot2::scale_color_manual(
            values = c(left = "red", right = "green", left2 = "blue"),
            name = "Boundary"
        ) +
        ggplot2::coord_fixed() +
        ggplot2::scale_x_continuous(breaks = seq(0, width, by = 10)) +
        ggplot2::scale_y_continuous(breaks = seq(0, height, by = 10)) +
        ggplot2::labs(
            title = sprintf(
                "Month %d, Time %02d:00 (%s) → UTC %.1f [%d, %d, , ]",
                month,
                as.integer(time),
                tz,
                utc_time,
                month,
                time_idx
            ),
            x = "Column",
            y = "Row"
        ) +
        ggplot2::theme_minimal()

    return(p)
}
