import os
import pandas as pd
from src import log
from src.helper import export_df_to_csv, OUT_PATH


HFD_PATH = "project/data/raw/asfr"


# get specified path for hfd and load into dataframe
def load_hfd() -> pd.DataFrame:
    log.log("loading HFD into memory...")

    path = HFD_PATH

    # TODO implement method to choose asfr - e.g. RR (registered births, resident mothers), TR (total births, resident mothers)
    asfr_type = "RR"

    # get file
    dirs = [f for f in os.listdir(path) if f.endswith(f"RR.txt")]
    if len(dirs) != 1: log.error(f"HFD files are indistinguishable or not found", path)
    path = os.path.join(path, dirs[0])

    df = pd.read_csv(
        path, 
        sep=r"\s+", # split if more than 1 space between columns 
        engine="python",
        skiprows=2)

    return df


def format_hfd(df: pd.DataFrame) -> pd.DataFrame:
    log.log("formatting HFD...")
    
    df.rename(columns={"Code": "ISO3"}, inplace=True)
    df["Age"] = pd.to_numeric(df["Age"].str.extract(r"(\d+)")[0], errors="coerce") # force age to be numeric, get rid of signs (e.g. +)

    return df


def generate_hfd_df():
    raw_hfd_df = load_hfd()
    hfd_df = format_hfd(raw_hfd_df)

    path = os.path.join(OUT_PATH, "hfd.csv")
    export_df_to_csv(hfd_df, path)

    log.log("formated HFD successfully exported as: " + path)
    return hfd_df