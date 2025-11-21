# ============================================================================
# Final Data Cleaning - Dyad Cohort
# ============================================================================
# This script performs final data cleaning and preparation for the dyad cohort:
# 1. Combines data from multiple processing batches
# 2. Calculates relocation indicators
# 3. Selects final variables for analysis
# 4. Removes PHI (Protected Health Information)
# 5. Creates separate files for environmental exposures, NO2, BC, and deprivation indices
# ============================================================================

# Final cleaning (without air pollutants) ---------------------------------------------------------
# Combines data from multiple batches and prepares final analysis dataset

# Define temporary folder and file paths for multiple batches
temp_folder <-   "W:/Data/Tan/temp/"
files <- paste0(temp_folder, "/temp_degauss_dyad", 1:6, "/temp_geocoded_census_road_greenspace_dep_road_density.rds")

# Combine data from all batches
# Read and unnest nested data from each batch file
combined_data <- rbindlist(
  lapply(files, function(file) {
    read_rds(file) %>%  
      unnest(cols = data)  # Unnest nested address records
  }),
  use.names = TRUE,
  fill = TRUE
)

# Sort by recipient ID and date
setDT(combined_data)
setorder(combined_data, recip, start_date, end_date)

# Calculate relocation indicator
# Identifies when a mother moved to a different location during pregnancy
coords <- sf::st_coordinates(sf::st_transform(st_as_sf(combined_data), 5072))
d_location <- combined_data
d_location[, `:=` (lon = coords[,1], lat = coords[,2])]

# Flag relocations: 1 if coordinates changed from previous record, 0 otherwise
d_location <- d_location[, .(
  relocation = fifelse(lon != data.table::shift(lon) & lat != data.table::shift(lat), 1, 0, na = 0)
), by = recip]

# Remove geometry and convert all columns to character
# This removes PHI and prepares data for export
combined_data <- combined_data %>% 
  dplyr::select(-geometry) %>%  # Remove spatial geometry (contains coordinates)
  mutate_all(as.character)  # Convert all to character for consistency

# Remove recip from location data before binding
d_location <- d_location %>% 
  dplyr::select(-recip)

# Combine main data with relocation indicator
combined_data <- cbind(combined_data, d_location)

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache

# Remove unsharable or unnecessary columns
#plan(sequential)

#cols_to_remove <- c("census_tract_id", "geometry", "address", "number", "state", "street", 
#                    "zip", "score", "prenum", "precision", 
#                    "census_block_group_id_2020", "data", "fips_county")
#
#d[, (cols_to_remove) := NULL]

# Select final variables for analysis
# Includes: identifiers (child and mother), dates, relocation, census boundaries,
# redlining, road proximity, road density, greenspace, and deprivation indices
# Note: Traffic density variables (AADT) are commented out but available if needed
columns_to_select <- c("recip", "mrecip", "start_date", "end_date", "relocation", "city",
                       "TN_DOB", "LMP",  # Child DOB and Last Menstrual Period
                       "county_fips2010","county_fips2020",
                       "census_block_group_id_2010", "census_block_group_id_2020",
                       "census_tract_id_2010", "census_tract_id_2020",
                       "redlining", "dist_to_1100", "dist_to_1200",
                       "length_1100", "length_1200", "length_1400",
                       "evi_500", "evi_1500", "evi_2500",
                       "fraction_assisted_income", "fraction_high_school_edu", "median_income",
                       "fraction_no_health_ins", "fraction_poverty", "fraction_vacant_housing",
                       "dep_index"
                       # Traffic density variables (commented out, available if needed):
                       #"length_moving", "length_stop_go",
                       #"vehicle_meters_moving", "vehicle_meters_stop_go",
                       #"truck_meters_moving", "truck_meters_stop_go",
                       #"dist_near", "aadt_near"
)

# Select only specified columns
combined_data_selected <- combined_data[, ..columns_to_select]

# Save final environmental exposure data (long format: one row per address period)
# Change the directory as needed
#combined_data_selected |> readr::write_csv("Y:/data/modified_degauss/env_data_long_child.csv")
combined_data_selected |> readr::write_csv("Y:/data/modified_degauss/env_data_long_dyad.csv")

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache

# Finally, delete the 'temp' folder.

# Final cleaning (NO2) ---------------------------------------------------------
# Combines NO2 exposure summaries from multiple batches

temp_folder <-   "W:/Data/Tan/temp/"
files <- paste0(temp_folder, "/temp_degauss_dyad", 1:6, "/d_no2_summary.rds")

# Combine NO2 summaries from all batches
combined_data <- rbindlist(lapply(files, read_rds), use.names = TRUE, fill = TRUE)

setDT(combined_data)
setorder(combined_data, recip)

