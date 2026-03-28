
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
  "ncdf4",
  "rasterVis",
  "fst",
  "tigris"
)

setwd("Y:/Aki_env_data_test/modified_DeGAUSS_make_data")

# Create a grid file ------------------------------------------------------

# https://sites.wustl.edu/acag/surface-pm2-5/#V5.NA.05.02

# Year 2020 Census Block Groups
# Get state information for downloading census data
tennessee <- tigris::states(year = 2020) %>%
  filter(STATEFP == 47)
tennessee <- vect(tennessee)
tennessee_aea <- project(tennessee, "epsg:5070")
tennessee_target <- buffer(tennessee_aea, 5000) # 5km buffer

# Create a grid file
ncpath <- "/"  
files <- list.files(pattern = '\\.nc$', full.names = TRUE)

nc2raster <- rast(files[2])
coords <- crds(nc2raster, df = TRUE)
coords$idx <- 1:nrow(coords)

grid <- vect(
  coords[, c("idx", "x", "y")],
  geom = c("x", "y"),
  crs = crs(nc2raster)
)

tennessee_target_nc <- project(tennessee_target, crs(nc2raster))
grid <- grid[tennessee_target_nc]

# get grid cell IDs
grid_ids <- cellFromXY(nc2raster, crds(grid))

# crs transform
grid <- project(grid, "epsg:4326")

writeVector(grid, "bc_monthly_biomass/grid.gpkg", overwrite=TRUE)

# Create monthly BC files -------------------------------------------------

grid <- vect("bc_monthly_biomass/grid.gpkg")

filenames <- expand.grid(year = 2000:2017, month = sprintf("%02d", 1:12)) %>%
  mutate(
    month_abbr = case_when(
      month == "01" ~ "JAN",
      month == "02" ~ "FEB",
      month == "03" ~ "MAR",
      month == "04" ~ "APR",
      month == "05" ~ "MAY",
      month == "06" ~ "JUN",
      month == "07" ~ "JUL",
      month == "08" ~ "AUG",
      month == "09" ~ "SEP",
      month == "10" ~ "OCT",
      month == "11" ~ "NOV",
      month == "12" ~ "DEC"
    ),
    input_filename = paste0("bc_monthly_biomass_raw/Monthly/V5NA05.02.HybridBC-BC.FromBiomass.xNorthAmerica.", year, "-", month_abbr, ".nc"),
    output_filename = paste0("bc_monthly_biomass/", year, month, ".fst")
  ) 

# import .nc files and restrict to TN only, then output files
process_nc_files <- function(i) {
  r <- rast(filenames$input_filename[i])
  
  vals <- terra::extract(r, grid, ID = FALSE)
  
  dt <- data.table(
    idx   = grid$idx,
    value = vals[[1]],
    date  = as.integer(str_extract(filenames$output_filename[i], "\\d{6}"))
  ) 
  
  dt <- dt[!is.na(value)]
  write_fst(dt, filenames$output_filename[i])
}

lapply(
  seq_len(nrow(filenames)),
  process_nc_files
)

# Figure ------------------------------------------------------------------

folder_path <- 'bc_monthly_biomass/'
file_names <- list.files(path = folder_path, pattern = '\\.fst$', full.names = TRUE)
file_names <- file_names[grepl("2017", file_names)]

.d <- map(file_names, read_fst) %>% 
  bind_rows()

monthly_average <- .d |> 
  group_by(idx) |> 
  dplyr::summarise(monthly_average = mean(value, na.rm = TRUE))

grid <- vect("bc_monthly_biomass/grid.gpkg")
fig <- merge(grid, monthly_average, by = "idx", all.x = TRUE)

#plot(fig, "monthly_average")
plet(fig, "monthly_average", col = viridis::inferno(100))
