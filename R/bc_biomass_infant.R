# ============================================================================
# Biomass-specific Black Carbon (BC) Exposure Assessment - Child Cohort
# ============================================================================
# This script assigns biomass-specific black carbon exposure estimates for the child cohort
# ============================================================================

# BC ----------------------------------------------------------------------

# Set up parallel processing
future::plan(multisession, workers = 24, gc = TRUE)  # to use multiple cores explicitly

# Load geocoded and cleaned address data
d <- read_fst(paste0(temp_folder, '/', 'temp_geocoded_cleaned.fst'), as.data.table = TRUE)

# Parse date columns (handle multiple date formats)
d[, `:=` (start_date = as.Date(parse_date_time(start_date, orders = c("y/m/d", "ymd", "mdy"))),
          end_date = as.Date(parse_date_time(end_date, orders = c("y/m/d", "ymd", "mdy")))
)]
# Keep only children whose whole exposure window is covered by the grids.
# The exposure window is the first year of life (birth to the day before the first birthday).
# exposure_period_cleaning_infant.R sets the first record's start_date to the
# window's first day and the last record's end_date to its last day, so
# min(start_date) and max(end_date) per child are the window's two ends.
# data_start / data_end are the first and last days with biomass-specific BC grid data
# (2000-01 to 2017-12). The test is made on the window's last day, not on the date of
# birth, so data_end is the actual end of the data and must NOT be moved back
# by the window length: a child born on 2017-01-01 has a window ending on
# 2017-12-31 and is fully covered.
# The test is made per child, not per record: filtering record by record
# would keep children whose window only partly overlaps the grids and average
# them over the covered months only.
data_start <- as.Date("2000-01-01")
data_end   <- as.Date("2017-12-31")

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
# Load BC grid cells (pre-computed BC concentration grid)
d_grid <- sf::st_read('data/bc_monthly_biomass/grid_bc_biomass.gpkg') |> sf::st_transform(crs = 5072)

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
                             get_bc_biomass,
                             .progress = TRUE,
                             .options = furrr_options(seed = TRUE))
]

#future::plan(sequential)  # Switch back to sequential if needed

# Calculate average BC exposure per child
# Unnest BC results and calculate mean across all exposure periods
d_bc_long <- d[, rbindlist(bc), by = recip]

# Average the monthly grid values, and record how much of the exposure window
# had no value so that partially covered children can be identified downstream.
# n_months_expected / n_months_missing count calendar months; n_month_records is
# larger when a child lived at more than one address within the same month.
d_bc_summary <- d_bc_long[, .(
  average_biomass_bc_infancy = mean(value, na.rm = TRUE),
  n_months_expected = uniqueN(date),
  n_months_missing  = uniqueN(date) - uniqueN(date[!is.na(value)]),
  n_month_records   = .N
), by = recip]
d_bc_summary[, fraction_months_missing := round(n_months_missing / n_months_expected, 4)]

# Save BC summary
d_bc_summary |> readr::write_rds(paste0(temp_folder, '/', 'd_bc_biomass_summary.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
