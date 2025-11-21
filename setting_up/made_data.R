# ============================================================================
# Data Preparation Script
# ============================================================================
# This script prepares all reference data needed for the environmental
# exposure assessment pipeline. It downloads and processes:
# 1. Census boundaries (block groups and tracts for 2010 and 2020)
# 2. Road network data (primary and secondary roads)
# 3. Traffic density data (AADT - Annual Average Daily Traffic)
# 4. Greenspace data (EVI - Enhanced Vegetation Index)
# 5. Deprivation index data
# 6. NO2 concentration grid data
# 7. Black Carbon (BC) concentration grid data
# 
# Note: This script should be run once to set up the data directory before
# running the main exposure assessment pipeline.
# ============================================================================

# Set-up ---------------------------------------------------------
# Load required packages for data preparation

pacman::p_load(
  "remotes",
  "devtools",
  "knitr",
  "tidyverse",
  "tidylog",
  "data.table",
  "readxl",
  "tidylog",
  "lubridate",
  "writexl",
  "here",
  "mappp",
  "furrr",
  "future",
  "sf",
  "terra",
  "glue",
  "raster",
  "exactextractr",
  "fst",
  "OfflineGeocodeR",
  "dht"
)

# Census data------------------------------------------------------------------
# Download and prepare census boundary data (block groups and tracts)
# Census boundaries are used to assign area-level characteristics to addresses

# Note: Install tigris package if needed
# devtools::install_github('walkerke/tigris')

# Year 2020 Census Block Groups
# Get state information for downloading census data
states <- tigris::states(year = 2020) %>%
  sf::st_drop_geometry() %>%
  arrange(STATEFP) %>%
  dplyr::select(STATEFP, NAME) %>%
  mutate(state_folder = paste0(STATEFP, "_", toupper(NAME)),
         state_folder = stringr::str_replace_all(state_folder, " ", "_"),
         fl_name = paste0('tl_2020_', STATEFP, '_bg20')) %>% # Block group file name
  filter(as.numeric(STATEFP) < 57)  # Filter to US states (exclude territories)

# Filter to Tennessee only (STATEFP = 47)
states <- states %>% 
  filter(STATEFP == 47)

# Function to download and process census block group shapefiles
# Downloads from US Census Bureau TIGER/Line files
get_block_group_shp <- function(fl_name, state_folder, state_fips) {
  fl.name.zip <- paste0(fl_name, '.zip')
  # Download ZIP file from Census Bureau
  download.file(paste0('https://www2.census.gov/geo/tiger/TIGER2020PL/STATE/', state_folder, "/",
                       state_fips, "/", fl.name.zip),
                destfile=fl.name.zip)
  unzip(fl.name.zip)
  unlink(fl.name.zip)  # Delete ZIP file after extraction
  fl.name.shp <- paste0(fl_name, '.shp')
  # Read shapefile and transform to Albers Equal Area (CRS 5072) for area calculations
  d.tmp <- sf::read_sf(fl.name.shp) %>% sf::st_transform(5072)
  unlink(list.files(pattern = fl_name))  # Clean up extracted files
  return(d.tmp)
}

# Download block group shapefiles for all states (in this case, just Tennessee)
block_group_shp <- pmap(list(states$fl_name, states$state_folder, states$STATEFP),
                        possibly(get_block_group_shp, NA_real_))
names(block_group_shp) <- states$NAME

# Extract Tennessee block groups
block_group_shp_all <- block_group_shp[[1]]

# Select and rename columns, create tract ID from block group ID
# Block group ID (12 digits) = State (2) + County (3) + Tract (6) + Block Group (1)
# Tract ID (11 digits) = first 11 digits of block group ID
block_group_shp_all <- block_group_shp_all |> 
  dplyr::select(census_block_group_id_2020 = GEOID20,
                county_fips2020 = COUNTYFP20,
                geometry) |> 
  mutate(census_tract_id_2020 = stringr::str_sub(census_block_group_id_2020, 1, 11))

