# =============================================================================
# Script: deprivation_make_data.R
# Date:   2026-06-01
# Purpose: Download and process census geography shapefiles and multiple
#          neighborhood deprivation/opportunity indices for Tennessee census
#          block groups and tracts, exporting each as a .fst or .rds file.
#
# Main Steps:
#   1. Load packages
#   2. Download 2020 block group shapefiles from TIGER for Tennessee
#   3. Download 2010 block group shapefiles from TIGER for Tennessee
#   4. Process NHGIS block group shapefiles for 1990-2020
#   5. Process and export ADI (Area Deprivation Index)
#   6. Process and export SVI (Social Vulnerability Index)
#   7. Process and export COI (Child Opportunity Index) subdomains and overall
#   8. Process and export EJI (Environmental Justice Index)
#   9. Process and export CRE (Community Resilience Estimates)
#  10. Process and export DCI (Distressed Communities Index)
#  11. Process and export NDI (Neighborhood Deprivation Index)
#  12. Process and export NSES (Neighborhood Socioeconomic Status)
#  13. Compute and export ICE (Index of Concentration at the Extremes)
#  14. Process and export SDI (Social Deprivation Index)
#  15. Process and export EQI (Environmental Quality Index) overall and components
# =============================================================================

# Load packages ----

pacman::p_load(
  "tidyverse",
  "tidylog",
  "readxl",
  "sf",
  "tigris",
  "fst"
)

# Download 2020 TIGER block group shapefiles ----

# Build a state lookup table for Tennessee using TIGRIS. STATEFP < 57 excludes
# territories. The file naming convention matches TIGER 2020PL's block-group
# files (suffix _bg20 for 2020 boundaries).
# year 2020
states <- tigris::states(year = 2020) %>%
  sf::st_drop_geometry() %>%
  arrange(STATEFP) %>%
  dplyr::select(STATEFP, NAME) %>%
  mutate(state_folder = paste0(STATEFP, "_", toupper(NAME)),
         state_folder = stringr::str_replace_all(state_folder, " ", "_"),
         fl_name = paste0('tl_2020_', STATEFP, '_bg20')) %>% # _bg10
  filter(as.numeric(STATEFP) < 57)

# Restrict to Tennessee (STATEFP == 47).
states <- states %>%
  filter(STATEFP == 47)

# Helper that downloads, unzips, reads, and reprojects a single block-group
# shapefile from the Census TIGER FTP. CRS 5072 (Albers Equal Area, CONUS)
# is used for consistent area-based operations downstream.
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

# Iterate over states (here just TN) with error protection via possibly().
block_group_shp <- pmap(list(states$fl_name, states$state_folder, states$STATEFP),
                        possibly(get_block_group_shp, NA_real_))
names(block_group_shp) <- states$NAME

block_group_shp_all <- block_group_shp[[1]]

# Standardize column names and derive census tract ID by truncating block-group
# GEOID to 11 characters (state + county + tract).
block_group_shp_all <- block_group_shp_all |>
  dplyr::select(census_block_group_id_2020 = GEOID20,
                county_fips2020 = COUNTYFP20,
                geometry) |>
  mutate(census_tract_id_2020 = as.numeric(stringr::str_sub(census_block_group_id_2020, 1, 11)))

block_group_shp_all |> write_rds("output/block_group_shp_all_TN_2020.rds")

# Download 2010 TIGER block group shapefiles ----

# Same process as 2020 but targets 2010 block-group boundaries (_bg10).
# Note: tigris is still called with year = 2020 to get the state metadata,
# but the file suffix switches to _bg10 to pull the 2010 boundary vintage.
# year 2010
states <- tigris::states(year = 2020) %>%
  sf::st_drop_geometry() %>%
  arrange(STATEFP) %>%
  dplyr::select(STATEFP, NAME) %>%
  mutate(state_folder = paste0(STATEFP, "_", toupper(NAME)),
         state_folder = stringr::str_replace_all(state_folder, " ", "_"),
         fl_name = paste0('tl_2020_', STATEFP, '_bg10')) %>% # _bg20
  filter(as.numeric(STATEFP) < 57)

