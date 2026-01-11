# ============================================================================
# Road Density Assessment
# ============================================================================
# This script calculates road density (total length of roads per unit area)
# within 500m buffers around each address for different road types:
# - S1100: Primary roads (interstates, major highways)
# - S1200: Secondary roads (major arterials)
# - S1400: Local roads
# ============================================================================

# Road density ----------------------------------------------------------

# Load geocoded data with census, road proximity, greenspace, and deprivation data
d <- read_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace_dep_aadt.rds')) 

# Extract geometry for buffer creation
# Create a separate spatial object with only geometry column
t <- d %>% 
  dplyr::select(geometry) %>% 
  as_tibble() %>% 
  st_as_sf()

# Create 500m radius buffers around each address location
# nQuadSegs = 1000 provides high resolution for buffer boundaries
# These buffers are used to calculate road density (road length per unit area)
buffers <- st_buffer(t, dist = 500, nQuadSegs = 1000)

# Calculate road density for S1100 roads (primary roads: interstates, major highways)
# Road density = total length of roads within 500m buffer (in meters)
roads1100_projected <- readr::read_rds('data/roads1100_projected_2011.rds')
d$length_1100 <- suppressWarnings(get_line_length(roads = roads1100_projected))

# Calculate road density for S1200 roads (secondary roads: major arterials)
roads1200_projected <- readr::read_rds('data/roads1200_projected_2011.rds')
d$length_1200 <- suppressWarnings(get_line_length(roads = roads1200_projected))

# Calculate road density for S1400 roads (local roads)
roads1400_projected <- readr::read_rds('data/roads1400_projected_2011.rds')
d$length_1400 <- suppressWarnings(get_line_length(roads = roads1400_projected))

# Convert to data.table and save
setDT(d)
d |> readr::write_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace_dep_aadt_road_density.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
