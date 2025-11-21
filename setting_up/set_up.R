install.packages('renv')
library(renv)

# Initialize renv in the current project
renv::init()

install.packages('pacman')

## from CRAN

cran_packages <- c(
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
  "exactextractr",
  "fst",
  "qs",
  "s2",
  "lwgeom",
  "geohashTools",
  "OfflineGeocodeR",
  "dht",
  "tigris"
)

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, ask = "never")
  }
}

invisible(lapply(cran_packages, install_if_missing))

## from GitHub

if (!requireNamespace("OfflineGeocodeR", quietly = TRUE)) {
  remotes::install_github("cole-brokamp/OfflineGeocodeR", upgrade = TRUE, build_vignettes = TRUE, dependencies = TRUE)
}

if (!requireNamespace("dht", quietly = TRUE)) {
  remotes::install_github("degauss-org/dht", upgrade = TRUE, build_vignettes = TRUE, dependencies = TRUE)
}

if (!requireNamespace("tigris", quietly = TRUE)) {
  remotes::install_github("walkerke/tigris", upgrade = TRUE, build_vignettes = TRUE, dependencies = TRUE)
}

## Load packages

#all_packages <- c(cran_packages, "icons", "emo")

#invisible(lapply(all_packages, function(pkg) {
#  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
#}))

pacman::p_load(
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
  "exactextractr",
  "fst",
  "qs",
  "s2",
  "lwgeom",
  "geohashTools",
  "OfflineGeocodeR",
  "dht",
  "tigris"
)

# check the status
renv::status()

# update the lockfile
renv::snapshot()