# Save final NO2 summary data (one row per child: average NO2 exposure during pregnancy)
# Change the directory as needed
#combined_data |> readr::write_csv("Y:/data/modified_degauss/no2_summary_infancy.csv")
combined_data |> readr::write_csv("Y:/data/modified_degauss/no2_summary_pregnancy.csv")

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache

# Finally, delete the 'temp' folder.

# Final cleaning (BC) ---------------------------------------------------------
# Combines black carbon exposure summaries from multiple batches

temp_folder <-   "W:/Data/Tan/temp/"
files <- paste0(temp_folder, "/temp_degauss_dyad", 1:6, "/d_bc_summary.rds")

# Combine BC summaries from all batches
combined_data <- rbindlist(lapply(files, read_rds), use.names = TRUE, fill = TRUE)

setDT(combined_data)
setorder(combined_data, recip)

# Save final BC summary data (one row per child: average BC exposure during pregnancy)
# Change the directory as needed
#combined_data |> readr::write_csv("Y:/data/modified_degauss/bc_summary_infancy.csv")
combined_data |> readr::write_csv("Y:/data/modified_degauss/bc_summary_pregnancy.csv")

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache

# Deprivation index -------------------------------------------------------
# Combines deprivation index data from multiple batches for Britt's project

temp_folder <-   "W:/Data/Tan/temp/"
files <- paste0(temp_folder, "/temp_degauss_dyad", 1:6, "/temp_geocoded_deprivation_britt.fst")

# Combine deprivation index data from all batches
combined_data <- rbindlist(
  lapply(files, function(file) {
    read_fst(file, as.data.table = TRUE) %>% 
      mutate_all(as.character)  # Convert all to character for consistency
  }),
  use.names = TRUE,
  fill = TRUE
)

# Rename EQI columns to handle duplicate column names from joins
# "first" refers to the first join, "second" to the second join
setnames(combined_data, "eqi_OverallEQI", "eqi_OverallEQI_first")
setnames(combined_data, "i.eqi_OverallEQI", "eqi_OverallEQI_second")

setnames(combined_data, "eqi_RUCA1_EQI", "eqi_RUCA1_EQI_first")
setnames(combined_data, "i.eqi_RUCA1_EQI", "eqi_RUCA1_EQI_second")

setnames(combined_data, "eqi_RUCA2_EQI", "eqi_RUCA2_EQI_first")
setnames(combined_data, "i.eqi_RUCA2_EQI", "eqi_RUCA2_EQI_second")

setnames(combined_data, "eqi_RUCA3_EQI", "eqi_RUCA3_EQI_first")
setnames(combined_data, "i.eqi_RUCA3_EQI", "eqi_RUCA3_EQI_second")

setnames(combined_data, "eqi_RUCA4_EQI", "eqi_RUCA4_EQI_first")
setnames(combined_data, "i.eqi_RUCA4_EQI", "eqi_RUCA4_EQI_second")

setnames(combined_data, "eqi_RUCA5_EQI", "eqi_RUCA5_EQI_first")
setnames(combined_data, "i.eqi_RUCA5_EQI", "eqi_RUCA5_EQI_second")

setDT(combined_data)
setorder(combined_data, recip, start_date, end_date)

# Select deprivation index variables for Britt's project
# Includes all deprivation/socioeconomic indices and redlining/relocation
combined_data_britt <- combined_data %>% 
  dplyr::select(recip, 
                start_date, end_date,
                starts_with("adi_"),  # Area Deprivation Index
                starts_with("svi_"),  # Social Vulnerability Index
                starts_with("coi_"),  # Child Opportunity Index
                starts_with("eji_"),  # Environmental Justice Index
                starts_with("cre_"),  # Climate and Economic Justice
                starts_with("dci_"),  # Distressed Communities Index
                starts_with("ndi_"),  # Neighborhood Deprivation Index
                starts_with("nses_"), # Neighborhood Socioeconomic Status
                starts_with("sdi_"),  # Social Deprivation Index
                starts_with("eqi_"),  # Environmental Quality Index
                redlining,            # Historical redlining grade
                relocation,           # Relocation indicator
  ) 

# Save final deprivation index data (long format: one row per address period)
#combined_data_britt %>% write_csv("Y:/Britt_preliminary_data/preliminary_analysis_data/deprivation_index_long.csv")
#combined_data_britt %>% write_csv("Y:/data/modified_degauss/deprivation_index_long.csv")

# tenncare data for Britt
#tenncare <- read_rds("Y:/Aki_env_data_test/TennCare/asthma_analysis/child_cohort_temp.rds")
#tenncare %>% 
#  write_csv("Y:/Britt_preliminary_data/preliminary_analysis_data/tenncare_data_wide.csv")
