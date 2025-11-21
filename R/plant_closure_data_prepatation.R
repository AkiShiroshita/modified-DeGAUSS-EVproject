
# Set-up ------------------------------------------------------------------

library(readxl)
library(tidyverse)
library(sf)
#library(mapview)

# ver 1
input_folder <- "X:/data_v2022"
input_file <- "ev_address_1.csv"
output_folder <- "Y:/modified_degauss/child_cohort_1"
temp_folder <-   "X:/temp/temp_degauss_child1"

# ver 2
input_folder <- "X:/data_v2022"
input_file <- "ev_address_2.csv"
output_folder <- "Y:/modified_degauss/child_cohort_2"
temp_folder <-   "X:/temp/temp_degauss_child2"

# ver 3
input_folder <- "X:/data_v2022"
input_file <- "ev_address_3.csv"
output_folder <- "Y:/modified_degauss/child_cohort_3"
temp_folder <-   "X:/temp/temp_degauss_child3"

# ver 4
input_folder <- "X:/data_v2022"
input_file <- "ev_address_4.csv"
output_folder <- "Y:/modified_degauss/child_cohort_4"
temp_folder <-   "X:/temp/temp_degauss_child4"

# ver 5
input_folder <- "X:/data_v2022"
input_file <- "ev_address_5.csv"
output_folder <- "Y:/modified_degauss/child_cohort_5"
temp_folder <-   "X:/temp/temp_degauss_child5"

# ver 6
input_folder <- "X:/data_v2022"
input_file <- "ev_address_6.csv"
output_folder <- "Y:/modified_degauss/child_cohort_6"
temp_folder <-   "X:/temp/temp_degauss_child6"

# Retirement data ---------------------------------------------------------

# Power Plant Retirements
# EPA compiles US Energy Information Administration (EIA) power plant data and displays recent and expected power plant retirements.
# Primary data source: coal, gas, oil, and other combustion power plant retirements compiled from EIA's Preliminary Monthly Electric Generator Inventory and EIA's Electric Power Monthly. 
# https://www.eia.gov/electricity/data/eia860m/
# https://www.eia.gov/electricity/monthly/
# Capacity from facilities with a total generator nameplate capacity less than 1 MW are excluded.

retirement_data <- read_excel("data/retirement_data_wide.xlsx") |> 
  filter(`Retirement Year` <= 2021) %>% 
  filter(`Fuel Catagory` != "Other")

retirement_data_sf <- st_as_sf(retirement_data, coords = c("Plant longitude", "Plant latitude"), crs = 4326)  # WGS84

mapview(retirement_data_sf, zcol = "Fuel Catagory", layer.name = "Power Plant Retirements")

retirement_data_sf_buffer <- retirement_data_sf %>% 
  st_buffer(10000) 

mapview(retirement_data_sf_buffer) + mapview(retirement_data_sf, zcol = "Fuel Catagory", layer.name = "Power Plant Retirements")

# Study population --------------------------------------------------------

d <- fst::read_fst(paste0(temp_folder, '/', 'temp_geocoded.fst'), as.data.table = TRUE)
d <- na.omit(d, cols = c("lat", "lon"))

d <- st_as_sf(d, coords = c("lon", "lat"), crs = 4326)|> st_transform(5072)

retirement_data <- read_excel("data/retirement_data_wide.xlsx") |> 
  filter(`Retirement Year` <= 2021) %>% 
  filter(`Fuel Catagory` != "Other")

retirement_data_sf <- st_as_sf(retirement_data, coords = c("Plant longitude", "Plant latitude"), crs = 4326)  # WGS84

retirement_data_sf_projected <- retirement_data_sf %>% 
  sf::st_transform(crs = 5072) 

nearest_index_1100 <- st_nearest_feature(d, retirement_data_sf_projected)

d$dist_to_plant <- purrr::map2_dbl(1:nrow(d),
                                   nearest_index_1100,
                                   ~round(sf::st_distance(d[.x,], retirement_data_sf_projected[.y,]), 1))

d %>% filter(dist_to_plant<=10000)
