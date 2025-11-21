# README ----------------------------------------------------------

######################################################################################
##When opening this project for the first time, please run the following commands::  #
#install.packages('renv')                                                            # 
#library(renv)                                                                       #
#renv::activate()                                                                    #
#renv::restore()                                                                     # 
#####################################################################################

# Could you provide the path to the input folder containing the address data and the file name?
# What is the path to the output folder where you’d like to store the processed data after removing all PHI data?
# If you would like to create a temporary folder in a different location to store intermediate files containing PHI, please specify the path.

# ver 1
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_dyad_1.csv"
output_folder <- "Y:/modified_degauss/dyad_cohort_1"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_dyad1"

# ver 2
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_dyad_2.csv"
output_folder <- "Y:/modified_degauss/dyad_cohort_2"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_dyad2"

# ver 3
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_dyad_3.csv"
output_folder <- "Y:/modified_degauss/dyad_cohort_3"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_dyad3"

# ver 4
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_dyad_4.csv"
output_folder <- "Y:/modified_degauss/dyad_cohort_4"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_dyad4"

# ver 5
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_dyad_5.csv"
output_folder <- "Y:/modified_degauss/dyad_cohort_5"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_dyad5"

##############################################################
# Execute this script from the next section all at once!! ####
##############################################################

# Initial set-up ----------------------------------------------------------

# Everytime you launch this R studio, please run the following command.

source("R/initial_set_up.R", echo = FALSE, print.eval = TRUE)

# Cleaning ----------------------------------------------------------------

tictoc::tic("Cleaning")
source("R/dyad_cohort_preparation_simple.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Parsing -----------------------------------------------------------------

#tictoc::tic("Parsing")
#source("R/parsing.R", echo = FALSE, print.eval = FALSE)
#tictoc::toc(log = TRUE)

# Geocoding ---------------------------------------------------------------

tictoc::tic("Geocoding")
source("R/geocoding_pregnancy.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Census boundary & redlining ---------------------------------------------

tictoc::tic("Census boundary & redlining")
source("R/census.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Road proximity ----------------------------------------------------------

tictoc::tic("Road proximity")
source("R/road.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Greenspace --------------------------------------------------------------

tictoc::tic("Greenspace")
source("R/green.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Deprivation index -------------------------------------------------------

tictoc::tic("Deprivation index")
source("R/dep_index.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Traffic density ---------------------------------------------------------

#tictoc::tic("Traffic density")
#source("R/aadt.R", echo = FALSE, print.eval = FALSE)
#tictoc::toc(log = TRUE)

# Road proximity * traffic density ----------------------------------------

#tictoc::tic("Road proximity * traffic density")
#source("R/road_and_aadt.R", echo = FALSE, print.eval = FALSE)
#tictoc::toc(log = TRUE)

# Road density ----------------------------------------

tictoc::tic("Road density")
source("R/road_density.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# NO2 ---------------------------------------------------------------------

# should tweak my program!
tictoc::tic("NO2")
#source("R/no2.R", echo = FALSE, print.eval = FALSE)
source("R/no2_monthly_pregnancy.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# BC ----------------------------------------------------------------------

# should tweak my program!
tictoc::tic("BC")
source("R/bc_pregnancy.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Tabulation data ---------------------------------------------------------

tictoc::tic("Tabulation data")
source("R/tabulation_dyad.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Final cleaning ----------------------------------------------------------

# for the dyad cohort
tictoc::tic("Final cleaning")
source("R/final_clean_dyad.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Retrieve the logs
tictoc_logs <- unlist(tic.log(format = TRUE))
print(tictoc_logs)
writeLines(tictoc_logs, "tictoc_dyad_log.txt")