# Save 2020 block group boundaries for Tennessee
block_group_shp_all |> write_rds("output/block_group_shp_all_TN_2020.rds")

# Year 2010 Census Block Groups
# 2010 boundaries are needed for historical data linkage
# Note: Using 2020 state boundaries but downloading 2010 block group data
states <- tigris::states(year = 2020) %>%
  sf::st_drop_geometry() %>%
  arrange(STATEFP) %>%
  dplyr::select(STATEFP, NAME) %>%
  mutate(state_folder = paste0(STATEFP, "_", toupper(NAME)),
         state_folder = stringr::str_replace_all(state_folder, " ", "_"),
         fl_name = paste0('tl_2020_', STATEFP, '_bg10')) %>% # 2010 block group file name
  filter(as.numeric(STATEFP) < 57)

# Filter to Tennessee only
states <- states %>% 
  filter(STATEFP == 47)

# Function to download 2010 block group shapefiles (same as above)
get_block_group_shp <- function(fl_name, state_folder, state_fips) {
  fl.name.zip <- paste0(fl_name, '.zip')
  download.file(paste0('https://www2.census.gov/geo/tiger/TIGER2020PL/STATE/', state_folder, "/",
                       state_fips, "/", fl.name.zip),
                destfile=fl.name.zip)
  unzip(fl.name.zip)
  unlink(fl.name.zip)
  fl.name.shp <- paste0(fl_name, '.shp')
  d.tmp <- sf::read_sf(fl.name.shp) %>% sf::st_transform(5072)
  unlink(list.files(pattern = fl_name))
  return(d.tmp)
}

# Download 2010 block group shapefiles
block_group_shp <- pmap(list(states$fl_name, states$state_folder, states$STATEFP),
                        possibly(get_block_group_shp, NA_real_))
names(block_group_shp) <- states$NAME

block_group_shp_all <- block_group_shp[[1]]

# Select and rename columns for 2010 data
# GEOID10 is the 2010 block group identifier
block_group_shp_all <- block_group_shp_all |> 
  dplyr::select(census_block_group_id_2010 = GEOID10,
                county_fips2010 = COUNTYFP10,
                geometry) |> 
  mutate(census_tract_id_2010 = stringr::str_sub(census_block_group_id_2010, 1, 11))

# Save 2010 block group boundaries for Tennessee
block_group_shp_all |> write_rds("output/block_group_shp_all_TN_2010.rds")

# Road data ---------------------------------------------------------------
# Download and prepare road network data for proximity and density calculations
# MTFCC codes: S1100 = Primary roads, S1200 = Secondary roads

# Year 2018 Road Data (used by original DeGAUSS)

# S1100: Primary roads (interstates and major highways)
roads1100 <- tigris::primary_roads(year = "2018")
# Transform from WGS84 (CRS 4326) to Albers Equal Area (CRS 5072) for distance calculations
roads1100_projected <- sf::st_transform(roads1100, crs = 5072)

roads1100_projected |> write_rds('data/roads1100_projected.rds', compress = 'gz')

# S1200: Secondary roads (major arterials)
# Download primary and secondary roads, then filter to S1200 only
roads1200 <- tigris::primary_secondary_roads(state = "TN", year = "2018")
roads1200_projected <- sf::st_transform(roads1200, crs = 5072)

# Filter to S1200 (secondary roads) only
# MTFCC = "S1200" indicates secondary roads
roads1200_projected <- roads1200_projected %>% 
  filter(MTFCC == 'S1200')

roads1200_projected |> write_rds('data/roads1200_projected.rds', compress = 'gz')

# Year 2011 Road Data
# 2011 data may be used for historical exposure assessment

# S1100: Primary roads for 2011
roads1100 <- tigris::primary_roads(year = "2011")
roads1100_projected <- sf::st_transform(roads1100, crs = 5072)

