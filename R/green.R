# ============================================================================
# Greenspace Exposure Assessment
# ============================================================================
# This script calculates greenspace exposure using Enhanced Vegetation Index (EVI)
# at multiple buffer distances (500m, 1500m, 2500m).
# EVI is a measure of vegetation greenness (higher = more vegetation).
# ============================================================================

# Greenspace --------------------------------------------------------------

# Load geocoded data with census and road proximity data
d <- readr::read_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road.rds'))

# Load EVI raster data (June 2018, projected to CRS 5072)
# EVI values are stored as integers (multiplied by 10000)
evi_2018 <- terra::rast("data/evi_June_2018_5072.tif")

# Calculate mean EVI within 500m buffer
# Represents immediate neighborhood greenspace
d$evi_500 <- get_evi_buffer(500)

# Calculate mean EVI within 1500m buffer
# Represents local area greenspace
d$evi_1500 <- get_evi_buffer(1500)

# Calculate mean EVI within 2500m buffer
# Represents broader neighborhood greenspace
d$evi_2500 <- get_evi_buffer(2500)

# Save data with greenspace measures
d |> readr::write_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
