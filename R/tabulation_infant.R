
# Geocoding summary -------------------------------------------------------

# child cohort
temp_folder <- "Z:/modified_degauss/"
files <- paste0(temp_folder, "/child_cohort_", 1:6, "/track.csv")

combined_data <- rbindlist(lapply(files, read.csv), use.names = TRUE, fill = TRUE)

combined_data %>% 
  group_by(status) %>% 
  summarise(total_n = sum(n),
            total_unique_n = sum(unique_n)) %>% 
  arrange(desc(total_n))

# Tabulation data ---------------------------------------------------------

# locations of birth addresses
temp_folder <-   "W:/Data/Tan/temp/"
files <- paste0(temp_folder, "/temp_degauss_child", 1:6, "/temp_geocoded_census_road.rds")

combined_data <- rbindlist(lapply(files, readRDS), use.names = TRUE, fill = TRUE)

combined_data_unnest <- unnest(combined_data, cols = data)

setDT(combined_data_unnest)
setorder(combined_data_unnest, recip, start_date, end_date)
combined_data_unnest_birth <- combined_data_unnest[, .SD[1], by = recip]

setDT(combined_data_unnest_birth)
combined_data_unnest_birth[, primary_road_category := fcase(
  dist_to_1100 < 50, "<50",
  dist_to_1100 >= 1000, ">=1000",
  default = paste0(floor(dist_to_1100/50)*50, "-<", floor(dist_to_1100/50)*50+50)
)]

combined_data_unnest_birth[, secondary_road_category := fcase(
  dist_to_1200 < 50, "<50",
  dist_to_1200 >= 1000, ">=1000",
  default = paste0(floor(dist_to_1200/50)*50, "-<", floor(dist_to_1200/50)*50+50)
)]

# Aisha's project ---------------------------------------------------------

combined_data_unnest_birth_2010_2022 <- combined_data_unnest_birth[as.Date("2010-01-01") <= TN_DOB & TN_DOB <= as.Date("2022-12-31")]

# primary road (Davidson)
summary_primary_road <- combined_data_unnest_birth_2010_2022[, .N, by = .(census_block_group_id_2010, primary_road_category)]
summary_primary_road_davidson <- summary_primary_road[str_detect(census_block_group_id_2010, "^47037")]
summary_primary_road_davidson[, N := fifelse(N<11, "<11", as.character(N))]
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_primary_road_davidson <- left_join(summary_primary_road_davidson,
                                           census_geom,
                                           by = "census_block_group_id_2010") %>% st_as_sf()
summary_primary_road_davidson %>% st_write('Y:/data/Aisha_data/primary_roads_davidson.shp', delete_dsn = T)

# secondary road (Davidson)
summary_secondary_road <- combined_data_unnest_birth_2010_2022[, .N, by = .(census_block_group_id_2010, secondary_road_category)]
summary_secondary_road_davidson <- summary_secondary_road[str_detect(census_block_group_id_2010, "^47037")]
summary_secondary_road_davidson[, N := fifelse(N<11, "<11", as.character(N))]
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_secondary_road_davidson <- left_join(summary_secondary_road_davidson,
                                             census_geom,
                                             by = "census_block_group_id_2010") %>% st_as_sf()
summary_secondary_road_davidson %>% st_write('Y:/data/Aisha_data/secondary_roads_davidson.shp', delete_dsn = T)

# asthma outcome (Davidson)
library(haven)
ev_link_v2022 <- read_sas("Y:/data/ev_link_v2022.sas7bdat") %>% 
  dplyr::select(recip, STUDYID)
ev_tb50b_v2022 <- read_sas("Y:/data/ev_tb50b_v2022.sas7bdat")
ev_tb50b_v2022 <- ev_tb50b_v2022 %>% 
  dplyr::select(STUDYID, J_INF_ASTHMA1) %>% 
  left_join(., ev_link_v2022, by = "STUDYID") %>% 
  dplyr::select(-STUDYID)
ev_tb50b_v2022 <- as.data.table(ev_tb50b_v2022)
combined_data_unnest_birth_2010_2022_asthma <- ev_tb50b_v2022[combined_data_unnest_birth_2010_2022, on = "recip"]
summary_asthma <- combined_data_unnest_birth_2010_2022_asthma[, .N, by = .(census_block_group_id_2010, J_INF_ASTHMA1)]
summary_asthma_davidson <- summary_asthma[str_detect(census_block_group_id_2010, "^47037")]
summary_asthma_davidson[, N := fifelse(N<11, "<11", as.character(N))]
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_asthma_davidson <- left_join(summary_asthma_davidson,
                                     census_geom,
                                     by = "census_block_group_id_2010") %>% st_as_sf()
summary_asthma_davidson %>% st_write('Y:/data/Aisha_data/asthmas_davidson.shp', delete_dsn = T)

# primary road (Nashville)
combined_data_unnest_birth_2010_2022_nashville <- combined_data_unnest_birth_2010_2022[city == "Nashville"]
summary_primary_road_nashville <- combined_data_unnest_birth_2010_2022_nashville[, .N, by = .(census_block_group_id_2010, primary_road_category)]
summary_primary_road_nashville[, N := fifelse(N<11, "<11", as.character(N))]
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_primary_road_nashville <- left_join(summary_primary_road_nashville,
                                            census_geom,
                                            by = "census_block_group_id_2010") %>% st_as_sf()
