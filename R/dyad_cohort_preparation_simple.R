# ============================================================================
# Dyad Cohort Data Preparation
# ============================================================================
# This script prepares address data for the dyad (mother-child) cohort by:
# 1. Defining exposure period: LMP (last menstrual period) to child's birth date (pregnancy period)
# 2. Filtering address records to only those overlapping with exposure period
# 3. Adjusting address dates to month boundaries
# ============================================================================

#### Algorithms ##############################################################################################################
# 1. Define the exposure period for each mother: 
# creates an exposure_start_date (LMP) and an exposure_end_date (the child's date of birth)
# 
# 2. Filtering for the First Year of Life
# keep only the address records from d that overlap with the exposure period

# Dyad cohort -------------------------------------------------------------

# Each mother has multiple rows for addresses (address history during pregnancy)

# Load input address data
d <- fread(paste0(input_folder, '/', input_file))

# Standardize column names
setnames(d, "ADDRESS", "address")
setnames(d, "inf_dob", "TN_DOB")  # Rename infant DOB to TN_DOB for consistency

## Start from here ----------------------------------------------------------

# Convert to data.table (if not already)
#setDT(d)

# Convert date columns to Date objects
# Handles multiple date formats (y/m/d, ymd, mdy)
d[, `:=`(
  BEG = as.Date(parse_date_time(BEG, orders = c("y/m/d", "ymd", "mdy"))),
  END = as.Date(parse_date_time(END, orders = c("y/m/d", "ymd", "mdy"))),
  LMP = as.Date(parse_date_time(LMP, orders = c("y/m/d", "ymd", "mdy"))),
  TN_DOB = as.Date(parse_date_time(TN_DOB, orders = c("y/m/d", "ymd", "mdy")))
)]

# Adjust BEG and END to month boundaries
# This standardizes address periods to full months for consistency
d[, `:=`(
  BEG = floor_date(BEG, "month"),          # First day of the month
  END = ceiling_date(END, "month") - 1     # Last day of the month
)]

# Create exposure period for each mother
# Exposure period = pregnancy period (LMP to child's birth)
# start_date = LMP (last menstrual period, start of pregnancy)
# end_date = TN_DOB (child's date of birth, end of pregnancy)
d[, `:=`(
  exposure_start_date = LMP,
  exposure_end_date = TN_DOB
)]

# Filter address records to only those overlapping with exposure period
# Keep addresses where the address period overlaps with the pregnancy period
# Overlap condition: exposure_start_date <= END AND exposure_end_date >= BEG
d <- d[exposure_start_date <= END & exposure_end_date >= BEG]

# Save file ---------------------------------------------------------------

# Save cleaned data in fast binary format (fst) and CSV format
d %>% fst::write_fst(paste0(temp_folder, '/', 'temp_cleaned.fst'), compress = 100)
d %>% write_csv(paste0(temp_folder, '/', 'temp_cleaned.csv'))
