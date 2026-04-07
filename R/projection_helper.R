project_to_lat_lon <- function(x, y, lat_ref = 0, lon_ref = 0, radius = 1) {
    # https://mathworld.wolfram.com/OrthographicProjection.html
    # calculate latitude (phi) and longitude (lambda) from x and y coordinates
    rad_lat_ref <- degrees_to_radians(lat_ref)
    rad_lon_ref <- degrees_to_radians(lon_ref)
    rho <- sqrt(x^2 + y^2)
    c <- asin(rho / radius)
    phi <- asin(
        cos(c) * sin(rad_lat_ref) + ((y * sin(c) * cos(rad_lat_ref)) / rho)
    )
    rho <- rad_lon_ref +
        atan(
            (x * sin(c)) /
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
