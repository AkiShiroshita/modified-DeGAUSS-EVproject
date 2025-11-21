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
input_file <- "ev_address_1.csv"
output_folder <- "Y:/modified_degauss/child_cohort_1"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_child1"

# ver 2
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_2.csv"
output_folder <- "Y:/modified_degauss/child_cohort_2"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_child2"

# ver 3
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_3.csv"
output_folder <- "Y:/modified_degauss/child_cohort_3"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_child3"

# ver 4
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_4.csv"
output_folder <- "Y:/modified_degauss/child_cohort_4"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_child4"

# ver 5
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_5.csv"
output_folder <- "Y:/modified_degauss/child_cohort_5"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_child5"

# ver 6
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_6.csv"
output_folder <- "Y:/modified_degauss/child_cohort_6"
temp_folder <-   "W:/Data/Tan/temp/temp_degauss_child6"

##############################################################
# Execute this script from the next section ####
##############################################################

# Initial set-up ----------------------------------------------------------

# Everytime you launch this R studio, please run the following command.

source("R/initial_set_up.R", echo = FALSE, print.eval = TRUE)

# Cleaning ----------------------------------------------------------------

tictoc::tic("Cleaning")
source("R/child_cohort_preparation_simple.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Parsing -----------------------------------------------------------------

#tictoc::tic("Parsing")
#source("R/parsing.R", echo = FALSE, print.eval = FALSE)
#tictoc::toc(log = TRUE)

# Geocoding ---------------------------------------------------------------

tictoc::tic("Geocoding")
source("R/geocoding_child.R", echo = FALSE, print.eval = FALSE)
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

tictoc::tic("NO2")
#source("R/no2.R", echo = FALSE, print.eval = FALSE)
source("R/no2_monthly_child.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# BC ----------------------------------------------------------------------

tictoc::tic("BC")
source("R/bc_child.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Tabulation data ---------------------------------------------------------

tictoc::tic("Tabulation data")
source("R/tabulation.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Final cleaning ----------------------------------------------------------

# for the child cohort
tictoc::tic("Final cleaning")
source("R/final_clean_child.R", echo = FALSE, print.eval = FALSE)
tictoc::toc(log = TRUE)

# Retrieve the logs
tictoc_logs <- unlist(tic.log(format = TRUE))
print(tictoc_logs)
writeLines(tictoc_logs, "tictoc_child_log.txt")

