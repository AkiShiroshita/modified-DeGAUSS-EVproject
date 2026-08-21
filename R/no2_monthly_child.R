# ============================================================================
# NO2 Exposure Assessment - Child Cohort (Monthly)
# ============================================================================
# This script assigns NO2 (nitrogen dioxide) exposure estimates for the
# child cohort during childhood using monthly aggregated NO2 data.
# NO2 is a traffic-related air pollutant.
# ============================================================================

# NO2 ---------------------------------------------------------------------

# Set up parallel processing
future::plan(future::multisession, workers = 24, gc = TRUE)  # to use multiple cores explicitly

# Load geocoded and cleaned address data
d <- fst::read_fst(paste0(temp_folder, '/', 'temp_geocoded_cleaned.fst'), as.data.table = TRUE)

# Parse date columns (handle multiple date formats)
d[, `:=` (start_date = as.Date(parse_date_time(start_date, orders = c("y/m/d", "ymd", "mdy"))),
          end_date = as.Date(parse_date_time(end_date, orders = c("y/m/d", "ymd", "mdy")))
)]
# Filter for exposure during childhood
# Update the period based on the duration of your exposure timeframe
# Restrict to the period covered by the exposure grids.
# A child is kept only if the *whole* exposure window falls inside the covered
# period, so the test has to be made per child: filtering record by record would
# silently keep children whose window only partly overlaps the grids, and average
# them over the covered fraction only.
data_start <- as.Date("2000-01-01")
data_end   <- as.Date("2012-12-31")

d <- d[state == "TN"]
d[, `:=` (window_start = min(start_date), window_end = max(end_date)), by = recip]
d <- d[window_start >= data_start & window_end <= data_end]
d[, c("window_start", "window_end") := NULL]

# Remove records with missing coordinates
d <- na.omit(d, cols = c("lat", "lon"))

# Nest data by location (group records with same coordinates)
d_nested <- d[, .(data = list(.SD)), by = .(lat, lon)]
# Convert to spatial object and transform to projected CRS (meters)
d_nested <- st_as_sf(d_nested, coords = c('lon', 'lat'), crs = 4326) |> st_transform(5072)

## Look-up grid cells
# Load NO2 grid cells (pre-computed NO2 concentration grid)
d_grid <- sf::st_read('data/no2_schwartz_monthly/grid_no2.gpkg') |> st_transform(crs = 5072)
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
d_no2_long <- d[, rbindlist(no2), by = recip]

# Average the monthly grid values, and record how much of the exposure window
# had no value so that partially covered children can be identified downstream.
# n_months_expected / n_months_missing count calendar months; n_month_records is
# larger when a child lived at more than one address within the same month.
d_no2_summary <- d_no2_long[, .(
  average_no2_childhood = mean(value, na.rm = TRUE),
  n_months_expected = uniqueN(date),
  n_months_missing  = uniqueN(date) - uniqueN(date[!is.na(value)]),
  n_month_records   = .N
), by = recip]
d_no2_summary[, fraction_months_missing := round(n_months_missing / n_months_expected, 4)]

# Save NO2 summary
d_no2_summary |> readr::write_rds(paste0(temp_folder, '/', 'd_no2_summary.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache

