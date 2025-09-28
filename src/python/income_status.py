import os, requests
import pandas as pd
from src.python.helper import OUT_PATH, DOWNLOAD_FOLDER, SETTINGS
from src.python import log


download_url = "https://ddh-openapi.worldbank.org/resources/DR0095334/download"
download_path = os.path.join(DOWNLOAD_FOLDER, "WBLG", "WorldBank_Country_LendingGroups.xlsx")


def download_income_status():
    # no need to login for world bank

    with requests.Session() as s:

        # download content
        log.log("downloading .xlxs from the WBLG database...")
        r = s.get(download_url, timeout=60)
        r.raise_for_status()
        if not r.content:
            log.error("could not download .xlsx content from the WBLG")
            raise RuntimeError()

        # make sure output directory exists
        path = os.path.dirname(download_path)
        os.makedirs(path, exist_ok=True)

        # IMPORTANT: for world bank, path include file name.xlxs
        path = download_path
        with open(path, "wb") as f:
            f.write(r.content)
    
        log.log("successfully downloaded .xlxs from the WBLG")


def load_income_status(path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Country Analytical History")
  
    log.log("loaded the WBLG data into memory")
    return df


def format_income_status(df: pd.DataFrame) -> pd.DataFrame:
    df = df.iloc[4:228].reset_index(drop=True) # grab subset of just data we want
    df.drop(df.columns[1], axis=1, inplace=True) # drop country column, already hav iso3

    # assign column names
    years = df.iloc[0, 1:].tolist()
    df.columns = ["ISO3"] + years; # asign names of columns 

    # drop unneeded header rows
    df.drop(index=range(0, 6), inplace=True) # remove rows before start of data

    # transpose the dataframe from wide to long
    df_long = df.melt(id_vars=["ISO3"], var_name="Year", value_name="income_status")
    df_long["Year"] = df_long["Year"].astype(int)

    # sort to country is completed before moving to next
    df_long = df_long.sort_values(by=["ISO3", "Year"]).reset_index(drop=True)

    log.log("formated the income status of countries")
    return df_long


def generate_income_status_df():
    if SETTINGS["download"]: download_income_status()

    raw_income_status_df = load_income_status(download_path)
    income_status_df = format_income_status(raw_income_status_df)

    path = os.path.join(OUT_PATH, "income_status.csv")
    income_status_df.to_csv(path, index=False)

    log.log("successfully generated the income status of countries: " + path)
    return income_status_df, path
