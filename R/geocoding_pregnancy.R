# ============================================================================
# Geocoding Script - Pregnancy/Dyad Cohort
# ============================================================================
# This script geocodes addresses (converts addresses to lat/lon coordinates)
# for the dyad (mother-child) cohort during pregnancy period.
# 
# Steps:
# 1. Clean and filter addresses (remove PO boxes, institutional addresses)
# 2. Geocode addresses in parallel
# 3. Filter geocoding results by quality (precision, score)
# 4. Remove addresses outside Tennessee
# 5. Clean exposure periods and nest data by location
# ============================================================================

# Geocoding ---------------------------------------------------------------

# Load cleaned address data
# Note: temp_normalized.fst (parsed addresses) is commented out
# Using temp_cleaned.fst (raw cleaned addresses) instead
d <- fst::read_fst(paste0(temp_folder, '/', 'temp_cleaned.fst'), as.data.table = TRUE)
setDT(d)

# Create tracking table to monitor data loss at each step
# Tracks number of records (n), unique mothers (unique_n), and unique children (unique_child_n)
track <- tibble(
  status = c("Before address cleaning", "After address cleaning",
             "After geocoding", "After removing imprecise geocoding", "After removing children who moved out of TN"),
  n = NA_integer_,
  unique_n = NA_integer_,
  unique_child_n = NA_integer_
)

# Record initial counts
track$n[track$status == "Before address cleaning"] <- nrow(d)
track$unique_n[track$status == "Before address cleaning"] <- nrow(distinct(d, recip))

## Clean up addresses and classify 'bad' addresses
# Standardize address format
d[, address := dht::clean_address(address)]
# Flag PO boxes (cannot be geocoded to physical locations)
d[, po_box := address_is_po_box2(address)] # this function was modified
# Flag institutional/foster care addresses
d[, cincy_inst_foster_addr := dht::address_is_institutional(address)]
# Flag non-address text (e.g., "Unknown", "N/A")
d[, non_address_text := dht::address_is_nonaddress(address)] 

## Exclude 'bad' addresses from geocoding
# Remove PO boxes, institutional addresses, and non-address text
# These cannot be reliably geocoded or represent invalid addresses
d <- d[!(cincy_inst_foster_addr) & !(po_box) & !(non_address_text)]
# Remove flag columns (no longer needed)
d[, `:=`(cincy_inst_foster_addr = NULL, po_box = NULL, non_address_text = NULL)]

# Record counts after address cleaning
track$n[track$status == "After address cleaning"] <- nrow(d)
track$unique_n[track$status == "After address cleaning"] <- nrow(distinct(d, recip))

# Start geocoder container and ensure it stops on exit
# The geocoder container must be running before geocoding
start_geocoder_container2()

# Geocoding in parallel
# Set number of CPU cores to use for parallel processing
core <- 24

# Set up parallel processing plan (use multisession for local parallelism)
# multisession creates multiple R sessions on the same machine
future::plan(multisession, workers = core, gc = TRUE)  # to use multiple cores explicitly

# Geocode all addresses in parallel with progress bar
# Add row index to track original row order
d[, row_index := .I]

# Geocode addresses in parallel
# future.apply::future_lapply distributes geocoding across multiple cores
d[, geocodes := future.apply::future_lapply(address, geocode2, future.seed = TRUE)]
#d[, geocodes := lapply(address, geocode2)]  # Sequential version (slower)
# Convert geocoding results from lists to data.tables
d[, geocodes := lapply(geocodes, function(x) as.data.table(lapply(x, unlist)))]

#future::plan(sequential)  # Switch back to sequential processing if needed

# Unnest geocoding results while keeping original columns
# rbindlist combines all geocoding results into one table
geo <- rbindlist(d[,geocodes], idcol = "row_index", fill = TRUE)
# Merge geocoding results back with original data
d <- merge(d[,!"geocodes"], geo, by = "row_index", all.x=TRUE)

#d <- d[, c(.SD, geocodes[[1]]), by = row_index]  # Alternative merge method

# Keep only the first row per original row_index
# Some addresses may return multiple geocoding results; keep the first one
d <- d[, .SD[1], by = row_index]

# Remove temporary columns
d[, c("row_index", "geocodes") := NULL]

#stop_geocoder_container2()  # Uncomment to stop container after geocoding

# Save geocoded data
d |> fst::write_fst(paste0(temp_folder, '/', 'temp_geocoded.fst'), compress = 100)

# Removing imprecise geocoding results
# Reload geocoded data for quality filtering
d <- fst::read_fst(paste0(temp_folder, '/', 'temp_geocoded.fst'), as.data.table = TRUE)