summary_primary_road_nashville %>% st_write('Y:/data/Aisha_data/primary_roads_nashville.shp', delete_dsn = T)

# secondary road (Nashville)
combined_data_unnest_birth_2010_2022_nashville <- combined_data_unnest_birth_2010_2022[city == "Nashville"]
summary_secondary_road_nashville <- combined_data_unnest_birth_2010_2022_nashville[, .N, by = .(census_block_group_id_2010, secondary_road_category)]
summary_secondary_road_nashville[, N := fifelse(N<11, "<11", as.character(N))]
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_secondary_road_nashville <- left_join(summary_secondary_road_nashville,
                                              census_geom,
                                              by = "census_block_group_id_2010") %>% st_as_sf()
summary_secondary_road_nashville %>% st_write('Y:/data/Aisha_data/secondary_roads_nashville.shp', delete_dsn = T)

# asthma outcome (Nashville)
library(haven)
ev_link_v2022 <- read_sas("Y:/data/ev_link_v2022.sas7bdat") %>% 
  dplyr::select(recip, STUDYID)
ev_tb50b_v2022 <- read_sas("Y:/data/ev_tb50b_v2022.sas7bdat")
ev_tb50b_v2022 <- ev_tb50b_v2022 %>% 
  dplyr::select(STUDYID, J_INF_ASTHMA1) %>% 
  left_join(., ev_link_v2022, by = "STUDYID") %>% 
  dplyr::select(-STUDYID)
ev_tb50b_v2022 <- as.data.table(ev_tb50b_v2022)
combined_data_unnest_birth_2010_2022_nashville <- combined_data_unnest_birth_2010_2022[city == "Nashville"]
combined_data_unnest_birth_2010_2022_asthma_nashville <- ev_tb50b_v2022[combined_data_unnest_birth_2010_2022_nashville, on = "recip"]
summary_asthma <- combined_data_unnest_birth_2010_2022_asthma_nashville[, .N, by = .(census_block_group_id_2010, J_INF_ASTHMA1)]
summary_asthma_nashville <- summary_asthma[str_detect(census_block_group_id_2010, "^47037")]
summary_asthma_nashville[, N := fifelse(N<11, "<11", as.character(N))]
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_asthma_nashville <- left_join(summary_asthma_nashville,
                                      census_geom,
                                      by = "census_block_group_id_2010") %>% st_as_sf()
summary_asthma_nashville %>% st_write('Y:/data/Aisha_data/asthmas_nashville.shp', delete_dsn = T)

# EV project map ----------------------------------------------------------

# asthma outcome
d <- read_rds("Y:/Aki_env_data_test/TennCare/asthma_analysis/child_cohort_temp.rds") 
colnames(d) <- tolower(colnames(d)) 
d <- d %>% 
  filter(tn_dob>= ymd("1995-01-01") & tn_dob <= ymd("2016-12-31")) %>% 
  filter(elig1 == 1) %>% 
  filter(elig4_6 == 1)

d_combined <- left_join(d, combined_data_unnest_birth, "recip")

## census block group-level
summary_asthma <- d_combined[, .N, by = .(census_block_group_id_2010, j_inf_asthma1)]
#summary_asthma_davidson[, N := fifelse(N<11, "<11", as.character(N))]
summary_asthma_total <- summary_asthma %>% 
  group_by(census_block_group_id_2010) %>% 
  summarize(total_n = sum(N, na.rm = TRUE),
            n_asthma = sum(J_INF_ASTHMA1, na.rm = TRUE),
            prop = n_asthma/total_n)
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_asthma <- left_join(summary_asthma_total,
                            census_geom,
                            by = "census_block_group_id_2010") %>% st_as_sf()
mapview::mapview(summary_asthma, zcol = "prop")

## census tract-level
summary_asthma <- d_combined[, .N, by = .(census_tract_id_2010, J_INF_ASTHMA1)]
#summary_asthma_davidson[, N := fifelse(N<11, "<11", as.character(N))]
summary_asthma_total <- summary_asthma %>% 
  group_by(census_tract_id_2010) %>% 
  summarize(total_n = sum(N, na.rm = TRUE),
            n_asthma = sum(J_INF_ASTHMA1, na.rm = TRUE),
            prop = n_asthma/total_n)
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_asthma <- left_join(summary_asthma_total,
                            census_geom,
                            by = "census_tract_id_2010") %>% st_as_sf()
mapview::mapview(summary_asthma, zcol = "prop")


# primary road (Davidson)
summary_primary_road <- combined_data_unnest_birth[, .N, by = .(census_block_group_id_2010, primary_road_category)]
summary_primary_road_total <- summary_primary_road %>% 
  group_by(census_block_group_id_2010) %>% 
  summarize(total_N = sum(N))

summary_primary_road <- left_join(summary_primary_road, summary_primary_road_total, by = "census_block_group_id_2010")
summary_primary_road <- summary_primary_road %>% 
  mutate(prop = N/total_N)
census_geom <- read_rds("data/block_group_shp_all_TN_2010.rds") %>% 
  st_transform(crs = 4326)
summary_primary_road_tn <- left_join(summary_primary_road,
                                     census_geom,
                                     by = "census_block_group_id_2010") %>% st_as_sf()
summary_primary_road_tn <- drop_na(summary_primary_road_tn)
mapview::mapview(summary_primary_road_tn, xcol = "prop")
summary_primary_road_tn %>% write_rds("")
