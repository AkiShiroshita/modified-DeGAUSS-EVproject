# ============================================================================
# Initial Set-up Script
# ============================================================================
# This script sets up the R environment, loads required packages, and
# initializes Podman containers for address parsing and geocoding.
# Run this script at the beginning of each R session.
# ============================================================================

# Activate renv (if using renv for package management)
#source("renv/activate.R")

# Load custom functions for the pipeline
source('R/custom_functions.R')

# Packages ----------------------------------------------------------------
# Load all required packages using pacman
# pacman::p_load automatically installs missing packages

pacman::p_load(
  "renv",
  "remotes",
  "devtools",
  "knitr",
  "tidyverse",
  "tidylog",
  "data.table",
  "readxl",
  "tidylog",
  "lubridate",
  "writexl",
  "here",
  "mappp",
  "furrr",
  "future",
  "sf",
  "terra",
  "glue",
  "raster",
  "fst",
  "qs",
  "tictoc")

# Create folders ----------------------------------------------------------

folders <- c(input_folder, output_folder, temp_folder)

for (f in folders) {
  if (!dir.exists(f)) {
    dir.create(f, recursive = TRUE)
    message("Created folder: ", f)
  } else {
    message("Folder already exists: ", f)
  }
}

# Log ---------------------------------------------------------------------
# Set up timing logs using tictoc package
# Logs track processing time for each pipeline step

# Clear previous logs (if any)
tic.clearlog()

# Podman ------------------------------------------------------------------
# Start Podman machine (required for running containers)
# Podman is a container runtime similar to Docker
# The machine must be running before containers can be started

system2("podman", c("machine", "start"), stderr = FALSE, stdout = FALSE)
#system2("podman", c("machine", "stop"))  # Uncomment to stop Podman machine

# Find and validate Podman command
# This function is also defined in custom_functions.R but included here for standalone use
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

# Run Podman command with error handling
# Wraps system2 calls to Podman with try-catch for better error messages
run_podman_cmd <- function(args) {
  podman_cmd <- find_podman_cmd()
  result <- tryCatch(
    {
      suppressWarnings(system2(podman_cmd, args = args, stderr = TRUE, stdout = TRUE))
    },
    error = function(e) {
      checkErrorMessage(conditionMessage(e))
    }
  )
  return(result)
}

# Check and format error messages from Podman
# Provides user-friendly messages for common errors (e.g., container already exists)
checkErrorMessage <- function(errorMessage) {
  # Check if the error message contains specific substrings
  if (grepl("the container name \"gs\" is already in use", errorMessage) ||
      grepl("the container name \"gs2\" is already in use", errorMessage)) {
    return("You already have the necessary environment! Please go to the next step.")
  } else {
    return(paste("Error: ", errorMessage))
  }
}

# Create/start postal container (gs) for address parsing
# Container name: gs
# Image: ghcr.io/degauss-org/postal:0.1.4 (libpostal address parser)
# This container is used for parsing and normalizing addresses
result1 <- run_podman_cmd(c('run', '-it', '-d', '--name gs',
                            '--entrypoint /bin/bash',
                            'ghcr.io/degauss-org/postal:0.1.4'))

# Create/start geocoder container (gs2) for address geocoding
# Container name: gs2
# Image: degauss/geocoder:3.0 (Ruby-based geocoder)
# This container converts addresses to lat/lon coordinates
result2 <- run_podman_cmd(c('run', '-it', '-d', '--name gs2',
                            '--entrypoint /bin/bash',
                            'degauss/geocoder:3.0'))

# Check for errors (containers may already exist, which is fine)
checkErrorMessage(result1[2])
checkErrorMessage(result2[2])
