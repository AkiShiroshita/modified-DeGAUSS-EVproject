# ============================================================================
# Black Carbon (BC) Exposure Assessment - Child Cohort
# ============================================================================
# This script assigns black carbon exposure estimates for the child cohort
# during infancy period. Black carbon is a component of fine particulate
# matter from combustion sources (traffic, industry).
# ============================================================================

# BC ----------------------------------------------------------------------

# Set up parallel processing
core <- 24
future::plan(multisession, workers = core, gc = TRUE)  # to use multiple cores explicitly

# Load geocoded and cleaned address data
d <- read_fst(paste0(temp_folder, '/', 'temp_geocoded_cleaned.fst'), as.data.table = TRUE)

# Parse date columns (handle multiple date formats)
d[, `:=` (start_date = as.Date(parse_date_time(start_date, orders = c("y/m/d", "ymd", "mdy"))),
          end_date = as.Date(parse_date_time(end_date, orders = c("y/m/d", "ymd", "mdy")))
)]
# Filter for exposure during infancy period
# Update the period based on the duration of your exposure timeframe
d <- d[state == "TN" & start_date >= as.Date("2000-01-01") & end_date <= as.Date("2016-12-31")]

# Remove records with missing coordinates
d <- na.omit(d, cols = c("lat", "lon"))

# Nest data by location (group records with same coordinates)
d_nested <- d[, .(data = list(.SD)), by = .(lat, lon)]
# Convert to spatial object and transform to projected CRS (meters)
d_nested <- st_as_sf(d_nested, coords = c('lon', 'lat'), crs = 4326) |> st_transform(5072)

## Look-up grid cells
# Load BC grid cells (pre-computed BC concentration grid)
d_grid <- sf::st_read('data/grid_bc.gpkg') |> sf::st_transform(crs = 5072)

# Find nearest grid cell for each address location
nearest_index <- st_nearest_feature(d_nested, d_grid)

# Assign grid cell index to each location
setDT(d_nested)
d_nested$idx <- d_grid$idx[nearest_index]

# Get BC estimates
# Unnest data and group by grid cell index
d <- d_nested[, rbindlist(data), by = idx]

# Re-parse dates (needed after unnesting)
d[, `:=` (start_date = as.Date(parse_date_time(start_date, orders = c("y/m/d", "ymd", "mdy"))),
          end_date = as.Date(parse_date_time(end_date, orders = c("y/m/d", "ymd", "mdy")))
)]

# Retrieve BC values for each exposure period
# Uses monthly aggregated BC data
d[, bc := furrr::future_pmap(list(start_date, end_date, idx),
                             get_bc,
                             .progress = TRUE,
                             .options = furrr_options(seed = TRUE))
]

#future::plan(sequential)  # Switch back to sequential if needed

# Calculate average BC exposure per child
# Unnest BC results and calculate mean across all exposure periods
d_bc_summary <- d[, rbindlist(bc), by = recip][, .(average_bc_infancy = mean(value, na.rm = TRUE)), by = recip]

# Save BC summary
d_bc_summary |> readr::write_rds(paste0(temp_folder, '/', 'd_bc_summary.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
