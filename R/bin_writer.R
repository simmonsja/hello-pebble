write_limits_bin <- function(
    limits_array,
    platform
) {
    # limits_array: [month, time, row, limit]
    # Binary layout: sequential blocks, one per (month, time) pair.
    # Block order: for time 1..n_times (outer), for month 1..n_months (inner).
    # Each block: height left uint16 LE values, then height right uint16 LE values.
    # Block index (0-based) = (time_idx - 1) * n_months + (month - 1)
    # Byte offset = block_index * height * 2 * 2
    dims <- dim(limits_array)
    n_months <- dims[1]
    n_times <- dims[2]

    path <- here::here(
        "blue_pixel",
        "resources",
        glue::glue("limits_{platform}.bin")
    )
    con <- file(path, "wb")
    on.exit(close(con))

    for (t in seq_len(n_times)) {
        for (m in seq_len(n_months)) {
            left_vals <- as.integer(limits_array[m, t, , "left"])
            right_vals <- as.integer(limits_array[m, t, , "right"])
            writeBin(
                c(left_vals, right_vals),
                con,
                size = 2L,
                endian = "little"
            )
        }
    }
}


# Read back a (height x 2) slice for a given month and hour from the binary file.
# Binary layout: blocks of (height * 2) uint16 LE values.
# Block index (0-based) = (time_idx - 1) * n_months + (month - 1)
# Each block: height left values then height right values.
read_limits_bin <- function(
    path,
    month,
    hour,
    height,
    n_months = 12,
    n_times = 48
) {
    time_vals <- seq(0, 23.5, by = 0.5)
    time_idx <- which.min(abs(time_vals - hour))
    block_size <- height * 2L

    block_index <- (time_idx - 1L) * n_months + (month - 1L)
    byte_offset <- block_index * block_size * 2L

    con <- file(path, "rb")
    on.exit(close(con))
    seek(con, byte_offset)
    vals <- readBin(
        con,
        integer(),
        n = block_size,
        size = 2L,
        signed = FALSE,
        endian = "little"
    )

    matrix(
        vals,
        nrow = height,
        ncol = 2,
        dimnames = list(NULL, c("left", "right"))
    )
}
