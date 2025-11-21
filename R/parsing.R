# ============================================================================
# Address Parsing and Normalization
# ============================================================================
# This script parses and normalizes addresses using libpostal in a container.
# Address parsing breaks addresses into components (house number, street, city, etc.)
# and normalizes them to a standard format for better geocoding accuracy.
# ============================================================================

# Preparation -------------------------------------------------------------

# Note: This script requires Podman to be running
# Open Command Prompt and run: podman machine start

# Please run this R script section-by-section.
# You can place the cursor in the section and press: Ctrl + Alt + T

# Prepare input addresses
# Load cleaned address data
d <- fst::read_fst(paste0(temp_folder, '/', 'temp_cleaned.fst'))

#if ("mrecip" %in% names(d)) {
#  names(d)[names(d) == "mrecip"] <- "recip"
#}

# Remove missing addresses
# Addresses must be present for parsing
d <- d |> 
  drop_na(address) 

setDT(d)

# Parse/normalize addresses 
# This section uses libpostal (via Docker/Podman container) for parsing and normalizing addresses.
# libpostal is a C library for parsing and normalizing street addresses worldwide.

# Start the postal container (must be created in initial_set_up.R)
start_postal_container()

# Parse and normalize all addresses
# This breaks addresses into components and reconstructs them in a standard format
d <- parse_and_normalize(d)
setDT(d)

# Save normalized addresses
d |> fst::write_fst(paste0(temp_folder, '/', 'temp_normalized.fst'), compress = 100)

#stop_postal_container()
#rm(list = ls(envir = .GlobalEnv), envir = .GlobalEnv) # Remove all objects from the environment
#gc() # Trigger garbage collection to free up memory
#if (rstudioapi::isAvailable()) rstudioapi::restartSession() # restart R studio to completely remove any cache