states <- states %>%
  filter(STATEFP == 47)

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

block_group_shp <- pmap(list(states$fl_name, states$state_folder, states$STATEFP),
                        possibly(get_block_group_shp, NA_real_))
names(block_group_shp) <- states$NAME

block_group_shp_all <- block_group_shp[[1]]

# Rename to 2010-vintage column names; tract ID derived the same way as above.
block_group_shp_all <- block_group_shp_all |>
  dplyr::select(census_block_group_id_2010 = GEOID10,
                county_fips2010 = COUNTYFP10,
                geometry) |>
  mutate(census_tract_id_2010 = as.numeric(stringr::str_sub(census_block_group_id_2010, 1, 11)))

block_group_shp_all |> write_rds("output/block_group_shp_all_TN_2010.rds")

# Process NHGIS block group shapefiles (1990-2020) ----

# NHGIS shapefiles cover four decennial vintages. boundary_year reflects
# which census boundary was used for each data year (1990 and 2000 data both
# use 2000 boundaries as the earliest available NHGIS vintage).
# Base file
# NHGIS: https://www.nhgis.org/
# https://github.com/degauss-org/st_census_tract/blob/master/get_tract_shapes_nhgis.R

year <- c('1990', '2000', '2010', '2020')
boundary_year <- c('2000', '2000', '2010', '2020')

all_blck <- map(
  glue::glue('input/nhgis_shape/nhgis_shape/nhgis0006_shapefile_tl{boundary_year}_470_blck_grp_{year}/TN_blck_grp_{year}.shp'),
  st_read
)

# 1990: Construct a 12-digit block-group ID from NHGIS GISJOIN2 components.
# GISJOIN2 encodes state (chars 1-2), county (chars 4-6), and tract (chars 8 to end-1).
# st_make_valid() fixes any geometry topology errors before downstream spatial joins.
all_blck[[1]] <- all_blck[[1]] %>%
  st_transform(crs=5072) |>
  dplyr::mutate(state_fips = stringr::str_sub(GISJOIN2, 1, 2),
                county_fips = stringr::str_sub(GISJOIN2, 4, 6),
                tract_fips = stringr::str_sub(GISJOIN2, 8, -2),
                census_block_group_id_1990 = glue::glue('{state_fips}{county_fips}{tract_fips}{GROUP}')) %>%
  select(census_block_group_id_1990, geometry) %>%
  mutate(census_block_group_id_1990 = as.character(census_block_group_id_1990)) |>
  sf::st_make_valid()

# 2000: ID is available directly as STFID.
all_blck[[2]] <- all_blck[[2]] %>%
  st_transform(crs=5072) |>
  dplyr::select(census_block_group_id_2000 = STFID,
                geometry) %>%
  mutate(census_block_group_id_2000 = as.character(census_block_group_id_2000)) |>
  sf::st_make_valid()

# 2010: ID is directly available as GEOID10.
all_blck[[3]] <- all_blck[[3]] %>%
  st_transform(crs=5072) |>
  dplyr::select(census_block_group_id_2010 = GEOID10,
                geometry) |>
  sf::st_make_valid()

# 2020: ID is available as GEOID (no year suffix in this vintage).
all_blck[[4]] <- all_blck[[4]] %>%
  st_transform(crs=5072) |>
  dplyr::select(census_block_group_id_2020 = GEOID,
                geometry) %>%
  mutate(census_block_group_id_2020 = as.character(census_block_group_id_2020)) |>
  sf::st_make_valid()

saveRDS(all_blck, "output/TN_all_blck_1990_2020_5072.rds")

# Process ADI (Area Deprivation Index) ----

