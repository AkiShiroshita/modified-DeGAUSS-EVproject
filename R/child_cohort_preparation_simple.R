# ============================================================================
# Child Cohort Data Preparation
# ============================================================================
# This script prepares address data for the child cohort by:
# 1. Defining exposure period: birth date to birth date + 4 year (childhood)
# 2. Filtering address records to only those overlapping with exposure period
# 3. Adjusting address dates to month boundaries
# ============================================================================

#### Algorithms ##############################################################################################################
# 1. Define the exposure period for each child: 
# creates an exposure_start_date (the child's date of birth) and an exposure_end_date (the child's date of birth + 4 year)
# 
# 2. Filtering for the First Four Years of Life
# keep only the address records from d that overlap with the exposure period

# Child cohort -------------------------------------------------------------

# Each child has multiple rows for addresses (address history)

# Load input address data
d <- fread(paste0(input_folder, '/', input_file))

## Start from here ----------------------------------------------------------

# Convert to data.table (if not already)
#setDT(d)

# Convert date columns to Date objects
# Handles multiple date formats (y/m/d, ymd, mdy)
d[, `:=`(
  BEG = as.Date(parse_date_time(BEG, orders = c("y/m/d", "ymd", "mdy"))),
  END = as.Date(parse_date_time(END, orders = c("y/m/d", "ymd", "mdy"))),
  TN_DOB = as.Date(parse_date_time(TN_DOB, orders = c("y/m/d", "ymd", "mdy")))
)]

# Adjust BEG and END to month boundaries
# This standardizes address periods to full months for consistency
d[, `:=`(
  BEG = floor_date(BEG, "month"),          # First day of the month
  END = ceiling_date(END, "month") - 1     # Last day of the month
)]

# Create exposure period for each child
# 4-year exposure period (commented out)
d[, `:=`(
  exposure_start_date = TN_DOB,
  exposure_end_date = TN_DOB %m+% years(4) - days(1)
)]

# Filter address records to only those overlapping with exposure period
# Keep addresses where the address period overlaps with the child's first year
# Overlap condition: exposure_start_date <= END AND exposure_end_date >= BEG
d <- d[exposure_start_date <= END & exposure_end_date >= BEG]

setorder(d, recip, BEG, END) 

# Removing children who moved out of TN
# Study is limited to Tennessee residents
d_tn_out <- d[flag_for_TN == 0 | is.na(flag_for_TN)] 
ids_tn_out <- distinct(d_tn_out, recip) %>% pull(recip)
cat("Number of children who moved out of TN: ", length(ids_tn_out))
d <- d[!recip %in% ids_tn_out]

# Save file ---------------------------------------------------------------

# Save cleaned data in fast binary format (fst) and CSV format
d %>% fst::write_fst(paste0(temp_folder, '/', 'temp_cleaned.fst'), compress = 100)
d %>% write_csv(paste0(temp_folder, '/', 'temp_cleaned.csv'))
