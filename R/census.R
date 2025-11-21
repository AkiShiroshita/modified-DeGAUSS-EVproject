# ============================================================================
# Census Boundary & Redlining Assignment
# ============================================================================
# This script assigns census boundaries (block groups and tracts) and
# historical redlining grades to each address location.
# Redlining grades (A-D) indicate historical neighborhood investment patterns.
# ============================================================================

# Census boundary & redlining---------------------------------------------------------

# Load nested geocoded data
d <- read_rds(paste0(temp_folder, '/', 'temp_geocoded_nested.rds'))

# Assign 2010 Census block group boundaries
# Block groups are the smallest census geographic unit
blk_grps_sf_2010 <- read_rds('data/block_group_shp_all_TN_2010.rds')
# Spatial join: assign block group ID to each address
d <- suppressWarnings( sf::st_join(d, blk_grps_sf_2010, left = TRUE, largest = TRUE) )

# Assign 2020 Census block group boundaries
# Using 2020 boundaries for more recent data linkage
blk_grps_sf_2020 <- read_rds('data/block_group_shp_all_TN_2020.rds')
# Spatial join: assign block group ID to each address
d <- suppressWarnings( sf::st_join(d, blk_grps_sf_2020, left = TRUE, largest = TRUE) )

# Assign historical redlining grades
# Redlining was a discriminatory practice from the 1930s-1960s
# Grades: A (best, green), B (blue), C (yellow), D (hazardous, red)
redlining <- sf::read_sf('data/mappinginequality.json')

# Filter for Tennessee and valid grades
setDT(redlining)
redlining <- redlining[state == "TN" & grade %in% c("A", "B", "C", "D"), .(grade, geometry)]
setnames(redlining, "grade", "redlining")
# Transform to projected CRS for spatial operations
redlining <- sf::st_as_sf(redlining) |> sf::st_transform(5072)

# Spatial join: assign redlining category to each address
d <- suppressWarnings( sf::st_join(d, redlining, left = TRUE, largest = TRUE) )

# Save data with census and redlining assignments
d |> write_rds(paste0(temp_folder, '/', 'temp_geocoded_census.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
