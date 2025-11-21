# ============================================================================
# Road Proximity Assessment
# ============================================================================
# This script calculates the distance from each address to the nearest
# primary (S1100) and secondary (S1200) roads.
# Road proximity is associated with traffic-related air pollution exposure.
# ============================================================================

# Road proximity ----------------------------------------------------------

# Load geocoded data with census boundaries
d <- readr::read_rds(paste0(temp_folder, '/', 'temp_geocoded_census.rds'))

# Calculate distance to S1100 roads (primary roads: interstates, major highways)
# Load primary road network data
roads1100_projected <- readr::read_rds('data/roads1100_projected_2011.rds')

# Find nearest primary road for each address location
nearest_index_1100 <- sf::st_nearest_feature(d, roads1100_projected)

# Calculate distance in meters to nearest primary road
d$dist_to_1100 <- purrr::map2_dbl(1:nrow(d),
                                  nearest_index_1100,
                                  ~round(sf::st_distance(d[.x,], roads1100_projected[.y,]), 1))

# Calculate distance to S1200 roads (secondary roads: major arterials)
# Load secondary road network data
roads1200_projected <- readr::read_rds('data/roads1200_projected_2011.rds')

# Find nearest secondary road for each address location
nearest_index_1200 <- sf::st_nearest_feature(d, roads1200_projected)

# Calculate distance in meters to nearest secondary road
d$dist_to_1200 <- purrr::map2_dbl(1:nrow(d),
                                  nearest_index_1200,
                                  ~round(sf::st_distance(d[.x,], roads1200_projected[.y,]), 1))

# Save data with road proximity measures
d |> readr::write_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