# ADI 2023 (v4.0.1) from Neighborhood Atlas — block group level, 2020 census.
# ADI 2023
# https://www.neighborhoodatlas.medicine.wisc.edu/
# census block group level
adi <- read_csv("input/adi-download-2023/TN_2023_ADI_Census_Block_Group_v4_0_1.csv")
adi <- adi |>
  dplyr::select(census_block_group_id_2020 = FIPS,
                ADI_NATRANK,
                ADI_STATERNK) |>
  rename_with(~ paste0("adi_", .x), .cols = -census_block_group_id_2020)

adi |> write_fst("output/adi.fst", compress = 100)

# Process SVI (Social Vulnerability Index) ----

# SVI 2022 from ATSDR — census tract level. The .gdb contains an M coordinate
# dimension that must be dropped before geometry operations.
# Overall SVI score available from 2014 onward.
# SVI 2022
# https://www.atsdr.cdc.gov/place-health/php/svi/svi-data-documentation-download.html
# from 2014, the overall score is available.
svi <- st_read("input/SVI_Tennessee_2022/SVI2022_TENNESSEE_tract.gdb")

# Drop the M (measure) dimension — not needed and causes downstream issues.
svi <- svi %>%
  st_zm() # drop M

# Drop geometry for tabular export; recode -999 sentinel values to NA
# (ATSDR uses -999 to flag missing/suppressed data).
svi <- svi %>%
  st_drop_geometry() |>
  dplyr::select(FIPS, AREA_SQMI:Shape_Area) |>
  rename(census_tract_id_2020 = FIPS) |>
  mutate(census_tract_id_2020 = as.numeric(census_tract_id_2020),
         across(everything(), ~ if_else(. == -999, NA_integer_, .))) |>
  rename_with(~ paste0("svi_", .x), .cols = -census_tract_id_2020)

svi |> write_fst("output/svi.fst", compress = 100)

# Process COI (Child Opportunity Index) subdomains ----

# COI 3.0 (2023) — subdomain z-scores for 14 dimensions at 2020 census tracts.
# Filtered to year == 2022 (the most recent release year in this dataset).
# Columns ending in _met are metro-level aggregates not needed here.
# COI3.0
# Child Opportunity Levels, Scores and composite z-scores for 14 subdomains (2020 census tracts)
coi <- read_csv("input/2020 census tracts, subdomains (COI 3.0-2023)/data.csv")

coi <- coi %>%
  filter(year == 2022) %>%
  rename(FIPS = geoid20) %>%
  mutate(FIPS = as.numeric(FIPS)) %>%
  filter(str_detect(FIPS, "^47")) %>%
  dplyr::select(metro_fips:z_SE_WL_met,
                census_tract_id_2020 = FIPS) |>
  dplyr::select(-ends_with("_met")) |>
  rename_with(~ paste0("coi_", .x), .cols = -census_tract_id_2020)

coi |> write_fst("output/coi_subdomains.fst", compress = 100)

# Process COI overall index ----

# COI 3.0 overall index and domain scores — separate input file from subdomains above.
# 2020 census tracts, overall index and domains (COI 3.0-2023)

coi <- read_csv("input/2020 census tracts, overall index and domains (COI 3.0-2023)/data.csv")

coi <- coi %>%
  filter(year == 2022) %>%
  rename(FIPS = geoid20) %>%
  mutate(FIPS = as.numeric(FIPS)) %>%
  filter(str_detect(FIPS, "^47")) %>%
  dplyr::select(c5_COI_nat:z_SE_met,
                census_tract_id_2020 = FIPS) |>
  rename_with(~ paste0("coi_", .x), .cols = -census_tract_id_2020)

coi |> write_fst("output/coi_overall.fst", compress = 100)

# Process EJI (Environmental Justice Index) ----

# EJI 2024 from ATSDR — census tract level, 2020 geographies.
# EJI 2022 used pre-2020 tract IDs, so the 2024 version is required here.
# -999 is the ATSDR sentinel for missing values, recoded to NA for both
# numeric and character columns.
# EJI 2024
# https://www.atsdr.cdc.gov/place-health/php/eji/eji-data-download.html
# EJI 2022 does not use census ID 2020
eji <- st_read("input/EJI_2024_Tennessee_GDB/EJI_2024_Tennessee/EJI_2024_Tennessee.gdb")

