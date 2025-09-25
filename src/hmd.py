import os
import pandas as pd
from src.helper import SETTINGS, OUT_PATH
from src import log


# get specified path for hmd and load into dataframe
def load_hmd() -> pd.DataFrame:
    log.log("loading HMD into memory...")

    path = SETTINGS["hmd_path"]

    # find sex file
    sex = SETTINGS["hmd_sex"]
    dirs = [f for f in os.listdir(path) if f.endswith(f"_{sex}")]
    if len(dirs) != 1: log.error(f"HMD directories are indistinguishable or not found", path)
    path = os.path.join(path, dirs[0])
    
    # TODO make it possible to select age class through settings
    value = "1x1"
    dirs = [f for f in os.listdir(path) if f.endswith(f"_{value}")]
    if len(dirs) != 1: log.error("HMD age class directories are indistinguishable or not found", path)
    path = os.path.join(path, dirs[0])

    # get .txt file
    dirs = [f for f in os.listdir(path)]
    if len(dirs) != 1: log.error(".txt is indistinguishable or cannot be found", path)
    path = os.path.join(path, dirs[0])

    df = pd.read_csv(
        path, 
        sep=r"\s+", # split if more than 1 space between columns 
        engine="python",
        skiprows=2)

    return df


def format_hmd(df: pd.DataFrame) -> pd.DataFrame:
    log.log("formatting HMD...")

    hmd_variables = ["PopName", "Year", "Age", "lx"] # alter accordingly to variables found in HMD life tables
    df = df[hmd_variables].copy() # filter for selected columns
    df.rename(columns={"PopName": "ISO3"}, inplace=True) 
    df["Age"] = pd.to_numeric(df["Age"].str.extract(r"(\d+)")[0], errors="coerce") # force age to be numeric, get rid of signs (e.g. +)
    
    # normalise data 
    if SETTINGS["standardise_lx"] and "lx" in df.columns:
        # normalise lx 0-1 instead of per 100,000
        df["lx"] = pd.to_numeric(df["lx"], errors="coerce")
        lx0 = (df.loc[df["Age"] == 0, ["ISO3", "Year", "lx"]].rename(columns={"lx": "lx0"})) # relative to the age 0 of each sub-selection (country, year)
        df = df.merge(lx0, on=["ISO3", "Year"], how="left")
        df["lx"] = df["lx"] / df["lx0"]
        df.drop(columns="lx0", inplace=True)

    return df


def generate_hmd_df() -> pd.DataFrame:
    raw_hmd_df = load_hmd()
    hmd_df = format_hmd(raw_hmd_df)

    path = os.path.join(OUT_PATH, "hmd.csv")
    hmd_df.to_csv(path, index=False)

    log.log("formated HMD successfully, exported as: " + path)
    return hmd_df