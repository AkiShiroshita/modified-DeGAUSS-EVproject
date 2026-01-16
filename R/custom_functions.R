# ============================================================================
# Custom Functions for Modified DeGAUSS Pipeline
# ============================================================================
# This file contains custom utility functions used throughout the pipeline
# for container management, address parsing, geocoding, and exposure assessment.
# ============================================================================

# Podman set-up -----------------------------------------------------------
# Functions for managing Podman containers used for address parsing and geocoding

# Find and validate Podman command
# Returns the path to the podman executable if found and running
# Throws an error if podman is not installed or the daemon is not running
find_podman_cmd <- function() {
  podman_cmd <- Sys.which('podman')
  if (length(podman_cmd) == 0) stop(paste('\n','podman command not found. ','\n',
                                          'Please install podman: ','\n',
                                          'https://podman.io/docs/installation'))
  podman_check <- suppressWarnings(system2(podman_cmd,'ps',stderr=TRUE,stdout=TRUE))
  if(!is.null(attr(podman_check,'status'))) stop(paste0('Cannot connect to the podman daemon. ',
                                                        'Is the podman daemon running on this host?'))
  return(podman_cmd)
}

# Parsing and normalizing -------------------------------------------------
# Functions for parsing and normalizing addresses using libpostal in a container
# Note: postal:0.1.4 was not uploaded to Docker Hub

# Start the postal container for address parsing
# The container must already exist (created in initial_set_up.R)
start_postal_container <- function() {
  message('starting container...')
  #system2(find_podman_cmd(),
  #        args = c('run','-it','-d','--name gs',
  #                 '--entrypoint /bin/bash',
  #                 'ghcr.io/degauss-org/postal:0.1.4'),
  #        stdout = NULL)
  system2(find_podman_cmd(),
          args = c('start','gs'),
          stdout = NULL)
}

# Stop the postal container
# Note: Container removal is commented out to preserve the container for reuse
stop_postal_container <- function() {
  message('stopping container...')
  system2(find_podman_cmd(),
          args = c('stop','gs'),
          stdout = NULL)
  #system2(find_podman_cmd(),
  #        args = c('rm','gs'),
  #        stdout = NULL)
}

# Parse and normalize addresses using libpostal
# Input: data.table with 'address' column
# Output: data.table with parsed and normalized address components
# This function uses the postal container to parse addresses into components
# (house number, road, city, state, postcode) and reconstructs a normalized address
parse_and_normalize <- function(d) {

  # Convert to data.table and rename address column
  setDT(d)
  setnames(d, "address", "old_address")
  
  # Get podman command path
  podman_cmd <- find_podman_cmd()
  
  # Execute address parser in container
  # Sends addresses to libpostal parser via stdin and captures JSON output
  parser_output <-  system2(podman_cmd,
                            args = c(
                              "exec", "-i", "gs",
                              "/code/libpostal/src/address_parser"
                            ),
                            input = d$old_address,
                            stderr = FALSE,
                            stdout = TRUE
  )
  
  # Parse JSON output from libpostal
  # Remove header lines (first 11 lines) and parse JSON results
  parsed_address_components <-
    parser_output[-c(1:11)] |>
    paste(collapse = " ") |>
    strsplit("Result:", fixed = TRUE) |>
    purrr::transpose() |>
    purrr::modify(unlist) |>
    purrr::modify(jsonlite::fromJSON) |>
    purrr::modify(tibble::as_tibble, .name_repair = "unique") |>
    dplyr::bind_rows() |>
    dplyr::select(-contains("...")) |>
    dplyr::rename_with(~ paste("parsed", .x, sep = ".")) |>
    suppressMessages()
  
  # Combine original data with parsed components
  d <- dplyr::bind_cols(d, parsed_address_components)
  
  # Extract 5-digit ZIP code if postcode exists
  if (!is.null(d$parsed.postcode)) {
    d$parsed.postcode_five <- substr(d$parsed.postcode, 1, 5)
  }
  
  # Reconstruct normalized address from parsed components
  # Combines house_number, road, city, state, and 5-digit postcode
  d <- tidyr::unite(d,
                    col = "parsed_address",
                    tidyselect::any_of(paste0("parsed.", c("house_number", "road", "city", "state", "postcode_five"))),
                    sep = " ", na.rm = TRUE, remove = TRUE) |> 
    dplyr::select(recip, TN_DOB, start_date, end_date, address = parsed_address)
  
  return(d)
}

# Geocoding ---------------------------------------------------------------
# Functions for geocoding addresses (converting addresses to lat/lon coordinates)
# Uses DeGAUSS geocoder container running Ruby geocoder