eji <- eji |>
  st_drop_geometry() |>
  dplyr::select(E_TOTPOP:Tribe_Flag,
                census_tract_id_2020 = GEOID_2020) |>
  mutate(census_tract_id_2020 = as.numeric(census_tract_id_2020),
         across(where(is.numeric), ~ if_else(. == -999, NA_integer_, .)),
         across(where(is.character), ~ if_else(. == "-999", NA_character_, .))) |>
  rename_with(~ paste0("eji_", .x), .cols = -census_tract_id_2020)

eji |> write_fst("output/eji.fst", compress = 100)

# Process CRE (Community Resilience Estimates) ----

# CRE 2023 — census tract level. Tract ID is assembled from STATE, COUNTY,
# and TRACT fields; filtered to Tennessee (FIPS prefix "47").
cre <- read_csv("input/CRE_23_Tract.csv")

cre <- cre |>
  mutate(census_tract_id_2020 = glue::glue('{STATE}{COUNTY}{TRACT}')) |>
  filter(str_detect(census_tract_id_2020, "^47")) |>
  dplyr::select(census_tract_id_2020, WATER_TRACT:PRED3_PM) |>
  rename_with(~ paste0("cre_", .x), .cols = -census_tract_id_2020)

cre |> write_fst("output/cre.fst", compress = 100)

# Process DCI (Distressed Communities Index) ----

# DCI 2019-2023 — ZIP code level (not census tract). Only the summary score
# and quintile are retained; full component data are not available here.
# score only
# zip-code based
dci <- read_excel("input/DCI-2019-2023-Scores-Only-11.xlsx")

dci <- dci |>
  dplyr::select(zip =`Zip Code`, `2019-2023 Distress Score`, `Quintile (5=Distressed)`) |>
  rename_with(~ paste0("dci_", .x), .cols = -zip)

dci |> write_fst("output/dci.fst", compress = 100)

# Process NDI (Neighborhood Deprivation Index) ----

# NDI from Singh (2003) — 2010 census tracts. Filtered to Tennessee (prefix "47").
# 2010 census tracts
ndi <- read_csv("input/NeighDeprvIndex_USTracts.csv")

ndi <- ndi |>
  rename(census_tract_id_2010 = TractID) |>
  filter(str_detect(census_tract_id_2010, "^47")) |>
  dplyr::select(census_tract_id_2010, NDI:PctUnempl) |>
  rename_with(~ paste0("ndi_", .x), .cols = -census_tract_id_2010)

ndi |> write_fst("output/ndi.fst", compress = 100)

# Process NSES (Neighborhood Socioeconomic Status) ----

# NSES was exported from ArcGIS Online and pasted into an Excel file;
# column names include trailing asterisks from the ArcGIS field alias.
# ArcGIS: https://www.arcgis.com/home/item.html?id=2a98d90305364e71866443af2c9b5d06
# import and copy&paste the attributes
nses <- read_excel("input/NSES_TN.xlsx")

nses <- nses |>
  dplyr::select(census_tract_id_2010 = `GEOID10 *`,
                `High school graduates *`:`unemployment rate *`) |>
  rename_with(~ paste0("nses_", .x), .cols = -census_tract_id_2010)

nses |> write_fst("output/nses.fst", compress = 100)

# Compute ICE (Index of Concentration at the Extremes) ----

# ICE measures economic and racial segregation simultaneously. It contrasts
# high-income White non-Hispanic (WNH) households against low-income
# people-of-color households within each tract, divided by total households.
# ACS 5-year estimates: year = 2015 covers 2011-2015.
# another option
# https://github.com/geomarker-io/hh_acs_measures/blob/main/make_hh_acs_data.R
library(tidycensus)

