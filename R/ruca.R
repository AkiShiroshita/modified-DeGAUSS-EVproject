# ============================================================================
# RUCA Assignment (for Britt's Project)
# ============================================================================
# This script joins Rural-Urban Commuting Area (RUCA) codes to each address
# after deprivation indices have been assigned. RUCA classifies ZIP code areas
# by population density and commuting flows (urban core, suburban, rural, etc.).
#
# This script also derives a binary Urban / Rural indicator using
# Categorization C (functional urban/rural definition) from the RUCA 2.0 code.
#
# Data source: University of Washington Rural Health Research Center
# (Tennessee extract; see data/ruca2_TN.xls).
# Reference: https://depts.washington.edu/uwruca/ruca-download.php
# ============================================================================

# RUCA ---------------------------------------------------------

# Load geocoded records with deprivation indices from the prior pipeline step
d <- read_fst(paste0(temp_folder, '/', 'temp_geocoded_deprivation_britt.fst'))

# RUCA lookup table (ZIP-level); coerce to character for reliable joins
ruca <- read_excel("data/ruca2_TN.xls")
ruca <- ruca %>% mutate(across(everything(), as.character)) |>
  rename(zip = ZIPA)

# Categorization C (functional Urban vs Rural) from the full RUCA 2.0 decimal code
# UW ZIP files store the code in column RUCA2 (e.g. 1.0, 4.1, 10.3); rename if your file differs
# Rule 1 — Metropolitan: primary codes 1, 2, or 3 (integer part of the code) → Urban
# Rule 2 — Non-metro with strong commuting ties to a large urban area: secondary digit .1
#          (first decimal place equals 1) → Urban
# All other ZIPs → Rural
code_num <- as.numeric(ruca$RUCA2)
ruca <- ruca %>%
  mutate(
    ruca_urban_rural = ifelse(
      floor(code_num) %in% c(1L, 2L, 3L) |
        round((code_num * 10) %% 10) == 1L,
      "Urban",
      "Rural"
    )
  )

# Attach RUCA fields (codes + Urban/Rural) by ZIP code
d <- ruca[d, on = 'zip']

# Save with RUCA appended for downstream exposure or analysis steps
d |> write_fst(paste0(temp_folder, '/', 'temp_geocoded_deprivation_britt_ruca.fst'), compress = "100")
