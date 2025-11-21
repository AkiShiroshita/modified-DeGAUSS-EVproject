# ============================================================================
# Deprivation Index Assignment (for Britt's Project)
# ============================================================================
# This script assigns multiple area-level deprivation and socioeconomic
# indices to each address based on census boundaries. These indices are used
# for research on neighborhood-level socioeconomic factors.
# 
# Indices assigned:
# - ADI: Area Deprivation Index
# - SVI: Social Vulnerability Index
# - COI: Child Opportunity Index
# - EJI: Environmental Justice Index
# - CRE: Climate and Economic Justice Screening Tool
# - NDI: Neighborhood Deprivation Index
# - NSES: Neighborhood Socioeconomic Status
# - SDI: Social Deprivation Index
# - EQI: Environmental Quality Index
# - DCI: Distressed Communities Index
# ============================================================================

# Deprivation index (for Britt's project)---------------------------------------------------------

# Load geocoded data with census boundaries
d <- read_rds(paste0(temp_folder, '/', 'temp_geocoded_census.rds'))

# Convert census IDs and redlining to character for joining
# This ensures proper matching when joining with index data
d <- d %>% mutate(across(census_block_group_id_2010:redlining, as.character))

# Assign Area Deprivation Index (ADI) - block group level (2020)
# ADI measures neighborhood-level socioeconomic disadvantage
adi <- read_fst("data/adi.fst", as.data.table = TRUE)
adi <- adi %>% mutate(across(everything(), as.character))
d <- adi[d, on = 'census_block_group_id_2020']

# Assign Social Vulnerability Index (SVI) - tract level (2020)
# SVI measures community resilience to disasters and health emergencies
svi <- read_fst("data/svi.fst", as.data.table = TRUE)
svi <- svi %>% mutate(across(everything(), as.character))
d <- svi[d, on = 'census_tract_id_2020']

# Assign Child Opportunity Index (COI) subdomains - tract level (2020)
# COI measures neighborhood resources and conditions that matter for children
coi <- read_fst("data/coi_subdomains.fst", as.data.table = TRUE)
coi <- coi %>% mutate(across(everything(), as.character))
d <- coi[d, on = 'census_tract_id_2020']

# Assign Child Opportunity Index (COI) overall - tract level (2020)
coi <- read_fst("data/coi_overall.fst", as.data.table = TRUE)
coi <- coi %>% mutate(across(everything(), as.character))
d <- coi[d, on = 'census_tract_id_2020']

# Assign Environmental Justice Index (EJI) - tract level (2020)
# EJI measures cumulative environmental and social impacts
eji <- read_fst("data/eji.fst", as.data.table = TRUE)
eji <- eji %>% mutate(across(everything(), as.character))
d <- eji[d, on = 'census_tract_id_2020']

# Assign Climate and Economic Justice Screening Tool (CRE) - tract level (2020)
# CRE identifies communities overburdened by pollution and climate change
cre <- read_fst("data/cre.fst", as.data.table = TRUE)
cre <- cre %>% mutate(across(everything(), as.character))
d <- cre[d, on = 'census_tract_id_2020']

# Assign Neighborhood Deprivation Index (NDI) - tract level (2010)
# NDI measures neighborhood socioeconomic disadvantage
ndi <- read_fst("data/ndi.fst", as.data.table = TRUE)
ndi <- ndi %>% mutate(across(everything(), as.character))
d <- ndi[d, on = 'census_tract_id_2010']

# Assign Neighborhood Socioeconomic Status (NSES) - tract level (2010)
# NSES measures neighborhood-level socioeconomic position
nses <- read_fst("data/nses.fst", as.data.table = TRUE)
nses <- nses %>% mutate(across(everything(), as.character))
d <- nses[d, on = 'census_tract_id_2010']

# Assign Social Deprivation Index (SDI) - tract level (2010)
# SDI measures area-level social disadvantage
sdi <- read_fst("data/sdi.fst", as.data.table = TRUE)
sdi <- sdi %>% mutate(across(everything(), as.character))
d <- sdi[d, on = 'census_tract_id_2010']

# Assign Environmental Quality Index (EQI) overall - tract level (2010)
# EQI measures overall environmental quality
eqi <- read_fst("data/eqi_overall.fst", as.data.table = TRUE)
eqi <- eqi %>% mutate(across(everything(), as.character))
d <- eqi[d, on = 'census_tract_id_2010']

# Assign Environmental Quality Index (EQI) components - tract level (2010)
# EQI components: air, water, land, built environment, sociodemographic
eqi <- read_fst("data/eqi_components.fst", as.data.table = TRUE)
eqi <- eqi %>% mutate(across(everything(), as.character))
d <- eqi[d, on = 'census_tract_id_2010']

# Unnest nested data to access individual address records
d <- unnest(d, cols = c(data))

# Assign Distressed Communities Index (DCI) - ZIP code level
# DCI measures economic distress at the ZIP code level
dci <- read_fst("data/dci.fst", as.data.table = TRUE)
dci <- dci %>% mutate(across(everything(), as.character))
d <- dci[d, on = 'zip'] # Join on ZIP code (change zip code name if needed)

# Calculate relocation indicator
# Identifies when a person moved to a different location (different coordinates)
coords <- sf::st_coordinates(sf::st_transform(st_as_sf(d), 5072))
d_location <- d
d_location[, `:=` (lon = coords[,1], lat = coords[,2])]

# Flag relocations: 1 if coordinates changed from previous record, 0 otherwise
# relocation = 1 indicates the person moved to a new address
d_location <- d_location[, .(
  relocation = fifelse(lon != data.table::shift(lon) & lat != data.table::shift(lat), 1, 0, na = 0)
), by = recip]

# Remove geometry column (not needed for final output)
d <- d %>% 
  dplyr::select(-geometry)

# Remove recip from location data before binding
d_location <- d_location %>% 
  dplyr::select(-recip)

# Combine deprivation indices with relocation indicator
d <- cbind(d, d_location)

# Save data with all deprivation indices and relocation indicator
d |> write_fst(paste0(temp_folder, '/', 'temp_geocoded_deprivation_britt.fst'), compress = "100")
