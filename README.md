# Instructions

## Setup

### MacOS

```
pip install -r requirements.txt
```

## Execution

### Download and run

Primary command to download the databases from the internet, and run the program for formatting and analyses.

```
python3 main.py --download
```

### Run

Default command after data has been downloaded. Code is ran on the previously downloaded data.

```
python3 main.py
```

### Help

For more help.

```
python3 main.py --help
```

Data collection:

HMD data: https://www.mortality.org/Data/ZippedDataFiles
female: https://www.mortality.org/File/GetDocument/hmd.v6/zip/by_statistic/lt_female.zip
male: https://www.mortality.org/File/GetDocument/hmd.v6/zip/by_statistic/lt_male.zip
both: https://www.mortality.org/File/GetDocument/hmd.v6/zip/by_statistic/lt_both.zip

HFD: https://www.humanfertility.org/Data/ZippedDataFiles
asfr: https://www.humanfertility.org/File/Download/Files/zip/asfr.zip

World Bank Country and Lending Groups: https://datahelpdesk.worldbank.org/knowledgebase/articles/906519-world-bank-country-and-lending-groups?utm_source=chatgpt.com
current: https://ddh-openapi.worldbank.org/resources/DR0095333/download
historical: https://ddh-openapi.worldbank.org/resources/DR0095334/download

make sure email and password are the same for both websites (HMD and HFD)

TODO:
fix ISO3 conflicts (e.g. DEUTE > DEU)
form metadata

NOTE:
the Ne calculation is not fully correct, but numbers are too low when using the "correct" formula. as of right now, I have removed the 1 + from the demoninator
