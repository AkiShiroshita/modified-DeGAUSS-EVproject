# =============================================================================
# Script: cdc_urban_rural_classification.R
# Date:   2026-06-01
# Purpose: Download and prepare NCHS Urban-Rural county classification codes
#          for Tennessee counties, retaining classification schemes from
#          multiple reference years.
#
# Main Steps:
#   1. Load packages
#   2. Read raw NCHS Urban-Rural classification data
#   3. Filter to Tennessee and select relevant columns
#   4. Export cleaned data as RDS
# =============================================================================

# Source: CDC/NCHS Urban-Rural Classification Scheme for Counties
# https://www.cdc.gov/nchs/data-analysis-tools/urban-rural.html

# Load packages ----

library(readr)
library(tidyverse)

# Read raw NCHS Urban-Rural classification data ----

# The CSV contains all U.S. counties with urban-rural codes assigned under
# four different classification schemes (1990, 2006, 2013, 2023).
NCHSurb_rural_codes <- read_csv("NCHSurb-rural-codes.csv")

# Filter to Tennessee and select relevant columns ----

# Restrict to Tennessee (ST_ABBREV == "TN") and keep only the county FIPS code
# and the four vintage classification codes. The different CODE years reflect
# how county urbanicity categorizations have shifted over time and allow
# analyses to use the scheme that matches their study period.
NCHSurb_rural_codes <- NCHSurb_rural_codes |>
  filter(ST_ABBREV == "TN") |>
  dplyr::select(CTYFIPS, CODE1990, CODE2006, CODE2013, CODE2023)

# Export cleaned data as RDS ----

# Save as RDS for fast, type-safe loading in downstream scripts.
NCHSurb_rural_codes |> write_rds("NCHSurb_rural_codes.rds")
