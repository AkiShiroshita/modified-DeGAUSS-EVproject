# ============================================================================
# NO2 Exposure Assessment - Child Cohort (Monthly)
# ============================================================================
# This script assigns NO2 (nitrogen dioxide) exposure estimates for the
# child cohort during childhood using monthly aggregated NO2 data.
# NO2 is a traffic-related air pollutant.
# ============================================================================

# NO2 ---------------------------------------------------------------------

# Set up parallel processing
future::plan(multisession, workers = 24, gc = TRUE)  # to use multiple cores explicitly

# Load geocoded and cleaned address data
d <- fst::read_fst(paste0(temp_folder, '/', 'temp_geocoded_cleaned.fst'), as.data.table = TRUE)

# Parse date columns (handle multiple date formats)
d[, `:=` (start_date = as.Date(parse_date_time(start_date, orders = c("y/m/d", "ymd", "mdy"))),
          end_date = as.Date(parse_date_time(end_date, orders = c("y/m/d", "ymd", "mdy")))
)]
# Filter for exposure during childhood
# Update the period based on the duration of your exposure timeframe
d <- d[state == "TN" & start_date >= as.Date("2000-01-01") & end_date <= as.Date("2012-12-31")]

# Remove records with missing coordinates
d <- na.omit(d, cols = c("lat", "lon"))

# Nest data by location (group records with same coordinates)
d_nested <- d[, .(data = list(.SD)), by = .(lat, lon)]
# Convert to spatial object and transform to projected CRS (meters)
d_nested <- st_as_sf(d_nested, coords = c('lon', 'lat'), crs = 4326) |> st_transform(5072)

## Look-up grid cells
# Load NO2 grid cells (pre-computed NO2 concentration grid)
d_grid <- sf::st_read('data/no2_schwartz/grid.gpkg') |> st_transform(crs = 5072)
# Find nearest grid cell for each address location
nearest_index <- sf::st_nearest_feature(d_nested, d_grid)

# Assign grid cell index to each location
setDT(d_nested)
d_nested$idx <- d_grid$idx[nearest_index]

# Get NO2 estimates
# Unnest data and group by grid cell index
d <- d_nested[, rbindlist(data), by = idx]

# Re-parse dates (needed after unnesting)
d[, `:=` (start_date = as.Date(parse_date_time(start_date, orders = c("y/m/d", "ymd", "mdy"))),
          end_date = as.Date(parse_date_time(end_date, orders = c("y/m/d", "ymd", "mdy")))
)]

# Retrieve NO2 values for each exposure period
# Uses monthly aggregated NO2 data (faster than daily for long periods)
d[, no2 := furrr::future_pmap(list(start_date, end_date, idx),
                              get_no2_monthly,
                              .progress = TRUE,
                              .options = furrr_options(seed = TRUE))
]

#future::plan(sequential)  # Switch back to sequential if needed

# Calculate average NO2 exposure per child
# Unnest NO2 results and calculate mean across all exposure periods
d_no2_summary <- d[, rbindlist(no2), by = recip][, .(average_no2_childhood = mean(value, na.rm = TRUE)), by = recip]

# Save NO2 summary
d_no2_summary |> readr::write_rds(paste0(temp_folder, '/', 'd_no2_summary.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache

