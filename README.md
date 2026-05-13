## Modified DeGAUSS – Environmental Exposure Assessment Pipeline

### Overview

This project provides a pipeline for environmental exposure assessment using a modified version of [DeGAUSS](https://degauss.org/).

This software efficiently performs geocoding and derives environmental variables based on the longitude, latitude, and exposure period associated with each residential address.

[DeGAUSS](https://degauss.org/) is designed to derive environmental variables while preserving the privacy of protected health information (PHI). It uses Docker images to process address data; users upload a CSV file containing address information and receive an output file with various environmental variables.

However, there are some limitations of original DeGAUSS:

-   Not optimized for very large datasets.

-   Requires input and output files to be stored in the same folder.

-   Does not support creation of custom variables.

Therefore, this program was created to add some improvements:

-   Avoid reliance on Docker, using Podman only for part of the process. (VUMC moved from Docker to Podman in October 2025)

-   Utilize C and C++ in the backend wherever possible.

-   Enable parallel processing with multiple cores (optimized for Podman).

-   Restrict environmental data to Tennessee only, not the entire U.S.

Modified DeGAUSS provides clean, processed output files with all PHI removed.

For the list of environmental exposure variables and detailed guidance for practitioners, please visit [this website](https://akishiroshita.github.io/modified-DeGAUSS-instruction/).

## File Structure

### Main scripts

- **`modified_degauss_run_dyad.R`**: Dyad cohort (mother–child pair) processing pipeline (exposure during pregnancy).

- **`modified_degauss_run_infant.R`**: Infant cohort processing pipeline (exposure period during infancy, from birth to the 1st birthday).

- **`modified_degauss_run_child.R`**: Child cohort processing pipeline (exposure period during childhood, from birth to the 4th birthday).

### Processing steps

Each pipeline sources the scripts below in this exact order (see the `modified_degauss_run_*.R` files):

1. **Initial setup** (`R/initial_set_up.R`)
   - Loads required libraries and starts the Podman backend.

2. **Cleaning**
   - `R/dyad_cohort_preparation_simple.R` (dyad cohort, exposure during pregnancy).
   - `R/infant_cohort_preparation_simple.R` (infant cohort, exposure during infancy: birth to 1st birthday).
   - `R/child_cohort_preparation_simple.R` (child cohort, exposure during childhood: birth to 4th birthday).
   - Cleans and standardizes input data and produces address-period records.

3. **Geocoding** (`R/geocoding_dyad.R`, `R/geocoding_infant.R`, or `R/geocoding_child.R`)
   - Converts addresses to geographic coordinates (latitude/longitude) via the Podman geocoder container.

4. **Census boundary & redlining** (`R/census.R`)
   - Assigns 2010 / 2020 census tract and block group IDs and historical redlining grades.

5. **Road proximity** (`R/road.R`)
   - Calculates distance to the nearest primary (S1100) and secondary (S1200) roads.

6. **Greenspace** (`R/green.R`)
   - Calculates greenspace metrics (EVI) within 500 m, 1500 m, and 2500 m buffers.

7. **Deprivation index** (`R/dep_index.R`)
   - Assigns area-level deprivation / socioeconomic status indices used in the main pipeline.
   - Companion scripts (sourced for Britt's project to support the deprivation/RUCA outputs consumed by `R/final_clean_*.R`):
     - `R/dep_index_britt.R` – additional deprivation indices (ADI, SVI, COI, EJI, CRE, NDI, NSES, SDI, EQI, DCI).
     - `R/ruca.R` – Rural–Urban Commuting Area (RUCA) ZIP-level codes from the University of Washington WWAMI RHRC, plus a binary Urban/Rural indicator derived from RUCA 2.0 (Categorization C).

8. **Traffic density (AADT)** (`R/aadt.R`)
   - Calculates vehicle-meters and truck-meters within a 500 m buffer using 2014 Tennessee HPMS AADT, separated into "moving" (Interstate / Freeway-Expressway) and "stop-go" (Principal/Minor Arterial) traffic.

9. **Road density** (`R/road_density.R`)
   - Calculates road length (S1100 / S1200 / S1400) within a buffer.

10. **NO₂ exposure** (`R/no2_monthly_infant.R`, `R/no2_monthly_dyad.R`, or `R/no2_monthly_child.R`)
    - Assigns average monthly NO₂ levels during the exposure period.

11. **Black carbon (BC) exposure** (`R/bc_infant.R`, `R/bc_dyad.R`, or `R/bc_child.R`)
    - Assigns average black carbon levels during the exposure period.

12. **Final cleaning**
    - `R/final_clean_dyad.R` (dyad cohort).
    - `R/final_clean_infant.R` (infant cohort).
    - `R/final_clean_child.R` (child cohort).
    - Combines per-batch outputs, derives a `relocation` indicator (any address change during the exposure period), removes geometry and other PHI, and writes:
      - `env_data_long_<cohort>.csv` (environmental exposures, long format)
      - `no2_summary_<cohort>.csv` (one row per subject)
      - `bc_summary_<cohort>.csv` (one row per subject)
      - `deprivation_index_long_<cohort>.csv` (Britt's project deprivation indices, including RUCA / Urban–Rural for the infant cohort).

Optional / currently commented-out steps in the main scripts:

- **Parsing** (`R/parsing.R`) – address parsing helper.
- **Road proximity × traffic density** (`R/road_and_aadt.R`) – nearest high-traffic road distance plus its AADT, derived after the AADT step.
- **Tabulation** (`R/tabulation_dyad.R`, `R/tabulation_infant.R`, `R/tabulation_child.R`) – summary tables.

### Data folder
Download the original and/or processed environmental data from [here](https://vanderbilt.box.com/s/m3l5bfe8gwfqhrqj1apbalbje5n8gf1b) (an invitation is required).

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

Install [Podman](https://github.com/containers/podman/blob/main/docs/tutorials/podman-for-windows.md):

As of October 29, 2025, the latest version is podman-installer-windows-amd64.exe (sha256:5e97bd3a56eba7302c94a2b11a8a639f513830c228d27f9cda7e557a77bd4379).

After installation, run the following commands to initialize and start Podman:
```         
podman
```

Check the status and start the Podman machine:
```         
podman machine start
```

Prepare the necessary containers so that we avoid pulling Docker images from the public repository every time we run the command.

```         
podman run -it -d --name gs --entrypoint /bin/bash ghcr.io/degauss-org/postal:0.1.4
podman run -it -d --name gs2 --entrypoint /bin/bash degauss/geocoder:3.0
```

**Cautions**:

-   Avoid launching the same Podman container multiple times from multiple RStudio sessions, as it may lead to unintentional errors.

-   Parallel processes require CPU cores and memory. If your system doesn't have enough resources, processes can fail. $\rightarrow$ Reduce the number of workers used by setting the multisession plan to use fewer workers.

### Every session

Launch RStudio.
Every time you start a new R session, run the **Initial setup** section in the main script.

## Usage

### 0. Data preparation

This program requires the following data format:

-   Address data should be in CSV format.

-   In TennCare, `BEG` and `END` are given in year–month format: in the TennCare address data, these correspond to address start month and address end month.

-   Convert these to the first day of the corresponding month.

-   Although the program is flexible, the ideal address format is "first address line" (you may not include second address line, but it is acceptable) + "5-digit ZIP code".

-   Add a flag indicating whether the address is located in Tennessee. This may be necessary to accurately identify subjects who moved outside TN (0 = not TN, 1 = TN, missing).

**Dyad cohort**

| recip | TN_DOB     | BEG        | END        | mrecip | LMP       | address                                | TN_flag |
|-------|------------|------------|------------| -------|-----------|----------------------------------------|---------|
| 1     | 2010-10-14 | 2010-10-01 | 2010-10-01 | 101    | 2010-6-14 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |
| 1     | 2010-10-14 | 2011-12-01 | 2011-12-01 | 101    | 2010-6-14 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |
| 2     | 2022-01-06 | 2022-01-01 | 2022-04-01 | 102    | 2021-10-02| 2600 Hillsboro Pike Nashville TN 37212 | 1       |

- `recip` (child ID)
- `mrecip` (mother's ID)
- `TN_DOB` (Year-Month-Day)
- `LMP` (Year-Month-Day)
- `BEG` (set to the first day of the month corresponding to the original BEG date in the address file)
- `END` (set to the first day of the month corresponding to the original END date in the address file)
- `address`
- `TN_flag` (flag indicating whether the address is located in Tennessee)

**Infant cohort**

| recip | TN_DOB     | BEG        | END        | address                                | TN_flag |
|-------|------------|------------|------------|----------------------------------------|---------|
| 1     | 2010-10-14 | 2010-10-01 | 2010-10-01 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |
| 1     | 2010-10-14 | 2011-12-01 | 2011-12-01 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |
| 2     | 2022-01-06 | 2022-01-01 | 2022-04-01 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |

- `recip`
- `TN_DOB` (Year-Month-Day)
- `BEG` (set to the first day of the month corresponding to the original BEG date in the address file)
- `END` (set to the first day of the month corresponding to the original END date in the address file)
- `address`
- `TN_flag` (flag indicating whether the address is located in Tennessee)

**Child cohort**

| recip | TN_DOB     | BEG        | END        | address                                | TN_flag |
|-------|------------|------------|------------|----------------------------------------|---------|
| 1     | 2010-10-14 | 2010-10-01 | 2010-10-01 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |
| 1     | 2010-10-14 | 2011-12-01 | 2011-12-01 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |
| 2     | 2022-01-06 | 2022-01-01 | 2022-04-01 | 2600 Hillsboro Pike Nashville TN 37212 | 1       |

- `recip`
- `TN_DOB` (Year-Month-Day)
- `BEG` (set to the first day of the month corresponding to the original BEG date in the address file)
- `END` (set to the first day of the month corresponding to the original END date in the address file)
- `address`
- `TN_flag` (flag indicating whether the address is located in Tennessee)

### 1. Configure paths

Each run script ships with several pre-defined path "versions" (e.g. `ver 1`, `ver 2`, ...). Uncomment the block you want to use and leave the others commented out. Example values:

**Dyad cohort** (`modified_degauss_run_dyad.R`, `ver 1`):
```r
input_folder  <- "Z:/Data/Tan/subset"
input_file    <- "ev_dyad_1.csv"
output_folder <- "X:/modified_degauss/dyad_cohort_1"
temp_folder   <- "Z:/Data/Tan/temp/temp_degauss_dyad1"
```

**Infant cohort** (`modified_degauss_run_infant.R`, `ver 1`):
```r
input_folder  <- "Z:/Data/Tan/subset"
input_file    <- "ev_address_1.csv"
output_folder <- "X:/modified_degauss/child_cohort_1"
temp_folder   <- "Z:/Data/Tan/temp/temp_degauss_child1"
```

**Child cohort** (`modified_degauss_run_child.R`, `ver 21`):
```r
input_folder  <- "Z:/Data/Tan/subset"
input_file    <- "ev_address_1.csv"
output_folder <- "X:/modified_degauss/child_cohort_21"
temp_folder   <- "Z:/Data/Tan/temp/temp_degauss_child21"
```

### 2. Execute pipeline

Run all sections sequentially from the **Initial setup** section onward.
Each step depends on outputs from previous steps, so they must be run without interruption.

### 3. Check logs

After processing completes, timing logs are saved to the following files:
- Dyad cohort: `tictoc_dyad_log.txt`
- Infant cohort: `tictoc_infant_log.txt`
- Child cohort: `tictoc_child_log.txt`

## Output data

Processed data are saved to `output_folder` with all PHI (Protected Health Information) removed.
Intermediate files (which may contain PHI) are saved to `temp_folder`.

Per-cohort outputs written by the **Final cleaning** step:
- `env_data_long_<cohort>.csv` – environmental exposures in long format (one row per address period), including census IDs, redlining, road proximity, road density, greenspace, and traffic-density metrics (`length_*`, `vehicle_meters_*`, `truck_meters_*` for `moving` and `stop_go`).
- `no2_summary_<cohort>.csv` – one row per subject with the average NO₂ exposure during the exposure period.
- `bc_summary_<cohort>.csv` – one row per subject with the average black carbon exposure during the exposure period.
- `deprivation_index_long_<cohort>.csv` – Britt's-project deprivation indices in long format (ADI / SVI / COI / EJI / CRE / DCI / NDI / NSES / SDI / EQI), plus `redlining` and `relocation` (and `ruca_urban_rural` for the infant cohort).

## Important notes

1. **PHI handling**: Intermediate files may contain PHI. Manage `temp_folder` appropriately and ensure compliance with data protection regulations.

2. **Optional steps**: Parsing, road proximity × traffic density (`R/road_and_aadt.R`), and tabulation are currently commented out in the run scripts and can be enabled if needed.

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
