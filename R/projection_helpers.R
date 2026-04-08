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
    rho <- sqrt(x^2 + y^2)
    c <- asin(rho / radius)
    # raise error if abs(c) > pi/2
    if (is.na(c) | abs(c) > (pi / 2)) {
        if (verbose) {
            message("Invalid x and y coordinates: outside of projection bounds")
        }
        return(data.frame(
            lat = NA,
            lon = NA
        ))
    }
    phi <- asin(
        cos(c) * sin(rad_lat_ref) + ((y * sin(c) * cos(rad_lat_ref)) / rho)
    )
    rho <- rad_lon_ref +
        atan2(
            (x * sin(c)),
            (rho *
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
