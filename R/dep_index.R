# ============================================================================
# Deprivation Index Assignment
# ============================================================================
# This script assigns area-level deprivation/socioeconomic status indices
# to each address based on census tract boundaries.
# Deprivation indices measure neighborhood-level socioeconomic disadvantage.
# ============================================================================

# Deprivation index -------------------------------------------------------

# Load geocoded data with census, road proximity, and greenspace data
d <- readr::read_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace.rds'))

tracts10 <- readr::read_rds('data/tracts_2010_sf_5072_TN.rds')

d <- sf::st_join(d, tracts10) 

d <- data.table::as.data.table(d)


dep_index15 <- readr::read_rds('data/tract_dep_index_15.rds')
setDT(dep_index15)
setnames(dep_index15, 'census_tract_fips', 'fips_tract_id')

d <- dep_index15[d, on = 'fips_tract_id']
setnames(d, "fips_tract_id", "census_tract_id")

d <- sf::st_as_sf(d)

d |> readr::write_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace_dep.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