# Detect PO Box addresses
# PO Boxes cannot be geocoded to physical locations, so they need to be flagged
address_is_po_box2 <- function(address) {
  cli::cli_alert_info("Flagging PO boxes...", wrap = TRUE)
  
  # Define the regular expression for detecting PO Boxes.
  # This regex matches variations such as "PO BOX", "P.O. BOX", "POST OFFICE BOX", etc.
  # Cannot detect "PO Nashville"
  # The regex ignores case sensitivity (handled later by `ignore_case = TRUE`).
  po_regex_string <- "\\bP(OST)*\\.*\\s*[O|0](FFICE)*\\.*\\s*B[O|0]X"
  
  po_box <- purrr::map(address, ~ stringr::str_detect(.x, stringr::regex(po_regex_string, ignore_case = TRUE)))
  
  # Handle missing or empty addresses.
  # Identify addresses that are either NA (missing values) or empty strings ("").
  # These addresses are considered not to be PO Boxes, so they are set to FALSE.
  missing_address <- which(is.na(address) | address == "") # Find indices of missing/empty values.
  po_box[missing_address] <- FALSE # Set the corresponding results to FALSE.
  
  return(purrr::map_lgl(po_box, any))
}

# Internal function to call geocoder for a single address
# Returns geocoding results as a list/tibble with lat, lon, score, precision, etc.
gc_call2 <- function(address) {
  podman_cmd <- find_podman_cmd()
  
  # Execute geocoder Ruby script in container
  podman_out <- system2(podman_cmd,
                        args = c(
                          "exec", "gs2",
                          "ruby", "/root/geocoder/geocode.rb",
                          shQuote(address)
                        ),
                        stderr = FALSE,
                        stdout = TRUE
  )
  
  # Parse JSON output from geocoder
  out <- jsonlite::fromJSON(podman_out)
  
  # Remove FIPS county code (not needed)
  out$fips_county <- NULL
  
  # Return empty template if geocoding failed
  if (length(out) == 0) {
    out <- tibble(
      street = NA, zip = NA, city = NA, state = NA,
      lat = NA, lon = NA, score = NA, precision = NA
    )
  }
  
  return(out)
}

# Start the geocoder container
# The container must already exist (created in initial_set_up.R)
# Makes a test geocoding call to load the address range database into memory
start_geocoder_container2 <- function() {
  message('starting geocoding container...')
  #system2(find_podman_cmd(),
  #        args = c('run','-it','-d','--name gs2',
  #                 '--entrypoint /bin/bash',
  #                 'degauss/geocoder:3.0'),
  #        stdout = NULL)
  system2(find_podman_cmd(),
          args = c('start','gs2'),
          stdout = NULL)
  message('and loading address range database...')
  # Warm-up call to load database (test address in Cincinnati)
  invisible(gc_call2('3333 Burnet Ave Cincinnati OH 45229'))
}

# Template for geocoding output when geocoding fails
# Ensures consistent column structure even when no results are returned
out_template <- dplyr::tibble(
  street = NA, zip = NA, city = NA, state = NA,
  lat = NA, lon = NA, score = NA, precision = NA,
  fips_county = NA, number = NA, prenum = NA
)

# Main geocoding function
# Converts a single address string to geographic coordinates
# Returns a data.table with geocoding results (lat, lon, score, precision, etc.)
# Validate input is character
geocode2 <- function(addr_string) {
  stopifnot(class(addr_string) == "character")
  
  # Call geocoder container
  out <- system2(find_podman_cmd(),
                 args = c(
                   "exec", "gs2",
                   "ruby", "/root/geocoder/geocode.rb",
                   shQuote(addr_string)
                 ),
                 stderr = FALSE,
                 stdout = TRUE
  )
  
  # Parse JSON output and ensure consistent structure
  if (length(out) > 0) {
    out <- jsonlite::fromJSON(out)
    # Merge with template to ensure all columns exist
    out <- rbindlist(list(out_template, out), fill = TRUE)[2, ]
  } else {
    out <- out_template
  }
  
  # Convert all columns to character for consistency
  out[, names(out) := lapply(.SD, as.character)]
  out
}

# Stop the geocoder container
# Note: Container removal is commented out to preserve the container for reuse
stop_geocoder_container2 <- function() {
  message('stopping container...')
  system2(find_podman_cmd(),
          args = c('stop','gs2'),
          stdout = NULL)
  #system2(find_podman_cmd(),
  #        args = c('rm','gs'),
  #        stdout = NULL)
}

