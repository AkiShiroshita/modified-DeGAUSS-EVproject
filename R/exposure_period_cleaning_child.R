#### Algorithms ##############################################################################################################
# 1. Define the exposure period for each child: 
# creates an exposure_start_date (the child's date of birth) and an exposure_end_date (the child's date of birth + 1 year)
# 
# 2. Filtering for the First Year of Life
# keep only the address records from d that overlap with the exposure period

# 3. Trimming the Timeline Edges
# adjusts the boundaries of the address history for each child.

# The start date of the very first address record is trimmed 
# so it doesn't begin before the child's actual date of birth.

# The end date of the very last address record is trimmed 
# so it doesn't extend beyond the last day of their first year.

# 4. Resolving Gaps and Overlaps
# there might still be gaps or overlaps between consecutive records

# If a gap is found between the end of one record and the start of the next,
# it sets the end_date of the first record to be the day immediately before the start of the next one. 

# If an overlap is found,
# it sets the end_date of the first record to be the day immediately before the start of the next one.

# Child cohort -------------------------------------------------------------

# each child has multiple rows for addresses

#d <- fread(paste0(input_folder, '/', input_file))

#setnames(d, "ADDRESS", "address")

## Start from here ----------------------------------------------------------

# Convert to data.table
#setDT(d)

# Convert 'BEG' and 'END' to Date objects.
d[, `:=`(
  BEG = as.Date(parse_date_time(BEG, orders = c("y/m/d", "ymd", "mdy"))),
  END = as.Date(parse_date_time(END, orders = c("y/m/d", "ymd", "mdy"))),
  TN_DOB = as.Date(parse_date_time(TN_DOB, orders = c("y/m/d", "ymd", "mdy")))
)]

# Adjust BEG and END to month boundaries
d[, `:=`(
  BEG = floor_date(BEG, "month"),          # First day of the month
  END = ceiling_date(END, "month") - 1     # Last day of the month
)]

# Create start_date and end_date from TN_DOB in linkage_data
# start_date = TN_DOB
# end_date = TN_DOB + 1 year
d[, `:=`(
  exposure_start_date = TN_DOB,
  exposure_end_date = TN_DOB %m+% years(1) - days(1)
)]

# It finds rows in `d` overlapping
# between the `exposure_start_date` and `exposure_end_date`.
d <- d[exposure_start_date <= END & exposure_end_date >= BEG]

# Trimming of BEG and END
d[, `:=`(
  BEG = fifelse(BEG <= exposure_start_date, exposure_start_date, BEG),
  END = fifelse(exposure_end_date <= END, exposure_end_date, END)
), by = recip]

# Sort by the period start and end dates to prepare for merging
setorder(d, recip, BEG, -END) # by END in descending order and remove duplicate addresses with the same BEG, assuming that the entry with the latest END date as the most appropriate one.
d <- d[!duplicated(d, by = c('recip', 'BEG'))] # if multiple addresses were registered for the same person in the same period or the entire exposure period, pick up the first observation.
d[, `:=`(
  row_number = seq_len(.N),
  n_row = .N
), by = recip]

# sort by END in ascending order
setorder(d, recip, BEG, END)

# Algorithms to merge consecutive data
d[, `:=`(
  start_date = BEG
)]

d[, `:=`(
  # Rule for GAPS 
  end_date = fifelse(
    # This condition is FALSE for the last row because shift() is NA
    !is.na(data.table::shift(BEG, type = "lead")) & (END <= data.table::shift(BEG, type = "lead")),
    data.table::shift(BEG, type = "lead") - 1, # Action 
    END                  
  )
), by = recip]

d[, `:=`(
  # Rule for OVERLAPS 
  end_date = fifelse(
    # This condition is FALSE for the last row because shift() is NA
    !is.na(data.table::shift(BEG, type = "lead")) & (data.table::shift(BEG, type = "lead") <= END),
    data.table::shift(BEG, type = "lead") - 1, # Action 
    end_date                     
  )
), by = recip]

# For the first row in each recip group, just take the given exposure_start_date as BEG
# For the last row in each recip group, use the given exposure_end_date as END.
d[, `:=`(
  start_date = fifelse(row_number == 1, exposure_start_date, start_date),
  end_date = fifelse(row_number == n_row, exposure_end_date, end_date)
), by = recip] 

##### sanity check #############
#d %>% filter(end_date < start_date)
#
#random_draw <- sample(d$recip %>% unique(), size = 100)
#random_draw <- d$recip %>% unique()
#
#d_fig <- d %>% 
#  filter(recip %in% random_draw) %>% 
#  mutate(start_date_fig = start_date - exposure_start_date,
#         end_date_fig = end_date - exposure_start_date) 
#
#ggplot(d_fig, aes(x = recip)) +
#  geom_segment(aes(x = recip, xend = recip, y = start_date_fig, yend = end_date_fig), color = "blue", size = 1.5) +
#  geom_point(aes(y = start_date_fig), color = "green", size = 3) +  # Start points
#  geom_point(aes(y = end_date_fig), color = "red", size = 3) +     # End points
#  coord_flip() +
#  labs(x = "ID", y = "Start and end dates") +
#  theme_minimal()
#
#d_fig %>% 
#  filter(recip %in% random_draw) %>% 
#  mutate(diff = end_date - start_date + 1) %>% 
#  group_by(recip) %>% 
#  summarise(days = sum(diff)) %>% 
#  filter(days != 365 &  days != 366) # the output should be 365 or 366.
################################

cols_to_remove <- c("BEG", "END", "exposure_start_date", "exposure_end_date", "row_number", "n_row")

d[, (cols_to_remove) := NULL]

# Save file ---------------------------------------------------------------

#d %>% fst::write_fst(paste0(temp_folder, '/', 'temp_cleaned.fst'), compress = 100)
#d %>% write_csv(paste0(temp_folder, '/', 'temp_cleaned.csv'))
