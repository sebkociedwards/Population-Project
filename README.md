# Population Genetics Project: A Demographic Transitions Analysis Tool
## Project Overview

This application has the original intention in analysing demographic data using the Human Mortality Database (HMD) and Human Fertility Database (HFD) to explore population genetic metrics across industrialised periods. It additinally uses World Bank Income Statuses, and Modern Hunter Gather Data. 

Although this is the orginal intent of the application; any CSV file can be added (provided it fills the [requirements](###Data-Format-Requirements) to be analysed).

The entry point of this program is the main.py, which orchestrates the data collection and formating, as well as acting as a wrapper to integrate R for further processing and analysis.

**Current Version** 2.0

**Supervisor** A.D.J Overall

---

## Table of contents

1. [Research Focus](#research-focus)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [Data Sources](#data-sources)
5. [Project Structure](#project-structure)
6. [Usage Instructions](#usage-instructions)
7. [Calculated Parameters](#calculated-parameters)
8. [Hunter-Gatherer Data](#hunter-gatherer-data)
9. [Features](#features)
10. [Troubleshooting](#troubleshooting)
11. [References](#references)

---

## Research Focus

---

## System Requirements 

### Software Dependencies 
- **Python 3.8** (for data preprocessing)
- **R 4.5.1** (for data handeling and processing - specified in settings.json5)

### Required R Packages 
```r
- shiny
- bs4Dash
- data.table
- shinyWidgets
- RColorBrewer
```

### Required Python Packages
See `requirements.txt`:
```
beautifulsoup4==4.14.2
pandas==2.3.2
requests==2.32.5
python-dotenv==1.1.1
numpy
openpyxl==3.1.5
json5==0.12.1
numpy
```
---

## Insilation

### 1. Clone the repository or download zip package attatched 
```bash
git clone [repository-url]
cd [project-directory]
```

### 2. Set Up Python Environment
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Set Up R Environment
```R
# In R console
install.packages(c("shiny", "bs4Dash", "data.table", "shinyWidgets", "RColorBrewer"))
```
### 4. Configure Database Credentials

Create a `.env` file in the project root:
```
EMAIL=your_email@example.com
PASSWORD=your_password
```

**IMPORTANT**: You must have the same email and password registered at both:
- [Human Mortality Database (HMD)](https://www.mortality.org/)
- [Human Fertility Database (HFD)](https://www.humanfertility.org/)

---

## Data Sources

### 1. Human Mortality Database (HMD)
- **URL**: https://www.mortality.org/
- **Data Used**: Female life tables (lt_female.zip)
- **Coverage**: 30+ countries, 1800-present
- **Variables**: lx (survivorship), qx (death probability), ex (life expectancy), Age, Year

### 2. Human Fertility Database (HFD)
- **URL**: https://www.humanfertility.org/
- **Data Used**: Age-Specific Fertility Rates (asfr.zip)
- **Variables**: mx (fertility rate), Age, Year

### 3. World Bank Country and Lending Groups (WBLG)
- **URL**: https://datahelpdesk.worldbank.org/
- **Data Used**: Historical classification by income (XLSX format)
- **Purpose**: Income-based filtering (High, Upper Middle, Lower Middle, Low)

---

## Project Structure

```
project/
│
├── main.py                          # Main execution script
├── requirements.txt                 # Python dependencies
├── settings.json5                   # Configuration file
├── .env                            # Database credentials (create this)
├── .env.example                    # Template for .env
├── README.md                        # This file
│
├── src/
│   ├── python/
│   │   ├── helper.py               # Utility functions & paths
│   │   ├── log.py                  # Logging functionality
│   │   ├── hmd.py                  # HMD data download & processing
│   │   ├── hfd.py                  # HFD data download & processing
│   │   ├── income_status.py        # World Bank data processing
│   │   ├── life_table.py           # Life table generation
│   │   ├── country_table.py        # Country-level metrics
│   │   └── Keyfitz_entropy.py      # H_N calculations (Giaimo 2024)
│   │
│   └── R/
│       ├── life_table_derivatives.R    # Calculate dx, sx, vx, etc.
│       ├── generation_time.R           # Calculate T (generation time)
│       ├── ne_felsenstein.R            # Calculate Ne (Felsenstein method)
│       └── mx_shape_metrics.R          # Calculate skew & kurtosis
│
├── ShinyPipeline.R                  # Interactive dashboard
│
├── data/
│   ├── raw/                         # Downloaded data (auto-generated)
│   │   ├── HMD/
│   │   ├── HFD/
│   │   └── WBLG/
│   └── processed/                   # Processed output (auto-generated)
│       └── data[N]/                 # Numbered output folders
│           ├── life_table.csv
│           ├── country_table.csv
│           ├── income_status.csv
│           ├── hmd.csv
│           ├── hfd.csv
│           └── log_file.log
│
├── Ache__Hurtado__Hill.xlsx        # Hunter-gatherer data
└── Hadza__Blurton_Jones_data.xlsx  # Hunter-gatherer data
```

---


## Usage Instructions

### Basic Workflow

#### Step 1: Download Data (First Time Only)
```bash
python3 main.py --download
```

This will:
1. Download data from HMD, HFD, and World Bank
2. Process and merge datasets
3. Calculate all demographic derivatives
4. Generate output CSVs in `data/processed/data[N]/`
5. Launch the Shiny dashboard automatically

**Note**: Download takes ~5-10 minutes depending on connection speed.

#### Step 2: Interact with the Dashboard

Once launched, the application will:
- Open automatically in your default web browser at `http://127.0.0.1:7398`
- Display the interactive Shiny dashboard
- Allow real-time analysis and visualization

**To stop the application**: Press `Ctrl+C` in the terminal

---

## Calculated Parameters

### Life Table Variables

| Parameter | Description | Source | Calculation |
|-----------|-------------|--------|-------------|
| **Age** | Age in years (0-110) | HMD | Direct from data |
| **Year** | Calendar year | HMD/HFD | Direct from data |
| **lx** | Survivorship (proportion surviving to age x, normalized to l₀=1) | HMD | K/K₀ where K is radix scale |
| **mx** | Age-specific fertility rate | HFD | Direct from data |
| **qx** | Death probability at age x | HMD | Direct from data |
| **ex** | Life expectancy at age x | HMD | Direct from data |
| **K** | Radix scale survivorship (per 100,000) | HMD | Original lx before normalization |
| **dx** | Proportion dying between age x and x+1 | Calculated | 1 - lx+1/lx |
| **sx** | Survival probability | Calculated | 1 - dx |
| **N** | Population size at age x | Calculated | lx × 1000 |
| **vx** | Reproductive value variance component | Calculated | (lxmx_STAND_SUM_qx[x+1])²/lx[x+1]² |
| **lxmx** | Reproductive output | Calculated | lx × mx |
| **lxmx_STAND** | Standardized reproductive output | Calculated | lxmx / sum(lxmx) |
| **mx_ADJ** | Adjusted fertility | Calculated | lxmx_STAND / lx |
| **lxmx_STAND_SUM_qx** | Cumulative reproductive potential from age x | Calculated | sum(lxmx_STAND[x:ω]) |

### Country-Level Metrics

| Parameter | Description | Method | Reference |
|-----------|-------------|--------|-----------|
| **T** | Generation time (mean age of reproduction) | sum(Age × lx × mx) / sum(lx × mx) | Standard demographic |
| **Ne** | Effective population size | Felsenstein (1971) method | `ne_felsenstein.R` |
| **N_ratio** | Ne/N ratio | Ne / sum(N) | Calculated |
| **H_N** | Keyfitz entropy (mortality heterogeneity) | Fundamental matrix method | Giaimo (2024) Eq. 2 |
| **mx_skew** | Skewness of fertility distribution | sum((mx-mean(mx))³)/((n-1)×sd(mx)³) | Shape metric |
| **mx_kurtosis** | Kurtosis of fertility distribution | sum((mx-mean(mx))⁴)/((n-1)×sd(mx)⁴) | Shape metric |
| **mx_norm_ratio** | R₀/TFR ratio (NOT CURRENTLY CALCULATED - PLACEHOLDER) | Ratio of net reproductive rate to total fertility | Planned |
| **IS** | Income status classification | World Bank | H=High, UM=Upper Middle, LM=Lower Middle, L=Low |

### Special Age Parameters (Levitis & Bingaman Lackey 2013)

| Parameter | Description | Calculation |
|-----------|-------------|-------------|
| **B** | Beginning of reproductive period | Age at which 5% of lifetime fertility has occurred |
| **M** | End of reproductive period | Age at which 95% of lifetime fertility has occurred |
| **Z** | Near endpoint of survival | Age at which 95% of cohort years lived have passed |
| **PrR** | Postreproductive Representation | Proportion of adult years lived after age M: TM/TB |

**Note**: PrR distinguishes "Post-fertile Viability" (ability to survive past reproduction) from "Post-fertile Stage" (evolved life history stage with significant post-fertile population representation).

---

## Hunter-Gather Data

### Purpose
Hunter-gatherer populations serve as **reference baselines** representing pre-industrial demographic patterns. 

### Included Datasets

1. **Ache** (`Ache__Hurtado__Hill.csv`)
   - Source: Hurtado & Hill ethnographic data
   - Location: Paraguay
   - Lifestyle: Forest foragers

2. **Hadza** (`Hadza__Blurton_Jones_data.csv`)
   - Source: Blurton Jones field data
   - Location: Tanzania
   - Lifestyle: Savanna foragers

3. **!Kung** (`!kung-data.csv`)
   - Source: 
   - Location: Botswana/Namibia
   - Lifestyle: Desert foragers



### Data Format Requirements

If adding your own hunter-gatherer or reference population data, use this CSV format:

```csv
Age,lx,mx
0,1.000,0.000
1,0.950,0.000
2,0.940,0.000
...
12,0.920,0.005
13,0.915,0.010
...
45,0.650,0.120
...
55,0.400,0.000
...
```

**Required Columns**:
- `Age`: Integer age in years
- `lx`: Survivorship, **normalized to l₀ = 1.0** (NOT radix scale)
- `mx`: Age-specific fertility rate

**Important Notes**:
- `lx` must be normalized (start at 1.0, not 100,000)
- Include boundary ages if available (12- for fertility start, 55+ for fertility end, 110+ for mortality end)
- Missing values should be left blank or use `NA`
- Include `ISO3_suffix` column if distinguishing sub-populations

---

## Features 

### Shiny Dashboard Capabilities

1. **Multiple Simultaneous Analyses**
   - Create up to 10 independent analyses
   - Each with separate parameter configurations
   - Real-time comparison across populations

2. **Flexible Variable Selection**
   - **X-axis**: Year, Age, T, N_ratio, H_N, mx_skew, mx_kurtosis, etc.
   - **Y-axis**: lx, mx, qx, ex, T, Ne, etc.
   - Smart filtering (e.g., Age only pairs with life_table variables)

3. **Population Filtering**
   - **Global**: All countries
   - **Custom**: Select specific countries (up to 10)
   - **Income-based**: Filter by World Bank income status
     - High Income (H)
     - Upper Middle Income (UM)
     - Lower Middle Income (LM)
     - Low Income (L)

4. **Temporal Analysis**
   - Year range slider (min-max from data)
   - Age range slider (0-110 years)
   - Quartile sampling for clean visualization
   - Handles 1800-present timespan

5. **Visualization Options**
   - **Line plots**: Show trends over time/age
   - **Scatter plots**: Show individual data points
   - **Custom labels**: Override default axis labels
   - **Custom titles**: Set analysis-specific titles
   - **Interactive legends**: Dynamic country/year display

6. **Export Functionality**
   - Download plots (PNG, 1200×800, 120 DPI)
   

### Data Processing Features

1. **Modular Pipeline**
   - Python: Data downloading and preprocessing
   - R: Statistical calculations and demographic metrics
   - Clear separation of concerns

2. **Performance Optimization notes**
   - `data.table` for efficient data operations
   - Keyed tables for fast filtering
   - Vectorized calculations (no loops in H_N calculation)
   - Quartile sampling for large datasets

3. **Current Error Handling checks (should get rid of at end)**
   - Diagnostic logging throughout pipeline
   - Validation against supervisor benchmarks
   - NA handling for missing data
   - Merge conflict detection

4. **Configuration Management**
   - `settings.json5` for easy parameter adjustment
   - Toggle edge data inclusion (12-, 55+, 110+)
   - Age range customization (min_age, max_age)

---

## Configuration (settings.json5)

```json5
{
  min_age: 0,
  max_age: 110,              // HMD ranges from 0-110
  include_edge_data: true,   // Include 12-, 55+, 110+ 
  r_version: "R-4.5.1",
}
```
## Troubleshooting

### Common Issues

#### 1. Download Fails
**Symptom**: "could not download .zip content from the HMD/HFD"

**Solutions**:
- Check internet connection
- Verify credentials in `.env` file
- Ensure same email/password at both HMD and HFD
- Check if databases are online (maintenance periods)

#### 2. Shiny App Won't Start
**Symptom**: "Shiny crashed Exit code [N]"

**Solutions**:
- Check R is installed: `R --version`
- Verify R packages: Run in R console:
  ```r
  library(shiny)
  library(bs4Dash)
  library(data.table)
  ```
- Check port 7398 is available: `lsof -i :7398`
- Look at R stderr output in terminal

#### 3. Performance Issues
**Symptoms**: Application crashes, timeouts, lag

**Solutions**:
- Reduce number of countries selected (<10 recommended)
- Increase timeout in `ShinyPipeline.R` if needed


#### 4. Missing Data
**Symptom**: "No data available" in plots

**Solutions**:
- Check country has both HMD and HFD data
- Verify year range has data for selected countries
- Check income filter isn't excluding all countries
- Review `log_file.log` for processing errors

#### 5. Merge Conflicts
**Symptom**: Duplicate rows in output

**Solutions**:
- Check `ISO3_suffix` is included in merge keys
- Review diagnostic logging for merge operations
- Verify hunter-gatherer data doesn't conflict with HMD/HFD countries

#### 6. Permission denied when accsessing data
- This is usually because the file is open on your device elsewhere

### Logging

To see moreextensive debigging comments check 'Log_file.log' in your output directory

## Methodological Notes

### Keyfitz Entropy (H_N) Implementation

Our implementation follows **Giaimo (2024) Equation 2**, using the **fundamental matrix method**:

1. Build transition matrix **U** from survival probabilities
2. Calculate fundamental matrix **N = (I - U)⁻¹**
3. Build mortality matrix **M**
4. Calculate: **H_N = (e^T × N × M × N × e₁) / (e^T × N × e₁)**


### Fertility Distribution Shapes

We calculate **skewness** and **kurtosis** across **all ages** (including boundary zeros at 12- and 55+) to capture the **full shape** of the fertility schedule, including:
- Early peak (high skew)
- Late peak (low skew)  
- Concentrated reproduction (high kurtosis)
- Spread-out reproduction (low kurtosis)


## Pipeline Execution Order

The `main.py` script orchestrates the following sequence:

```
1. Python: Download & format HMD data → hmd.csv
2. Python: Download & format HFD data → hfd.csv  
3. Python: Merge HMD+HFD → life_table.csv
4. Python: Download & format World Bank data → income_status.csv
5. Python: Create country index → country_table.csv
6. Python: Calculate Keyfitz entropy H_N → adds to country_table.csv

7. R: Calculate life table derivatives (dx, sx, vx, etc.) → updates life_table.csv
8. R: Calculate generation time T → adds to country_table.csv
9. R: Calculate Ne (Felsenstein) → adds to country_table.csv
10. R: Calculate mx shape metrics → adds to country_table.csv

11. R Shiny: Launch interactive dashboard → reads final CSVs
```

---

## Future Development

### todo notes

1. **Mediation Analysis**
   - Formally test disease → fertility → survival → Ne pathway
   - Implement Bayesian network analysis
   - Add causal inference tools

2. **mx_norm_ratio Calculation**
   - Implement R₀/TFR ratio
   - Add to country_table calculations


3. **Website Deployment**
   - Deploy as permanent, searchable website
   - Use shinyapps.io for immediate access
   - GitHub + Zenodo DOI for long-term archival

5. **Additional Statistical Analysis**
   - More sophisticated comparative analyses
   - Automated significance testing
   - Confidence intervals and uncertainty quantification

---

## References

### Primary Methodological Sources

1. **Levitis & Bingaman Lackey (2013)**  
   "A measure for describing and comparing post-reproductive life span as a population trait"  
   _Evolutionary Anthropology_, 22:66-79  
   DOI: 10.1002/evan.21332
   - PrR calculation methodology
   - Ages B, M, Z definitions
   - Null hypothesis testing via simulation

2. **Giaimo (2024)**  
   "Keyfitz' entropy..."  
   Equation 2: Fundamental matrix method for H_N

3. **Felsenstein (1971)**  
   "Inbreeding and variance effective numbers in populations with overlapping generations"  
   - Ne calculation for age-structured populations

### Data Sources

- **Human Mortality Database**: https://www.mortality.org/  
  University of California, Berkeley & Max Planck Institute for Demographic Research

- **Human Fertility Database**: https://www.humanfertility.org/  
  Max Planck Institute for Demographic Research & Vienna Institute of Demography

- **World Bank**: https://datahelpdesk.worldbank.org/  
  Historical country income classifications

---



## Changelog

### Version 2.0 (Current)
- Complete Shiny dashboard rewrite with bs4Dash
- Added Keyfitz entropy (H_N) calculations
- Implemented mx shape metrics (skew & kurtosis)
- Added hunter-gatherer reference data
- Performance optimization with data.table
- Quartile sampling for clean visualization
- Multi-analysis capability (up to 10 simultaneous)

### Version 1.0
- Initial Python-R pipeline
- Basic HMD/HFD integration
- Ne and T calculations
- Simple plotting in R

---


## additinal TODO (Developer notes)

1. encorperate mediation analysis
2. add feature where other data files can be incorperated for comparsiosns like income, health ect.
3. Upload webiste to shinyCloud
4. Not tested for Mac currently; hypothetically should work
5. Maybe make HG data year agonistic - as to not be time bound - currently set a 1980
6. update sources and check if read me file is up to date - incl. strcuture 