roads1100_projected |> write_rds('data/roads1100_projected_2011.rds', compress = 'gz')

# S1200: Secondary roads for 2011
roads1200 <- tigris::primary_secondary_roads(state = "TN", year = "2011")
roads1200_projected <- sf::st_transform(roads1200, crs = 5072)

roads1200_projected <- roads1200_projected %>% 
  filter(MTFCC == 'S1200')

roads1200_projected |> write_rds('data/roads1200_projected_2011.rds', compress = 'gz')

# Traffic density ---------------------------------------------------------
# Download and prepare AADT (Annual Average Daily Traffic) data
# AADT measures the average number of vehicles per day on road segments
# Data source: FHWA HPMS (Highway Performance Monitoring System)

# Download 2017 AADT data from HPMS website
# Note: If download fails, manually download and place in appropriate directory
fl.zip <- 'Tennessee2017.zip' # Change year and state as needed
download.file(glue::glue('https://www.fhwa.dot.gov/policyinformation/hpms/shapefiles/{fl.zip}'),
              destfile=fl.zip)
unzip(fl.zip, exdir = 'Tennessee')
unlink(fl.zip)  # Delete ZIP file after extraction
fl.shp <- list.files(pattern = "shp", path = 'Tennessee')

# Read shapefile
tmp <- sf::st_read(glue::glue('Tennessee/{fl.shp}'))

# Select and rename relevant columns
tmp <- tmp %>% 
  dplyr::select(state_fips = State_Code,
                route_id = Route_ID,
                road_type = F_System,  # Functional system classification
                county_fips = County_Cod,
                aadt = AADT,  # Total AADT
                aadt_single_unit = AADT_Singl,  # Single-unit truck AADT
                aadt_combination = AADT_Combi)  # Combination truck AADT

# Standardize FIPS codes and convert road type codes to labels
# F_System codes: 1=Interstate, 2=Freeway/Expressway, 3=Principal Arterial,
#                 4=Minor Arterial, 5=Major Collector, 6=Minor Collector, 7=Local
tmp <- tmp %>%
  mutate(state_fips = str_pad(state_fips, width = 2, side = "left", pad = "0"),
         county_fips = str_pad(county_fips, width = 2, side = "left", pad = "0"),
         road_type = factor(road_type, levels = c(1, 2, 3, 4, 5, 6, 7),
                            labels = c("Interstate",
                                       "Principal Arterial - Other Freeways and Expressways",
                                       "Principal Arterial - Other",
                                       "Minor Arterial",
                                       "Major Collector",
                                       "Minor Collector",
                                       "Local"),
                            ordered = TRUE))

# Transform to Albers Equal Area for spatial operations
tmp <- st_transform(tmp, 5072)

# Save 2017 AADT data
tmp |> write_rds('data/Tennessee2017AADT.rds', compress = 'gz')

# 2014 AADT Data
# Process manually downloaded 2014 AADT data (if 2017 download unavailable)
# Note: Column names are lowercase in 2014 data
tmp <- read_sf("input/tennessee2014/Tennessee.shp")
tmp <- tmp %>% 
  dplyr::select(state_fips = state_code,
                route_id = route_id,
                road_type = f_system,
                county_fips = county_cod,
                aadt = aadt,
                aadt_single_unit = aadt_singl,
                aadt_combination = aadt_combi)

# Standardize FIPS codes and convert road type codes to labels (same as 2017)
tmp <- tmp %>%
  mutate(state_fips = str_pad(state_fips, width = 2, side = "left", pad = "0"),
         county_fips = str_pad(county_fips, width = 2, side = "left", pad = "0"),
         road_type = factor(road_type, levels = c(1, 2, 3, 4, 5, 6, 7),
                            labels = c("Interstate",
                                       "Principal Arterial - Other Freeways and Expressways",
                                       "Principal Arterial - Other",
                                       "Minor Arterial",
                                       "Major Collector",
                                       "Minor Collector",
                                       "Local"),
                            ordered = TRUE))