######Specific for the current dyad cohort#######################################################################
# Linkage file which contains recip, mrecip and inf_dob
# For dyad cohort, we need to link mother IDs (mrecip) with child IDs (recip)
linkage_file <- fread(paste0(input_folder, '/', 'ev_dyad_link_v2022.csv')) # This file contains recip, mrecip and inf_dob

# Add mother's ID to the geocoded data
# Join on child recipient ID (recip) and date of birth (TN_DOB)
d <- linkage_file[d, on = c('recip', 'TN_DOB')] # add mother's ID to the geocoded data
# Rename columns: recip (child) -> mrecip (mother), chld_recip -> recip (child)
setnames(d, "recip", "mrecip")
setnames(d, "chld_recip", "recip")

# updated tabulation data
d_updated_temp <- fst::read_fst(paste0(temp_folder, '/', 'temp_cleaned.fst'), as.data.table = TRUE)
setDT(d_updated_temp)
d_updated_temp <- linkage_file[d_updated_temp, on = c('recip', 'TN_DOB')] # add mother's ID

track$unique_child_n[track$status == "Before address cleaning"] <- nrow(distinct(d_updated_temp, chld_recip))
## clean up addresses / classify 'bad' addresses
d_updated_temp[, address := dht::clean_address(address)]
d_updated_temp[, po_box := address_is_po_box2(address)] # this function was modified
d_updated_temp[, cincy_inst_foster_addr := dht::address_is_institutional(address)]
d_updated_temp[, non_address_text := dht::address_is_nonaddress(address)] 

## exclude 'bad' addresses from geocoding (unless specified to return all geocodes)
d_updated_temp <- d_updated_temp[!(cincy_inst_foster_addr) & !(po_box) & !(non_address_text)]
d_updated_temp[, `:=`(cincy_inst_foster_addr = NULL, po_box = NULL, non_address_text = NULL)]

track$unique_child_n[track$status == "After address cleaning"] <- nrow(distinct(d_updated_temp, chld_recip))
################################################################################################

track$n[track$status == "After geocoding"] <- nrow(d)
track$unique_n[track$status == "After geocoding"] <- nrow(distinct(d, mrecip))
track$unique_child_n[track$status == "After geocoding"] <- nrow(distinct(d, recip))

# Filter geocoding results by quality
# Keep only geocodes with valid coordinates
d <- d[!is.na(lat) & !is.na(lon)]
# Keep only high-precision geocodes (range or street level, not city/state level)
d <- d[precision == "range" | precision == "street"]
# Keep only geocodes with score >= 0.5 (higher score = better match)
d <- d[score>=0.5]

# Record counts after quality filtering
track$n[track$status == "After removing imprecise geocoding"] <- nrow(d)
track$unique_n[track$status == "After removing imprecise geocoding"] <- nrow(distinct(d, mrecip))
track$unique_child_n[track$status == "After removing imprecise geocoding"] <- nrow(distinct(d, recip))

# Removing children who moved out of TN
# Study is limited to Tennessee residents
# Identify children with any address outside TN
d_tn_out <- d[state != "TN"] # this approach is not perfect, as states may have missing value after geocoding
ids_tn_out <- distinct(d_tn_out, recip) %>% pull(recip)
# Remove all records for children who moved out of TN
d <- d[!recip %in% ids_tn_out]

track$n[track$status == "After removing children who moved out of TN"] <- nrow(d)
track$unique_n[track$status == "After removing children who moved out of TN"] <- nrow(distinct(d, mrecip))
track$unique_child_n[track$status == "After removing children who moved out of TN"] <- nrow(distinct(d, recip))

# Cleaning exposure periods
# Resolve gaps and overlaps in address history to create continuous time spans
# For dyad cohort, exposure period is from LMP (last menstrual period) to child's birth
source("R/exposure_period_cleaning_dyad.R", echo = FALSE, print.eval = FALSE)
d |> fst::write_fst(paste0(temp_folder, '/', 'temp_geocoded_cleaned.fst'), compress = 100)

# Nest data by location
# Group all records by unique lat/lon coordinates
# This reduces data size and speeds up spatial operations
d <- fst::read_fst(paste0(temp_folder, '/', 'temp_geocoded_cleaned.fst'), as.data.table = TRUE)

# Save tracking table
track |> readr::write_csv(paste0(output_folder, '/', 'track.csv'))

# Nest all records with same coordinates into a list column
# Each row represents one unique location with all address records at that location
d <- d[, .(data = list(.SD)), by = .(lat, lon)]

# Convert to spatial object (sf) for spatial operations
# CRS 4326 = WGS84 (lat/lon), transform to 5072 = Albers Equal Area (meters)
d <- sf::st_as_sf(d, coords = c('lon', 'lat'), crs = 4326) |> 
  sf::st_transform(5072)

# Save nested spatial data
d |> readr::write_rds(paste0(temp_folder, '/', 'temp_geocoded_nested.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