# For Docker
#library(OfflineGeocodeR)
#geocode <- function(addr_string) {
#  docker_cmd <- find_docker_cmd()
#  
#  docker_out <- system2(docker_cmd,
#                        args = c(
#                          "exec", "gs",
#                          "ruby", "/root/geocoder/geocode.rb",
#                          shQuote(addr_string)
#                        ),
#                        stderr = FALSE,
#                        stdout = TRUE
#  )
#  
#  out <- jsonlite::fromJSON(docker_out)
#  
#  return(out)
#}
#start_geocoder_container()
#on.exit(stop_geocoder_container())
#d[, geocodes := future.apply::future_lapply(address, geocode)]


# Greenspace --------------------------------------------------------------
# Functions for calculating greenspace exposure using Enhanced Vegetation Index (EVI)

# Calculate mean EVI within a buffer around each point
# EVI is a measure of vegetation greenness (higher = more vegetation)
# Input: radius in meters for buffer
# Output: mean EVI value within buffer (scaled by 0.0001)
get_evi_buffer <- function(radius) {
  # Create circular buffer around each point
  d_buffer <- sf::st_buffer(d, dist = radius, nQuadSegs = 100)
  # Convert to terra SpatVector for raster extraction
  d_vect <- terra::vect(d_buffer)
  
  # Extract mean EVI value from raster within each buffer
  evi <- terra::extract(evi_2018,
                        d_vect,
                        fun = mean,
                        na.rm = TRUE) 
  
  # Scale and round EVI value (EVI raster values are stored as integers * 10000)
  return(round(evi$evi_June_2018_5072 * 0.0001, 4))
}

# Road density ------------------------------------------------------------
# Functions for calculating road density (length of roads per unit area)

# Calculate total length of roads intersecting each buffer
# Input: roads - sf object with road linestrings
# Output: vector of road lengths (in meters) for each buffer
# Note: buffers object must exist in the environment
get_line_length <- function(roads) {
  # Find indices of roads that intersect each buffer
  # If no roads intersect, length will be 0
  b <- buffers %>%
    mutate(buffer_index = 1:nrow(.),
           road_index = st_intersects(buffers, roads, sparse = TRUE),
           l = map_dbl(road_index, length),
           road_length = ifelse(l > 0, 1, 0))
  
  # Split buffers into two groups: those with intersections and those without
  b_split <- split(b, b$road_length)
  
  # For buffers with intersections, calculate actual road length
  if(!is.null(b_split$`1`)) {
    # Extract intersecting road segments for each buffer
    roads_intersects <- purrr::map(b_split$`1`$road_index, ~roads[.x,])
    # Calculate intersection geometry between buffer and roads
    roads_intersection <- purrr::map2(1:nrow(b_split$`1`),
                                      roads_intersects,
                                      ~st_intersection(b_split$`1`[.x,], .y))
    # Union multiple road segments into single geometry per buffer
    roads_intersection <- purrr::map(roads_intersection, st_union)
    # Calculate total length of intersected roads in meters
    b_split$`1`$road_length <- round(purrr::map_dbl(roads_intersection, st_length))
  }
  
  # Recombine buffers and return road lengths in original order
  b <- bind_rows(b_split) %>%
    arrange(buffer_index)
  
  return(b$road_length)
}

# NO2 grid lookup ---------------------------------------------------------
# Functions for finding the nearest NO2 grid cell to a query point

# Find the index of the nearest NO2 grid cell to a query point
# Input: query_point - sf point geometry
# Output: grid cell index (idx) for NO2 data lookup
# Note: d_grid must exist in the environment (NO2 grid cells)
get_closest_grid_site_index <- function(query_point) {
  
  # Calculate distances from query point to all grid cells
  distances <- sf::st_distance(query_point, d_grid, by_element = FALSE)
  
  # Find the index of the closest grid cell
  which_nearest <- which.min(distances)
  
  # Return the grid cell index for NO2 data lookup
  d_grid |>
    slice(which_nearest) |>
    sf::st_drop_geometry() |>
    dplyr::select(idx)
}

# NO2 estimates -----------------------------------------------------------
# Functions for retrieving NO2 exposure estimates from pre-computed grids