# year = 2015 → covers 2011–2015
# year = 2023 → covers 2019–2023
d <- get_acs(
  geography = 'tract',
  state = "Tennessee",
  year = 2015,
  survey = "acs5",
  variables = c(
    'B19001_001', # ice denom
    # high income (> 100k) white non hispanic households
    'B19001H_014', # white non hispanic hh, income $100,000 to $124,999
    'B19001H_015', # white non hispanic hh, income $125,000 to $149,999
    'B19001H_016', # white non hispanic hh, income $150,000 to $199,999
    'B19001H_017', # white non hispanic hh, income $200,000 or more
    # low income (< 25k) all race households
    'B19001_002', # all race hh, income less than $10,000
    'B19001_003', # all race hh, income $10,000 to $14,999
    'B19001_004', # all race hh, income $15,000 to $19,999
    'B19001_005', # all race hh, income $20,000 to $24,999
    # low income (< 25k) white non hispanic households
    'B19001H_002', # white non hispanic hh, income less than $10,000
    'B19001H_003', # white non hispanic hh, income $10,000 to $14,999
    'B19001H_004', # white non hispanic hh, income $15,000 to $19,999
    'B19001H_005' # white non hispanic hh, income $20,000 to $24,999
  )
) |>
  select(-NAME, -moe) |>
  pivot_wider(names_from = variable, values_from = estimate) |>
  mutate(
    high_inc_wnh = B19001H_014 +
      B19001H_015 +
      B19001H_016 +
      B19001H_017,
    low_inc_all = B19001_002 + B19001_003 + B19001_004 + B19001_005,
    low_inc_wnh = B19001H_002 +
      B19001H_003 +
      B19001H_004 +
      B19001H_005,
    # low_inc_poc = low-income households that are not White non-Hispanic
    low_inc_poc = low_inc_all - low_inc_wnh,
    ice = (high_inc_wnh - low_inc_poc) / B19001_001 |> round(3)
  ) |>
  dplyr::select(census_tract_id_2020 = GEOID, ice)

# Process SDI (Social Deprivation Index) ----

# SDI (2015-2019 ACS) — 2010 census tracts. Filtered to Tennessee.
# 2010 census tracts
sdi <- read_csv("input/rgcsdi-2015-2019-censustract.csv")

sdi <- sdi |>
  rename(census_tract_id_2010 = CENSUSTRACT_FIPS) |>
  filter(str_detect(census_tract_id_2010, "^47")) |>
  rename_with(~ paste0("sdi_", .x), .cols = -census_tract_id_2010)

sdi |> write_fst("output/sdi.fst", compress = 100)


# Process EQI (Environmental Quality Index) overall scores ----

# EQI 2011-2015 from EPA — 2010 census tracts. Filtered to Tennessee.
# 2010 census tracts
# 2011-2015

eqi <- read_csv("input/Tract EQI/Tract EQI/2011-2015/Tract_EQI_Scores_VC_2011_2015.csv")

eqi <- eqi |>
  rename(census_tract_id_2010 = tract) |>
  filter(str_detect(census_tract_id_2010, "^47")) |>
  dplyr::select(-`...1`) |>
  rename_with(~ paste0("eqi_", .x), .cols = -census_tract_id_2010)

eqi |> write_fst("output/eqi_overall.fst")

# Process EQI component variables ----

# PCA-derived input variables for the EQI (both transformed and non-transformed).
# Two columns share the name "education_area" in the source file; they are
# disambiguated here with _first / _second suffixes before renaming.
eqi <- read_csv("input/Tract EQI/Tract EQI/2011-2015/Tract_EQI_PCA_Variables_Transformed_and_Nontransformed_2011_2015.csv")

eqi <- eqi |>
  rename(census_tract_id_2010 = tract,
         education_area_first = `education_area...16`,
         education_area_second = `education_area...17`) |>
  filter(str_detect(census_tract_id_2010, "^47")) |>
  dplyr::select(-State, -County) |>
  rename_with(~ paste0("eqi_", .x), .cols = -census_tract_id_2010)

eqi |> write_fst("output/eqi_components.fst", compress = 100)
