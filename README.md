## Modified DeGAUSS – Environmental Exposure Assessment Pipeline (**Under Construction**)

### Overview

This project provides a pipeline for environmental exposure assessment using a modified version of DeGAUSS.

It can process both child cohort data and dyad (mother–child pair) cohort data.

For information about the motivation for this program, the list of environmental exposure variables, and detailed guidance for practitioners, please visit [this website](https://akishiroshita.github.io/modified-DeGAUSS-instruction/).

## File Structure

### Main scripts

- **`modified_degauss_run_infancy.R`**: Child cohort processing pipeline (exposure period during infancy, from birth to the 1st birthday).
  
- **`modified_degauss_run_dyad.R`**: Dyad cohort (mother–child pair) processing pipeline.

- **`modified_degauss_run_childhood.R`**: Child cohort processing pipeline (exposure period during childhood, from birth to the 4th birthday).

### Processing steps

Each pipeline consists of the following steps:

1. **Initial setup** (`R/initial_set_up.R`)
   - Loads required libraries and sets environment variables.

2. **Data cleaning** 
   - `R/child_cohort_preparation_infancy.R` (child cohort, exposure during infancy: birth to 1st birthday).
   - `R/dyad_cohort_preparation_simple.R` (dyad cohort).
   - `R/child_cohort_preparation_childhood.R` (child cohort, exposure during childhood: birth to 4th birthday).
   - Cleans and standardizes input data.

3. **Geocoding** (`R/geocoding_infancy.R`, `R/geocoding_pregnancy.R`, or `R/geocoding_childhood.R`)
   - Converts addresses to geographic coordinates (latitude/longitude).

4. **Census boundary & redlining** (`R/census.R`)
   - Assigns census tract boundaries and historical redlining indicators.

5. **Road proximity** (`R/road.R`)
   - Calculates distance to the nearest roads.

6. **Greenspace** (`R/green.R`)
   - Calculates greenspace exposure metrics.

7. **Deprivation index** (`R/dep_index.R`)
   - Assigns area-level deprivation / socioeconomic status indices.

8. **Road density** (`R/road_density.R`)
   - Calculates road density (length of roads per unit area).

9. **NO2 exposure** (`R/no2_monthly_infancy.R`, `R/no2_monthly_pregnancy.R`, or `R/no2_monthly_childhood.R`)
   - Assigns NO₂ exposure using monthly concentration data.

10. **Black carbon (BC) exposure** (`R/bc_infancy.R`, `R/bc_pregnancy.R`, or `R/bc_childhood.R`)
    - Assigns black carbon exposure estimates.

11. **Tabulation** 
    - `R/tabulation.R` (child cohort).
    - `R/tabulation_dyad.R` (dyad cohort).
    - Creates summary tables.

12. **Final cleaning**
    - `R/final_clean_child.R` (child cohort).
    - `R/final_clean_dyad.R` (dyad cohort).
    - Performs final data cleaning and removes PHI (Protected Health Information).
    
## Setup

### Initial setup

When opening this project for the first time, run the following commands:

```r
install.packages('renv')
library(renv)
renv::activate()
renv::restore()
```

Required packages are managed in the `renv.lock` file. Running `renv::restore()` will install the appropriate package versions.

### Every session

Every time you start a new R session, run the **Initial setup** section in the main script.
    
## Usage

### 1. Configure paths

**Child cohort – infancy (birth to 1st birthday)** (`modified_degauss_run_infancy.R`):
```r
# ver 1
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_1.csv"
output_folder <- "Y:/modified_degauss/child_cohort_1"
temp_folder <- "W:/Data/Tan/temp/temp_degauss_child1"
```

**Dyad cohort** (`modified_degauss_run_dyad.R`):
```r
# ver 1
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_dyad_mom.csv"
output_folder <- "Y:/modified_degauss/dyad_cohort_1"
temp_folder <- "W:/Data/Tan/temp/temp_degauss_dyad1"
```

**Child cohort – childhood (birth to 4th birthday)** (`modified_degauss_run_childhood.R`):
```r
# ver 21
input_folder <- "W:/Data/Tan/subset"
input_file <- "ev_address_1.csv"
output_folder <- "Y:/modified_degauss/child_cohort_21"
temp_folder <- "W:/Data/Tan/temp/temp_degauss_child21"
```

### 2. Execute pipeline

Run all sections sequentially from the **Initial setup** section onward.  
Each step depends on outputs from previous steps, so they must be run without interruption.

### 3. Check logs

After processing completes, timing logs are saved to the following files:
- Child cohort: `tictoc_child_log.txt`
- Dyad cohort: `tictoc_dyad_log.txt`
    
## Input data requirements

- Address data in CSV format.
- Required columns:

**Child cohort**:  

- `recip`  
- `TN_DOB` (Year-Month-Day)  
- `BEG` (set to the first day of the month corresponding to the original BEG date in the address file)  
- `END` (set to the first day of the month corresponding to the original END date in the address file)  
- `ADDRESS`  

**Dyad cohort**:  

- `recip`
- `mrecip`
- `TN_DOB` (Year-Month-Day)  
- `LMP` (Year-Month-Day)  
- `BEG` (set to the first day of the month corresponding to the original BEG date in the address file)  
- `END` (set to the first day of the month corresponding to the original END date in the address file)
- `ADDRESS`

## Output data

Processed data are saved to `output_folder` with all PHI (Protected Health Information) removed.  
Intermediate files (which may contain PHI) are saved to `temp_folder`.

## Important notes

1. **PHI handling**: Intermediate files may contain PHI. Manage `temp_folder` appropriately and ensure compliance with data protection regulations.
    
2. **Optional steps**: Some steps (parsing, traffic density, road proximity × traffic density) are currently commented out and can be enabled if needed.
    
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
