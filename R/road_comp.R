# ============================================================================
# Road Proximity Assessment (birth-year specific road networks)
# ============================================================================
# This script calculates the distance from each address to the nearest
# primary (S1100) and secondary (S1200) roads, using the road network
# vintage that matches each child's birth year.
# Road proximity is associated with traffic-related air pollution exposure.
#
# Difference from R/road.R:
# - road.R uses a single road network (2011) for every record.
# - This script picks data/roads1100_projected_<birth year>.rds and
#   data/roads1200_projected_<birth year>.rds for each record
#   (e.g. birth year 2012 -> roads1100_projected_2012.rds).
# - Records whose birth year is outside road_years (or whose TN_DOB is missing)
#   have no matching road file and are dropped.
#
# Because the input is nested by unique lat/lon (one row per location, many
# children per location), the distances are birth-year specific and therefore
# stored inside the nested `data` column instead of on the location row.
# Unnesting `data` downstream yields dist_to_1100_comp / dist_to_1200_comp.
# The output keeps the location geometry in EPSG:5072.
# ============================================================================

# Road proximity ----------------------------------------------------------

# Load geocoded data with census boundaries (nested by unique lat/lon)
d <- readr::read_rds(paste0(temp_folder, '/', 'temp_geocoded_census.rds'))

# Distances are only valid in the projected CRS (EPSG:5072, meters)
if (!isTRUE(sf::st_crs(d)$epsg == 5072)) stop('temp_geocoded_census.rds is not in EPSG:5072.')

# Unnest the location-level data so that each record keeps its own birth year
# loc_index links every record back to its row (location) in d
records <- data.table::rbindlist(unname(d$data), idcol = 'loc_index')
records[, birth_year := lubridate::year(TN_DOB)]

# Drop records whose birth year has no matching road network
# (birth years outside road_years, missing TN_DOB, or years not downloaded yet)
n_before <- nrow(records)
road_years <- 2011:2016
dropped <- records[!birth_year %in% road_years, .N, by = birth_year][order(birth_year)]
if (nrow(dropped) > 0) {
  message('Records dropped (no road data for their birth year):')
  print(dropped)
}
records <- records[birth_year %in% road_years]
message('Records kept: ', nrow(records), ' of ', n_before)

if (nrow(records) == 0) stop('No records left after excluding birth years without road data.')

# Calculate distances one birth year at a time
# For each year only the locations actually used by that year's children are processed
dist_by_year <- vector('list', length(road_years))
names(dist_by_year) <- as.character(road_years)

for (yr in road_years) {

  # Locations occupied by at least one child born in this year
  loc_ids <- sort(unique(records[birth_year == yr, loc_index]))
  if (length(loc_ids) == 0) next

  d_yr <- sf::st_geometry(d)[loc_ids]
  message('Birth year ', yr, ': ', length(loc_ids), ' locations')

  # Calculate distance to S1100 roads (primary roads: interstates, major highways)
  # Load primary road network data for this year
  roads1100_projected <- readr::read_rds(paste0('data/roads1100_projected_', yr, '.rds'))
  if (!isTRUE(sf::st_crs(roads1100_projected)$epsg == 5072)) stop('roads1100_projected_', yr, '.rds is not in EPSG:5072.')

  # Find nearest primary road for each address location
  nearest_index_1100 <- sf::st_nearest_feature(d_yr, roads1100_projected)

  # Calculate distance in meters to nearest primary road
  dist_to_1100 <- round(as.numeric(sf::st_distance(d_yr,
                                                   roads1100_projected[nearest_index_1100, ],
                                                   by_element = TRUE)), 1)

  #rm(roads1100_projected, nearest_index_1100)
  #gc()

  # Calculate distance to S1200 roads (secondary roads: major arterials)
  # Load secondary road network data for this year
  roads1200_projected <- readr::read_rds(paste0('data/roads1200_projected_', yr, '.rds'))
  if (!isTRUE(sf::st_crs(roads1200_projected)$epsg == 5072)) stop('roads1200_projected_', yr, '.rds is not in EPSG:5072.')

  # Find nearest secondary road for each address location
  nearest_index_1200 <- sf::st_nearest_feature(d_yr, roads1200_projected)

  # Calculate distance in meters to nearest secondary road
  dist_to_1200 <- round(as.numeric(sf::st_distance(d_yr,
                                                   roads1200_projected[nearest_index_1200, ],
                                                   by_element = TRUE)), 1)

  #rm(roads1200_projected, nearest_index_1200, d_yr)
  #gc()

  # One row per location x birth year, to be joined back onto the records
  dist_by_year[[as.character(yr)]] <- data.table::data.table(
    loc_index = loc_ids,
    birth_year = yr,
    road_year = yr,
    dist_to_1100_comp = dist_to_1100,
    dist_to_1200_comp = dist_to_1200
  )
}

dist_lookup <- data.table::rbindlist(dist_by_year)

# Attach the birth-year specific distances to every record
records <- dist_lookup[records, on = .(loc_index, birth_year)]
records[, birth_year := NULL]  # birth year is recoverable from TN_DOB

# Re-nest the records by location so the output has the same structure as
# temp_geocoded_census_road.rds (one sf row per location, records in `data`)
# Locations whose records were all dropped are removed
nested <- records[, .(data = list(.SD)), by = loc_index]
d_out <- d[nested$loc_index, setdiff(names(d), 'data')]
d_out$data <- nested$data

if (!isTRUE(sf::st_crs(d_out)$epsg == 5072)) stop('Output is not in EPSG:5072.')

# Save data with road proximity measures
d_out |> readr::write_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_comp.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
