# ============================================================================
# Road Proximity × Traffic Density
# ============================================================================
# This script combines road proximity (distance to nearest major road) with
# traffic density (AADT of nearest road). This creates a composite exposure
# metric that considers both how close an address is to a major road and
# how much traffic that road carries.
# ============================================================================

# Road proximity * traffic density ----------------------------------------

# Load geocoded data with all previous exposure assessments including AADT
d <- readr::read_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace_dep_aadt.rds')) |> 
  sf::st_as_sf()

# Load AADT data for finding nearest high-traffic road
traffic_volume <- readr::read_rds('data/Tennessee2017AADT.rds') |>
  st_zm() # Drop M dimension
traffic_volume$geometry <- st_cast(traffic_volume$geometry, "MULTILINESTRING") # for AADT 2014
setDT(traffic_volume)

# Filter to only highest-traffic road types (interstates and freeways)
# These roads typically have the highest AADT values
road_types_to_keep <- c('Interstate', 'Principal Arterial - Other Freeways and Expressways')

# Filter to high-traffic roads only (AADT > 0)
# Note: Could also filter by truck AADT if needed
traffic_volume <- sf::st_as_sf(traffic_volume[road_type %in% road_types_to_keep & aadt >0, # aadt > 0 | aadt_single_unit > 0 | aadt_combination > 0
                                              -c("state_fips", "county_fips")])

# Find the nearest high-traffic road segment for each address
nearest_index <- sf::st_nearest_feature(d, traffic_volume)

# Calculate distance to nearest high-traffic road (in meters)
# This measures proximity to major traffic sources
d$dist_near <- purrr::map2_dbl(1:nrow(d),
                               nearest_index,
                               ~round(sf::st_distance(d[.x,], traffic_volume[.y,]), 1))

# Extract AADT value of the nearest road
# This measures traffic intensity at the nearest major road
setDT(traffic_volume)
d$aadt_near <- purrr::map_dbl(nearest_index, ~traffic_volume[.x][["aadt"]])

# Save data with combined proximity × traffic density metrics
d |> readr::write_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace_dep_aadt_int.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
