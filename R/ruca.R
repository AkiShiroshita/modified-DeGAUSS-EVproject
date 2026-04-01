# ============================================================================
# RUCA Assignment (for Britt's Project)
# ============================================================================
# This script joins Rural-Urban Commuting Area (RUCA) codes to each address
# after deprivation indices have been assigned. RUCA classifies ZIP code areas
# by population density and commuting flows (urban core, suburban, rural, etc.).
#
# Data source: University of Washington Rural Health Research Center
# (Tennessee extract; see data/ruca2_TN.xls).
# Reference: https://depts.washington.edu/uwruca/ruca-download.php
# ============================================================================

# RUCA (Britt's project) ---------------------------------------------------------

# Load geocoded records with deprivation indices from the prior pipeline step
d <- read_fst(paste0(temp_folder, '/', 'temp_geocoded_deprivation_britt.fst'))

# RUCA lookup table (ZIP-level); coerce to character for reliable joins
ruca <- read_excel("data/ruca2_TN.xls")
ruca <- ruca %>% mutate(across(everything(), as.character)) |>
  rename(zip = ZIPA)

# Attach RUCA fields by ZIP code
d <- ruca[d, on = 'zip']

# Save with RUCA appended for downstream exposure or analysis steps
d |> write_fst(paste0(temp_folder, '/', 'temp_geocoded_deprivation_britt_ruca.fst'), compress = "100")
