import pandas as pd
import os
from src.helper import SETTINGS, OUT_PATH
from src import log


def load_income_status() -> pd.DataFrame:
    log.log("loading income statuses into memory...")

    path = SETTINGS["wb_path"]
    path = os.path.join(path, "OGHIST_2025_07_01.xlsx")
    df = pd.read_excel(path, sheet_name="Country Analytical History")
  
    return df


def format_income_status(df: pd.DataFrame) -> pd.DataFrame:
    log.log("formatting income statuses...")

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

    return df_long


def generate_income_status_df() -> pd.DataFrame:
    raw_income_status_df = load_income_status()
    income_status_df = format_income_status(raw_income_status_df)

    path = os.path.join(OUT_PATH, "income_status.csv")
    income_status_df.to_csv(path, index=False)

    log.log("formated income statuses successfully, exported as: " + path)
    return income_status_df