tmp <- st_transform(tmp, 5072)

# Save 2014 AADT data
tmp |> write_rds('data/Tennessee2014AADT.rds', compress = 'gz')

# Greenspace --------------------------------------------------------------
# Download Enhanced Vegetation Index (EVI) raster data
# EVI measures vegetation greenness (higher values = more vegetation)
# Data source: DeGAUSS greenspace package

# Download EVI raster for June 2018 (projected to CRS 5072)
# EVI values are stored as integers (multiplied by 10000)
url <- "https://github.com/degauss-org/greenspace/releases/download/0.3.0/evi_June_2018_5072.tif"
destfile <- "data/evi_June_2018_5072.tif"

# Download the file (binary mode for raster data)
download.file(url, destfile, mode = "wb")

# Deprivation index -------------------------------------------------------
# Download and prepare deprivation index data
# Deprivation indices measure area-level socioeconomic disadvantage
# Data source: DeGAUSS dep_index package

# Download 2018 tract-level deprivation index
url <- "https://github.com/degauss-org/dep_index/releases/download/0.2.1/tract_dep_index_2018.rds"
destfile <- "data/tract_dep_index_18.rds"
download.file(url, destfile, mode = "wb")

# Download 2010 census tract boundaries (projected to CRS 5072)
# These are used for spatial joins with deprivation index data
url <- "https://github.com/degauss-org/dep_index/releases/download/0.2.1/tracts_2010_sf_5072.rds"
destfile <- "data/tracts_2010_sf_5072.rds"
download.file(url, destfile, mode = "wb")

# Restrict tract boundaries to Tennessee only
# Tennessee FIPS code starts with "47"
tracts10 <- read_rds('data/tracts_2010_sf_5072.rds')
tracts10 <- tracts10 |> filter(str_detect(fips_tract_id, "^47"))

# Save Tennessee-only tract boundaries
tracts10 |> write_rds('data/tracts_2010_sf_5072_TN.rds', compress = 'gz')

# Deprivation index 2015
# Process custom 2015 deprivation index data (if available)
# This may be from American Community Survey (ACS) data
ACS_deprivation_index_by_census_tracts <- readRDS("ACS_deprivation_index_by_census_tracts.rds")
ACS_deprivation_index_by_census_tracts <- ACS_deprivation_index_by_census_tracts %>%
  ungroup()
# Filter to Tennessee only
ACS_deprivation_index_by_census_tracts <- ACS_deprivation_index_by_census_tracts %>%
  filter(str_detect(census_tract_fips, "^47"))

# Save 2015 deprivation index for Tennessee
ACS_deprivation_index_by_census_tracts |> write_rds("tract_dep_index_15.rds", compress = "gz")


# NO2 ---------------------------------------------------------------------
# Prepare NO2 (nitrogen dioxide) concentration grid data
# NO2 is a traffic-related air pollutant
# Data source: Schwartz et al. NO2 model (1km x 1km grid cells)

# Grid cells
# Read NO2 grid cell centroids (1km x 1km grid)
d_grid <- st_read('data/no2_schwartz/grid.gpkg')

# Create geohash for efficient spatial lookup
# Geohash is a geocoding method that encodes geographic coordinates
# Precision 13 provides high spatial resolution
d_grid <- d_grid %>%
  mutate(gh13 = lwgeom::st_geohash(d_grid, precision = 13))

# Create site index for lookup in daily/monthly NO2 files
# Each grid cell gets a unique sequential index
d_grid <- d_grid %>%
  mutate(site_index = seq_len(nrow(d_grid)))

# Convert to data.table and index on geohash for fast lookups
d_grid_dt <- as.data.table(d_grid, key = 'gh13')

