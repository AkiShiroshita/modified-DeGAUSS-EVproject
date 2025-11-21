
# Set-up ------------------------------------------------------------------

library(tidyverse)
library(tidylog)
library(readxl)
library(data.table)
library(sf)
library(tigris)
library(fst)

# Tabulation data ---------------------------------------------------------

setwd("Z:/Britt_preliminary_data")

deprivation_index_long <- read_csv("preliminary_analysis_data/deprivation_index_long.csv")

# just checking
env_data <- fread("Z:/data/modified_degauss/env_data_long_child.csv")
data <- read_rds("Z:/Aki_env_data_test/TennCare/asthma_analysis/child_cohort_temp.rds")

data <- merge(env_data, data, by = "recip", all.x = TRUE)
colnames(data) <- tolower(colnames(data)) 

deprivation_index_long <- data %>% 
  filter(tn_dob>= ymd("1995-01-01") & tn_dob <= ymd("2016-12-31")) %>% 
  filter(elig1 == 1) %>% 
  filter(elig4_6 == 1) %>% 
  filter(!is.na(dist_to_1100)) # because once geocoded, everyone has distance to roads

# The number of address registrations
table(deprivation_index_long$relocation)

# The number of address registrations per person
num <- deprivation_index_long %>% 
  count(recip, name='N')
with(num, table(N))

# The number of address relocations per person
num <- deprivation_index_long %>% 
  group_by(recip) %>% 
  filter(relocation==1) %>% 
  count(relocation, name='N') %>% 
  ungroup()
with(num, table(N))

# Summary of the change in these indices at the first relocation per person (each person has a single relocation)
lag_summary <- deprivation_index_long %>% 
  arrange(recip, start_date, end_date) %>% 
  group_by(recip) %>% 
  mutate(relocation_cumsum = cumsum(relocation)) %>% 
  filter(relocation_cumsum == 0 | relocation_cumsum == 1) %>% 
  mutate(adi_ADI_STATERNK_lag = lag(adi_ADI_STATERNK),
         svi_AREA_SQMI_lag = lag(svi_AREA_SQMI),
         coi_z_COI_stt_lag = lag(coi_z_COI_stt)) %>% 
  ungroup() %>% 
  drop_na(adi_ADI_STATERNK_lag, svi_AREA_SQMI_lag, coi_z_COI_stt_lag) %>% 
  filter(relocation_cumsum == 1) %>% 
  mutate_all(as.numeric) %>% 
  mutate(diff_adi_ADI_STATERNK = adi_ADI_STATERNK - adi_ADI_STATERNK_lag,
         diff_svi_AREA_SQMI = svi_AREA_SQMI - svi_AREA_SQMI_lag,
         diff_coi_z_COI_stt = coi_z_COI_stt - coi_z_COI_stt_lag) %>% 
  drop_na(diff_adi_ADI_STATERNK, diff_svi_AREA_SQMI, diff_coi_z_COI_stt) 

# ADI
summary(lag_summary$diff_adi_ADI_STATERNK)

ggplot(lag_summary, aes(x = diff_adi_ADI_STATERNK)) +
  geom_histogram(position = 'identity', alpha = 0.8, binwidth = 1) +
  theme_bw()

logged_values_summary %>% nrow()
logged_values_summary %>% filter(diff_adi_ADI_STATERNK>0) %>% nrow()
logged_values_summary %>% filter(diff_adi_ADI_STATERNK<0) %>% nrow()

# SVI
summary(logged_values_summary$diff_svi_AREA_SQMI)
ggplot(logged_values_summary, aes(x = diff_svi_AREA_SQMI)) +
  geom_histogram(position = 'identity', alpha = 0.8, binwidth = 1) +
  theme_bw()

logged_values_summary %>% nrow()
logged_values_summary %>% filter(diff_svi_AREA_SQMI>0) %>% nrow()
logged_values_summary %>% filter(diff_svi_AREA_SQMI<0) %>% nrow()

# COI
summary(logged_values_summary$diff_coi_z_COI_stt)

ggplot(logged_values_summary, aes(x = diff_coi_z_COI_stt)) +
  geom_histogram(position = 'identity', alpha = 0.8, binwidth = 1) +
  theme_bw()

logged_values_summary %>% nrow()
logged_values_summary %>% filter(diff_coi_z_COI_stt>0) %>% nrow()
logged_values_summary %>% filter(diff_coi_z_COI_stt<0) %>% nrow()

# Summary of change in these indices at every reloaction (each person has multiple relocations)

lag_summary2 <- deprivation_index_long %>% 
  arrange(recip, start_date, end_date) %>% 
  group_by(recip) %>% 
  mutate(adi_ADI_STATERNK_lag = lag(adi_ADI_STATERNK),
         svi_AREA_SQMI_lag = lag(svi_AREA_SQMI),
         coi_z_COI_stt_lag = lag(coi_z_COI_stt)) %>% 
  ungroup() %>% 
  drop_na(adi_ADI_STATERNK_lag, svi_AREA_SQMI_lag, coi_z_COI_stt_lag) %>% 
  mutate_all(as.numeric) %>% 
  mutate(diff_adi_ADI_STATERNK = adi_ADI_STATERNK - adi_ADI_STATERNK_lag,
         diff_svi_AREA_SQMI = svi_AREA_SQMI - svi_AREA_SQMI_lag,
         diff_coi_z_COI_stt = coi_z_COI_stt - coi_z_COI_stt_lag) %>% 
  drop_na(diff_adi_ADI_STATERNK, diff_svi_AREA_SQMI, diff_coi_z_COI_stt) 

# ADI
summary(lag_summary2$diff_adi_ADI_STATERNK)

ggplot(lag_summary2, aes(x = diff_adi_ADI_STATERNK)) +
  geom_histogram(position = 'identity', alpha = 0.8, binwidth = 1) +
  theme_bw()

lag_summary2 %>% nrow()
lag_summary2 %>% filter(diff_adi_ADI_STATERNK>0) %>% nrow()
lag_summary2 %>% filter(diff_adi_ADI_STATERNK<0) %>% nrow()

# SVI
summary(lag_summary2$diff_svi_AREA_SQMI)

ggplot(lag_summary2, aes(x = diff_svi_AREA_SQMI)) +
  geom_histogram(position = 'identity', alpha = 0.8, binwidth = 1) +
  theme_bw()

lag_summary2 %>% nrow()
lag_summary2 %>% filter(diff_svi_AREA_SQMI>0) %>% nrow()
lag_summary2 %>% filter(diff_svi_AREA_SQMI<0) %>% nrow()

# COI
summary(lag_summary2$diff_coi_z_COI_stt)

ggplot(lag_summary2, aes(x = diff_coi_z_COI_stt)) +
  geom_histogram(position = 'identity', alpha = 0.8, binwidth = 1) +
  theme_bw()

lag_summary2 %>% nrow()
lag_summary2 %>% filter(diff_coi_z_COI_stt>0) %>% nrow()
lag_summary2 %>% filter(diff_coi_z_COI_stt<0) %>% nrow()
