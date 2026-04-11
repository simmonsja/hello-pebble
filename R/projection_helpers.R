project_to_lat_lon <- function(
    x_in,
    y_in,
    lat_ref = 0,
    lon_ref = 0,
    radius = 1,
    width = 260,
    height = 260,
    verbose = TRUE
) {
    # https://mathworld.wolfram.com/OrthographicProjection.html
    # calculate latitude (phi) and longitude (lambda) from x and y coordinates
    x <- x_in - width / 2
    y <- height / 2 - y_in
    rad_lat_ref <- degrees_to_radians(lat_ref)
    rad_lon_ref <- degrees_to_radians(lon_ref)
    psi <- sqrt(x^2 + y^2)
    # we are going to cheat a bit for our case, we know every valid pixel is "within" our radius or should be were it not for my bad drawing. So let's bump back in any pixels that are outside the radius back to the radius. I don't know if this is okay, frowned upon or downright illegal. But it will probably do the job.
    # psi <- max(min(psi, radius), 1e-6) # avoid division by zero
    c <- asin(psi / radius)
    if (is.na(c) | abs(c) > (pi / 2)) {
        if (verbose) {
            message("Invalid x and y coordinates: outside of projection bounds")
        }
        return(data.frame(
            lat = NA,
            lon = NA
        ))
    }
    # caution to the wind we're just nudging our way to a valid solution
    phi_in <- cos(c) *
        sin(rad_lat_ref) +
        ((y * sin(c) * cos(rad_lat_ref)) / psi)
    phi <- asin(
        phi_in #max(min(phi_in, 1), -1)
    )
    rho <- rad_lon_ref +
        atan2(
            (x * sin(c)),
            (psi *
                cos(rad_lat_ref) *
                cos(c) -
                y * sin(rad_lat_ref) * sin(c))
        )
    return(data.frame(
        lat = radians_to_degrees(phi),
        lon = radians_to_degrees(rho)
    ))
}

degrees_to_radians <- function(degrees) {
    return(degrees * (pi / 180))
}

radians_to_degrees <- function(radians) {
    return(radians * (180 / pi))
}