# Export geohashed grid for use in downstream processing
qs::qsave(d_grid_dt, "output/schwartz_grid_geohashed.qs")

# NO2 estimates
# Process daily NO2 data and create monthly aggregates

# Reload grid (needed for processing)
d_grid <- st_read('data/no2_schwartz/grid.gpkg')

# Note: First, unzip 4 folders from Harvard
# Each folder contains daily NO2 estimates for multiple 1km² grid cells
# Data covers approximately 12 months × 17 years = 204 files (minus 1 base file)

# Extract all daily NO2 file names
folder_path <- 'data/no2_schwartz/'
file_names <- list.files(path = folder_path, pattern = '\\.csv.gz$', full.names = TRUE)
file_names <- file_names[-205] # Remove the base file "no2_schwartz/grid.csv.gz"

# Create monthly aggregated NO2 files
# Monthly aggregation reduces file size and speeds up processing
after_files <- gsub("no2_schwartz", "no2_schwartz_monthly", file_names)

# Process each daily file: calculate monthly mean NO2 per grid cell
for (i in 1:length(file_names)) {
  .d <- read_fst(file_names[i])  # Read daily NO2 data
  .ymd <- .d |> pull(date) 
  .date <- as.numeric(format(.ymd[1], "%Y%m"))  # Extract YYYYMM format
  # Calculate monthly mean NO2 for each grid cell
  .d <- .d |> 
    group_by(idx) |>  # Group by grid cell index
    summarise(value = mean(value, na.rm = TRUE)) |>  # Monthly mean
    mutate(date = .date)  # Add month identifier
  # Save monthly aggregated file
  .d |> write_fst(after_files[i])  
}

# BC (Black Carbon) ----------------------------------------------------------------
# Prepare Black Carbon concentration grid data
# Black Carbon is a component of fine particulate matter from combustion sources
# Data source: OM (likely a model output file)

# Create BC grid cells
# Read BC data from model output file
bc <- read.table("OM/output.txt")

# Extract unique grid cell locations
# V1 = grid cell index, V3 = latitude, V4 = longitude, V6 = year-month
grid_bc <- bc |> 
  dplyr::select(idx = V1, lat = V3, lon = V4, YM = V6) |> 
  dplyr::distinct(idx, lat, lon)  # Get unique grid cell locations

# Convert to spatial vector (terra format) for spatial operations
grid_bc <- vect(
  grid_bc[, c("idx", "lon", "lat")],
  geom = c("lon", "lat"),
  crs = "epsg:4326")  # WGS84 coordinate system

# Save BC grid cells as GeoPackage
writeVector(grid_bc, "grid_bc.gpkg", overwrite=TRUE)

# Process BC monthly data
# Create list of all year-month combinations (2000-2017, 12 months each)
bc_months <- expand.grid(year = 2000:2017, month = sprintf("%02d", 1:12)) |>
  apply(1, paste, collapse = "")  # Format as YYYYMM (e.g., "200001", "200002", ...)

library(pbapply)
library(data.table)

# Reload BC data for monthly file creation
bc <- read.table("OM/output.txt")

# Select and format BC data
bc <- bc |> 
  dplyr::select(idx = V1, lat = V3, lon = V4, date = V6) %>% 
  mutate(date = as.integer(date)) %>%  # Convert date to integer (YYYYMM format)
  as.data.table()

# Create monthly BC files (one file per month)
# Uses progress bar (pblapply) to track processing
invisible(pblapply(
  bc_months,  # List of months to process (e.g., "200001", "200002", ...)
  function(YM) {
    # Create output filename for this month
    output_file <- sprintf("bc/%s.fst", YM)
    
    # Skip if file already exists (allows script to be restarted)
    if (file.exists(output_file)) {
      return(NULL)
    }
    
    # Filter BC data for current month and save as compressed fst file
    bc[date == YM] |>
      fst::write_fst(output_file, compress = 100)
    
    return(NULL)
  }
))








