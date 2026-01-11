# ============================================================================
# Traffic Density (AADT) Assessment
# ============================================================================
# This script calculates traffic density metrics using Annual Average Daily
# Traffic (AADT) data within 400m buffers around each address.
# AADT measures the average number of vehicles per day on a road segment.
# Metrics include road length, vehicle-meters, and truck-meters by traffic type
# (moving traffic: interstates/freeways vs stop-go traffic: arterials).
# ============================================================================

# Traffic density ---------------------------------------------------------

# Load geocoded data with census, road proximity, greenspace, and deprivation data
d <- read_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace_dep.rds')) 

# Add buffer index to track each address location
d$buffer_index <- 1:nrow(d) 

# Load AADT (Annual Average Daily Traffic) data for Tennessee (2017)
traffic_volume <- read_rds('data/Tennessee2017AADT.rds') |>
  st_zm() # Drop M dimension (remove measure dimension if present)
traffic_volume$geometry <- st_cast(traffic_volume$geometry, "MULTILINESTRING") # for AADT 2014
setDT(traffic_volume)

# Filter to major road types only
# These road types have reliable AADT data and significant traffic volumes
road_types_to_keep <- c('Interstate', 'Principal Arterial - Other Freeways and Expressways',
                        'Principal Arterial - Other', 'Minor Arterial')

# Filter traffic volume data to selected road types
# Remove state and county FIPS codes (not needed)
traffic_volume <- st_as_sf(traffic_volume[road_type %in% road_types_to_keep, 
                                          -c("state_fips", "county_fips")])

# Create a 500m radius buffer around each address
# This buffer captures nearby traffic exposure
d_buffer <- sf::st_buffer(d, dist = 500) 

# Extract traffic density data within each buffer
# Intersection finds all road segments that fall within each buffer
d_aadt <- sf::st_intersection(d_buffer, traffic_volume)

setDT(d_aadt)

# Calculate traffic density metrics
# length: total length of roads (in meters) within buffer
# aadt_length: vehicle-meters (AADT × length) - weighted traffic exposure
# aadt_truck: sum of single-unit and combination truck AADT
# aadt_truck_length: truck-meters (truck AADT × length) - weighted truck exposure
d_summary <- d_aadt[, `:=`(
  length = as.numeric(st_length(geometry)),  # Length of road segment in meters
  aadt = as.numeric(aadt)  # Annual Average Daily Traffic
)][, `:=`(
  aadt_length = aadt * length,  # Vehicle-meters: traffic volume weighted by road length
  aadt_truck = as.numeric(aadt_single_unit) + as.numeric(aadt_combination)  # Total truck AADT
)][,
   aadt_truck_length := aadt_truck * length  # Truck-meters: truck volume weighted by road length
][, # Summarize by buffer and road type
  .(
    length = round(sum(length, na.rm = TRUE)),  # Total road length in buffer
    vehicle_meters = round(sum(aadt_length, na.rm = TRUE)),  # Total vehicle-meters
    truck_meters = round(sum(aadt_truck_length, na.rm = TRUE))  # Total truck-meters
  ),
  by = .(buffer_index, road_type)  # Group by address buffer and road type
]

# Classify traffic types
# "moving": highways/freeways with continuous traffic flow
# "stop_go": arterials with traffic lights and stop signs
d_summary[, traffic_type := fcase(
  road_type %in% c('Interstate', 'Principal Arterial - Other Freeways and Expressways'), "moving",
  road_type %in% c('Principal Arterial - Other', 'Minor Arterial'), "stop_go"
)]

# Reshape to wide format: one row per address, separate columns for moving vs stop-go traffic
d_summary_wide <- dcast(d_summary[!is.na(traffic_type)], 
                        buffer_index ~ traffic_type, 
                        fun.aggregate = sum,
                        value.var = c("length", "vehicle_meters", "truck_meters"))

# Final join: merge traffic density metrics back to address data
d <- as.data.table(d)
d <- d_summary_wide[d, on = "buffer_index"]
d[, buffer_index := NULL]  # Remove temporary index

# Convert back to spatial object
d <- d |> st_as_sf()

# Save data with traffic density measures
d |> write_rds(paste0(temp_folder, '/', 'temp_geocoded_census_road_greenspace_dep_aadt.rds'), compress = 'gz')

#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache
