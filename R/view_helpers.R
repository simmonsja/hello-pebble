plot_daylight <- function(
    daylight_limits,
    month,
    times,
    width,
    height,
    radius,
    night_colour = "#0a0a2a",
    day_colour = "#87ceeb"
) {
    time_labels <- as.numeric(dimnames(daylight_limits)$time)
    cx <- width / 2
    cy <- height / 2

    base_grid <- expand.grid(col = seq_len(width), row = seq_len(height)) |>
        dplyr::mutate(
            in_circle = sqrt((col - cx)^2 + (row - cy)^2) <= radius
        )

    pixel_df <- lapply(times, function(time) {
        time_idx <- which.min(abs(time_labels - time))
        time_key <- dimnames(daylight_limits)$time[time_idx]

        left_vec <- daylight_limits[month, time_key, , "left"]
        right_vec <- daylight_limits[month, time_key, , "right"]

        row_limits <- data.frame(
            row = seq_len(height),
            left = as.integer(left_vec),
            right = as.integer(right_vec)
        )

        base_grid |>
            dplyr::left_join(row_limits, by = "row") |>
            dplyr::mutate(
                state = dplyr::case_when(
                    !in_circle ~ NA_character_,
                    !is.na(left) & col >= left & col <= right ~ "day",
                    TRUE ~ "night"
                ),
                time_label = sprintf("%05.2f UTC", as.numeric(time_key))
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
        ggplot2::labs(title = sprintf("Month %d", month))
}
