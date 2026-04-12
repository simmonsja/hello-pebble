compress_bool_to_limits <- function(daylight_bool, min_max_coords) {
    dims <- dim(daylight_bool)
    n_months <- dims[1]
    n_times <- dims[2]
    height <- dims[3]

    limits <- array(
        NA_integer_,
        dim = c(n_months, n_times, height, 3),
        dimnames = list(
            month = dimnames(daylight_bool)$month,
            time = dimnames(daylight_bool)$time,
            row = 1:height,
            limit = c("left", "right", "left2")
        )
    )

    pb <- cli::cli_progress_bar(
        total = height,
        format = "Compressing {cli::pb_bar} {cli::pb_current}/{cli::pb_total}"
    )

    for (r in seq_len(height)) {
        cli::cli_progress_update(id = pb)
        row_min <- min_max_coords$min_x[r]
        row_max <- min_max_coords$max_x[r]

        if (is.na(row_min) || is.na(row_max)) {
            limits[,, r, ] <- 0L
            next
        }

        sentinel <- as.integer(row_max + 1L)

        for (m in seq_len(n_months)) {
            for (t in seq_len(n_times)) {
                row_vals <- daylight_bool[m, t, r, row_min:row_max]
                row_vals[is.na(row_vals)] <- FALSE

                # Fill small gaps (≤ 2 pixels) to smooth projection artifacts
                rle_row <- rle(row_vals)
                for (ri in seq_along(rle_row$lengths)) {
                    if (
                        !rle_row$values[ri] &&
                            rle_row$lengths[ri] <= 2 &&
                            ri > 1 &&
                            ri < length(rle_row$lengths) &&
                            rle_row$values[ri - 1] &&
                            rle_row$values[ri + 1]
                    ) {
                        rle_row$values[ri] <- TRUE
                    }
                }
                row_vals <- inverse.rle(rle_row)

                day_positions <- which(row_vals)

                if (length(day_positions) == 0) {
                    # No daylight: left > right signals "all night"
                    limits[m, t, r, ] <- c(sentinel, 0L, sentinel)
                    next
                }

                # Convert to absolute column indices
                day_cols <- day_positions + row_min - 1L

                # Find gaps between consecutive day pixels
                diffs <- diff(day_cols)
                gap_positions <- which(diffs > 1)

                if (length(gap_positions) == 0) {
                    # Single contiguous daylight block
                    limits[m, t, r, ] <- c(
                        as.integer(min(day_cols)),
                        as.integer(max(day_cols)),
                        sentinel
                    )
                } else {
                    # Multiple blocks: split at the largest gap
                    largest_gap_idx <- gap_positions[which.max(diffs[
                        gap_positions
                    ])]
                    block1_end <- day_cols[largest_gap_idx]
                    block2_start <- day_cols[largest_gap_idx + 1]

                    limits[m, t, r, ] <- c(
                        as.integer(min(day_cols)),
                        as.integer(block1_end),
                        as.integer(block2_start)
                    )
                }
            }
        }
    }
    cli::cli_progress_done(id = pb)

    return(limits)
}


write_limits_bin <- function(
    limits_array,
    platform
) {
    # limits_array: [month, time, row, limit]
    # Binary layout: sequential blocks, one per (month, time) pair.
    # Block order: for time 1..n_times (outer), for month 1..n_months (inner).
    # Each block: height values per limit column, written sequentially.
    # Block index (0-based) = (time_idx - 1) * n_months + (month - 1)
    dims <- dim(limits_array)
    n_months <- dims[1]
    n_times <- dims[2]
    n_limit_cols <- dims[4]

    path <- here::here(
        "blue_pixel",
        "resources",
        glue::glue("limits_{platform}.bin")
    )
    con <- file(path, "wb")
    on.exit(close(con))

    for (t in seq_len(n_times)) {
        for (m in seq_len(n_months)) {
            for (lc in seq_len(n_limit_cols)) {
                vals <- as.integer(limits_array[m, t, , lc])
                writeBin(vals, con, size = 1L, endian = "little")
            }
        }
    }
}


# Read back a (height x 2) slice for a given month and hour from the binary file.
# Binary layout: blocks of (height * 2) uint8 values.
# Block index (0-based) = (time_idx - 1) * n_months + (month - 1)
# Each block: height left values then height right values.
read_limits_bin <- function(
    path,
    month,
    hour,
    height,
    n_months = 12,
    n_times = 48,
    n_limit_cols = 3
) {
    time_vals <- seq(0, 23.5, by = 0.5)
    time_idx <- which.min(abs(time_vals - hour))
    block_size <- height * n_limit_cols

    block_index <- (time_idx - 1L) * n_months + (month - 1L)
    byte_offset <- block_index * block_size

    con <- file(path, "rb")
    on.exit(close(con))
    seek(con, byte_offset)
    vals <- readBin(
        con,
        integer(),
        n = block_size,
        size = 1L,
        signed = FALSE,
        endian = "little"
    )

    col_names <- c("left", "right", "left2")[seq_len(n_limit_cols)]
    matrix(
        vals,
        nrow = height,
        ncol = n_limit_cols,
        dimnames = list(NULL, col_names)
    )
}