# Read NO2 data file and merge with lookup table
# This helper function reads monthly/daily NO2 data files and merges with
# the date/grid index lookup table
# Input: .split - data.table with file_name, idx, and date columns
# Output: data.table with NO2 values merged
read_and_merge <- function(.split){
  # Get filename from first row (all rows in split have same filename)
  .file_name <- .split |> slice(1) |> pull(file_name) 
  # Read NO2 data file (fst format for fast reading)
  .s <- fst::read_fst(.file_name, as.data.table = TRUE) |> 
    setkey('idx', 'date')
  
  # Merge NO2 values with lookup table by grid index and date
  .split <- data.table::merge.data.table(.split,
                                         .s,
                                         all.x = TRUE,
                                         all.y = FALSE,
                                         by.x = c('idx', 'date'),
                                         by.y = c('idx', 'date'),
                                         allow.cartesian = TRUE)
  return(.split)
}

# Get daily NO2 estimates for a date range and grid cell
# Input: start_date, end_date (Date objects), idx (grid cell index)
# Output: data.table with daily NO2 values for the specified period
get_no2 <- function(start_date, end_date, idx){
  
  # Create lookup table with all dates in range and grid index
  # Each row represents one day at one grid cell
  .look_up <- tidyr::expand_grid(date = seq.Date(as.Date(start_date), as.Date(end_date), by = "day"),
                                 idx = idx) |> 
    mutate(year = as.character(year(date)), 
           month = as.character(sprintf("%02d", as.numeric(month(date)))),
           file_name = paste0("data/no2_schwartz_daily/", year, "-", month, ".fst")) |>  # Add leading zero if needed
    data.table::as.data.table(key = c('idx', 'date'))
  
  # Split by filename to read each monthly file once
  .look_up_split <- split(.look_up, .look_up$file_name)
  
  # Read and merge NO2 data in parallel for each monthly file
  .no2_average <- furrr::future_map(.look_up_split,
                                    ~read_and_merge(.x),
                                    .progress = TRUE,
                                    .options = furrr_options(seed = TRUE)) |> 
    dplyr::bind_rows() 
}

# Get monthly NO2 estimates for a date range and grid cell
# Similar to get_no2 but uses monthly aggregated data (faster for long periods)
# Input: start_date, end_date (Date objects), idx (grid cell index)
# Output: data.table with monthly NO2 values for the specified period
get_no2_monthly <- function(start_date, end_date, idx){
  
  # Create lookup table with all months in range and grid index
  # Each row represents one month at one grid cell
  .look_up <- tidyr::expand_grid(date = seq.Date(as.Date(start_date), as.Date(end_date), by = "month"),
                                 idx = idx) |> 
    mutate(year = as.character(year(date)), 
           month = as.character(sprintf("%02d", as.numeric(month(date)))),
           date = as.integer(paste0(year, month)),  # Convert to YYYYMM integer format
           file_name = paste0("data/no2_schwartz_monthly/", year, "-", month, ".fst")) |>  # Add leading zero if needed
    data.table::as.data.table(key = c('idx', 'date'))
  
  # Split by filename to read each monthly file once
  .look_up_split <- split(.look_up, .look_up$file_name)
  
  # Read and merge NO2 data in parallel for each monthly file
  .no2_average <- furrr::future_map(.look_up_split,
                                    ~read_and_merge(.x),
                                    .progress = TRUE,
                                    .options = furrr_options(seed = TRUE)) |> 
    dplyr::bind_rows() 
}

# BC (Black Carbon) ----------------------------------------------------------------------
# Functions for retrieving black carbon exposure estimates from pre-computed grids

# Get monthly BC estimates for a date range and grid cell
# Black carbon is a component of fine particulate matter from combustion sources
# Input: start_date, end_date (Date objects), idx (grid cell index)
# Output: data.table with monthly BC values for the specified period
get_bc <- function(start_date, end_date, idx){
  
  # Create lookup table with all months in range and grid index
  # Each row represents one month at one grid cell
  .look_up <- tidyr::expand_grid(date = seq.Date(as.Date(start_date), as.Date(end_date), by = "month"),
                                 idx = idx) %>% 
    mutate(year = as.character(year(date)), 
           month = as.character(sprintf("%02d", as.numeric(month(date)))),
           date = as.integer(paste0(year, month)),  # Convert to YYYYMM integer format
           #date = format(date, "%Y-%m"),
           file_name = paste0("data/bc_monthly/", year, month, ".fst")) |>  # Add leading zero if needed
    as.data.table(key = c('idx', 'date'))
  
  # Split by filename to read each monthly file once
  .look_up_split <- split(.look_up, .look_up$file_name)
  
  # Read and merge BC data in parallel for each monthly file
  .bc_average <- future_map(.look_up_split,
                            ~read_and_merge(.x),
                            .progress = TRUE,
                            .options = furrr_options(seed = TRUE)) |> 
    bind_rows() 
}
