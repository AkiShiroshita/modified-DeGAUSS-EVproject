# Modified DeGAUSS - Environmental Exposure Assessment Pipeline (**Under Construction**)

## Overview

This project provides a pipeline for environmental exposure assessment using modified DeGAUSS.

It can process both child cohort and dyad (mother-child pair) cohort data.

If  you require information regarding our motivation for this program, a list of environmental variables, or detailed explanations for practitioners, please visit [this website](https://akishiroshita.github.io/modified-DeGAUSS-instruction/).

## File Structure

### Main Scripts

- **`modified_degauss_run_child.R`**: Child cohort data processing pipeline
  
- **`modified_degauss_run_dyad.R`**: Dyad cohort data processing pipeline

### Processing Steps

Each pipeline consists of the following steps:

1. **Initial Set-up** (`R/initial_set_up.R`)
   - Loads required libraries and sets up environment variables

2. **Data Cleaning** 
   - `R/child_cohort_preparation_simple.R` (for child cohort)
   - `R/dyad_cohort_preparation_simple.R` (for dyad cohort)
   - Cleans and standardizes input data

3. **Geocoding** (`R/geocoding_child.R` or `R/geocoding_pregnancy.R`)
   - Converts addresses to geographic coordinates (latitude/longitude)

4. **Census Boundary & Redlining** (`R/census.R`)
   - Assigns census tract boundaries and historical redlining data

5. **Road Proximity** (`R/road.R`)
   - Calculates distance to nearest roads

6. **Greenspace** (`R/green.R`)
   - Calculates greenspace exposure metrics (e.g., NDVI, park proximity)

7. **Deprivation Index** (`R/dep_index.R`)
   - Assigns area-level deprivation/socioeconomic status indices

8. **Road Density** (`R/road_density.R`)
   - Calculates road density (length of roads per unit area)

9. **NO2 Exposure** (`R/no2_monthly_child.R` or `R/no2_monthly_pregnancy.R`)
   - Assigns NO2 exposure using monthly concentration data

10. **Black Carbon (BC) Exposure** (`R/bc_child.R` or `R/bc_pregnancy.R`)
    - Assigns black carbon exposure estimates

11. **Tabulation** 
    - `R/tabulation.R` (for child cohort)
    - `R/tabulation_dyad.R` (for dyad cohort)
    - Creates summary tables

12. **Final Cleaning**
    - `R/final_clean_child.R` (for child cohort)
    - `R/final_clean_dyad.R` (for dyad cohort)
    - Final data cleaning and PHI (Protected Health Information) removal

## Setup

### Initial Setup

When opening this project for the first time, run the following commands:

```r
install.packages('renv')
library(renv)
renv::activate()
renv::restore()
```

Required packages are managed in the `renv.lock` file. Running `renv::restore()` will install the appropriate package versions.

### Every Session Launch

Every time you launch an R session, run the "Initial Set-up" section in the main script.

## Usage

### 1. Configure Paths

Uncomment the path configuration for the cohort version you want to process:

**For child cohort** (`modified_degauss_run_child.R`):
```r
# ver 1
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_1.csv"
output_folder <- "Y:/modified_degauss/child_cohort_1"
temp_folder <- "W:/Data/Tan/temp/temp_degauss_child1"
```

**For dyad cohort** (`modified_degauss_run_dyad.R`):
```r
# ver 1
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_dyad_mom.csv"
output_folder <- "Y:/modified_degauss/dyad_cohort_1"
temp_folder <- "W:/Data/Tan/temp/temp_degauss_dyad1"
```

### 2. Execute Pipeline

Run all sections sequentially from the "Initial Set-up" section onward. Each step depends on outputs from previous steps, so they must be run without interruption.

### 3. Check Logs

After processing completes, timing logs are saved to the following files:
- Child cohort: `tictoc_child_log.txt`
- Dyad cohort: `tictoc_dyad_log.txt`

## Input Data Requirements

- CSV format address data file
- Required columns are defined in each cohort preparation script

## Output Data

Processed data is saved to `output_folder` with all PHI (Protected Health Information) removed. Intermediate files (which may contain PHI) are saved to `temp_folder`.

## Important Notes

1. **PHI Handling**: Intermediate files may contain PHI. Manage `temp_folder` data appropriately and ensure compliance with data protection regulations.

2. **Optional Steps**: Some steps (Parsing, Traffic density, Road proximity × traffic density) are currently commented out and can be enabled if needed.

## License

This project is licensed under the MIT License.

Copyright (c) [2025] [Aki Shiroshita]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
