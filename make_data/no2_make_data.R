
# Set-up ------------------------------------------------------------------

pacman::p_load(
  "remotes",
  "devtools",
  "knitr",
  "tidyverse",
  "tidylog",
  "data.table",
  "readxl",
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
  "exactextractr",
  "fst"
)

dir.create("no2_unzipped") # input folder
dir.create("no2_schwartz_monthly") # output folder

# unzip the files
zip_dir <- "no2_raw_data"
out_dir <- "no2_unzipped"

zip_files <- list.files(zip_dir, pattern = "\\.zip$", full.names = TRUE)
lapply(zip_files, unzip, exdir = out_dir)

# Prepare monthly NO2 data ------------------------------------------------

# Note: First, unzip 4 folders from Harvard
# Each folder contains daily NO2 estimates for multiple 1km² grid cells
# Data covers approximately 12 months × 17 years = 204 files (minus 1 base file)
# Create the "no2_schwartz" folder and put all files there
# Create the "no2_schwartz_monthly" folder to put output files.

# Extract all daily NO2 file names
folder_path <- 'no2_unzipped/no2'
file_names <- list.files(path = folder_path, pattern = '\\.csv.gz$', full.names = TRUE)
file_names <- file_names[-205] # Remove the base file "no2_schwartz/grid.csv.gz"

# Create monthly aggregated NO2 files
# Monthly aggregation reduces file size and speeds up processing
after_files <- file_names |>
  gsub("no2_unzipped/no2", "no2_schwartz_monthly", x = _) |>
  gsub("\\.csv\\.gz$", ".fst", x = _)

# Process each daily file: calculate monthly mean NO2 per grid cell
purrr::walk2(file_names, after_files, function(infile, outfile) {
  
  date_ym <- read_csv(infile, col_types = cols()) |>
    colnames() |>
    ymd() |>
    last() |>
    format("%Y%m") |>
    as.integer()
  
  read_csv(infile, col_types = cols()) |>
    pivot_longer(
      cols = -idx,
      names_to = "date",
      values_to = "value"
    ) |>
    group_by(idx) |>
    summarise(
      value = mean(value, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(date = date_ym) |>
    write_fst(outfile)
})

# Figure ------------------------------------------------------------------

folder_path <- 'no2_schwartz_monthly/'
file_names <- list.files(path = folder_path, pattern = '\\.fst$', full.names = TRUE)
file_names <- file_names[grepl("2016", file_names)]

.d <- map(file_names, read_fst) %>% 
  bind_rows()

monthly_average <- .d |> 
  group_by(idx) |> 
  dplyr::summarise(monthly_average = mean(value, na.rm = TRUE))

grid <- vect("no2_unzipped/no2/grid.gpkg")
fig <- merge(grid, monthly_average, by = "idx", all.x = TRUE)

#plot(fig, "monthly_average")
plet(fig, "monthly_average", col = viridis::inferno(100))

