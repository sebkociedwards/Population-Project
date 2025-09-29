import os
import pandas as pd
from src.python import income_status
from src.python.helper import SETTINGS, OUT_PATH


def load_life_table(life_table_path): return pd.read_csv(life_table_path, engine="python")


def format_country_table(income_status_df: pd.DataFrame, life_table_df: pd.DataFrame):
    '''
    format the income status table for WBLG so that it only filters for countries also in the life table
    '''
    inc = income_status_df.copy()
    life = life_table_df.copy()

    # make sure ISO3 all upper case
    inc["ISO3"] = inc["ISO3"].astype(str).str.upper().str.strip()
    life["ISO3"] = life["ISO3"].astype(str).str.upper().str.strip()

    # keep only rows with ISO3 in life table
    keep = set(life["ISO3"].dropna().unique())
    out = inc[inc["ISO3"].isin(keep)]

    return out


def generate_country_table(life_table_path, download: bool):
    income_status_df, path = income_status.generate_income_status_df(download)

    life_table_df = load_life_table(life_table_path)
    country_table_df = format_country_table(income_status_df, life_table_df)

    path = os.path.join(OUT_PATH, "country_table.csv")
    country_table_df.to_csv(path, index=False)
    return path
