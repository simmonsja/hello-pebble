compress_bool_to_limits <- function(daylight_bool, min_max_coords) {
    dims <- dim(daylight_bool)
    n_months <- dims[1]
    n_times <- dims[2]
    height <- dims[3]

    # Store every other row to halve binary size
    stored_rows <- seq(1, height, by = 2)
    n_stored <- length(stored_rows)

    limits <- array(
        NA_integer_,
        dim = c(n_months, n_times, n_stored, 3),
        dimnames = list(
            month = dimnames(daylight_bool)$month,
            time = dimnames(daylight_bool)$time,
            row = stored_rows,
            limit = c("left", "right", "left2")
        )
    )

    pb <- cli::cli_progress_bar(
        total = n_stored,
        format = "Compressing {cli::pb_bar} {cli::pb_current}/{cli::pb_total}"
    )

    for (si in seq_along(stored_rows)) {
        cli::cli_progress_update(id = pb)
        r <- stored_rows[si]
        row_min <- min_max_coords$min_x[r]
        row_max <- min_max_coords$max_x[r]
        pair_r <- NA_integer_
        pair_min <- NA_integer_
        pair_max <- NA_integer_

        if (is.na(row_min) || is.na(row_max)) {
            # The odd stored row is outside the globe.  The even row that shares
            # this stored slot (r+1) may still be inside the globe, so try that
            # first.  If not, fall back to the all-zero sentinel.
            cand <- r + 1L
            if (
                cand <= nrow(min_max_coords) &&
                    !is.na(min_max_coords$min_x[cand]) &&
                    !is.na(min_max_coords$max_x[cand])
            ) {
                r <- cand
                row_min <- min_max_coords$min_x[r]
                row_max <- min_max_coords$max_x[r]
                # pair is the original odd row (NA) — no width expansion needed
            } else {
                limits[,, si, ] <- 0L
                next
            }
        } else {
            # Odd row is valid. Check if the even pair (r+1) is wider.
            cand <- r + 1L
            if (cand <= nrow(min_max_coords)) {
                pair_r <- cand
                pair_min <- min_max_coords$min_x[pair_r]
                pair_max <- min_max_coords$max_x[pair_r]
            }
        }

        # Effective bounds: union of canonical row and its even pair's bounds.
        effective_min <- min(row_min, pair_min, na.rm = TRUE)
        effective_max <- max(row_max, pair_max, na.rm = TRUE)
        sentinel <- as.integer(effective_max + 1L)

        for (m in seq_len(n_months)) {
            for (t in seq_len(n_times)) {
                # Build row_vals over effective_min:effective_max.
                # Use canonical row r for its own columns; use pair_r for any
                # columns that extend beyond r's bounds (wider even-pair edges).
                n_eff <- effective_max - effective_min + 1L
                row_vals <- logical(n_eff)
                r_start <- row_min - effective_min + 1L
                r_end <- row_max - effective_min + 1L
                row_vals[r_start:r_end] <-
                    as.logical(daylight_bool[m, t, r, row_min:row_max])

                if (!is.na(pair_min) && effective_min < row_min) {
                    ext_cols <- effective_min:(row_min - 1L)
                    row_vals[seq_along(ext_cols)] <-
                        as.logical(daylight_bool[m, t, pair_r, ext_cols])
                }
                if (!is.na(pair_max) && effective_max > row_max) {
                    ext_cols <- (row_max + 1L):effective_max
                    row_vals[(r_end + 1L):(r_end + length(ext_cols))] <-
                        as.logical(daylight_bool[m, t, pair_r, ext_cols])
                }

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
                    limits[m, t, si, ] <- c(sentinel, 0L, sentinel)
                    next
                }

                # Convert to absolute column indices
                day_cols <- day_positions + effective_min - 1L

                # Find gaps between consecutive day pixels
                diffs <- diff(day_cols)
                gap_positions <- which(diffs > 1)

                if (length(gap_positions) == 0) {
                    # Single contiguous daylight block
                    limits[m, t, si, ] <- c(
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

                    limits[m, t, si, ] <- c(
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
