# TODO look into finding a way to collapse extra ISO3 codes into (e.g. DEUTNP -> DEU)

import os
import pandas as pd
from src.python import hmd, hfd, log
from src.python.helper import SETTINGS, OUT_PATH


def merge_hmd_hfd_df(hmd_df: pd.DataFrame, hfd_df: pd.DataFrame):
    # filter only common country, year pairs
    common_df = pd.merge(
        hmd_df[["ISO3", "Year"]].drop_duplicates(),
        hfd_df[["ISO3", "Year"]].drop_duplicates(),
        on=["ISO3", "Year"],
        how="inner"
    )

    # find all rows that exist in common
    hmd_df = hmd_df.merge(common_df, on=["ISO3", "Year"], how="inner")
    hfd_df = hfd_df.merge(common_df, on=["ISO3", "Year"], how="inner")

    # restrict HMD ages between min_age and max_age, adjust acordingly (max = 110)
    hmd_df = hmd_df[hmd_df["Age"].between(SETTINGS["min_age"], SETTINGS["max_age"])]

    # building a full age grid min_age...max_age for each common (country, year)
    ages = pd.DataFrame({"Age": list(range(SETTINGS["min_age"], SETTINGS["max_age"] + 1))})
    grid = common_df.assign(_k=1).merge(ages.assign(_k=1), on="_k").drop(columns="_k")

    # merge lx (HMD) and asfr (HFD)
    df = grid.merge(hmd_df, on=["ISO3", "Year", "Age"], how="left")
    df = df.merge(hfd_df, on=["ISO3", "Year", "Age"], how="left")

    # split ISO3 into base and suffix
    iso3 = df["ISO3"].copy().astype(str).str.upper().str.strip()
    df["ISO3"] = iso3.str.slice(0, 3)
    df["ISO3_suffix"] = iso3.str.slice(3).replace("", pd.NA)

    # reorder
    front = ["ISO3", "ISO3_suffix", "Year", "Age"]
    df = df[[*front, *[c for c in df.columns if c not in front]]]

    log.log("merged the HMD and HFD tables and separated ISO3 from the suffix")
    return df


def generate_life_table(download: bool) -> str:
    # generate formated data from HMD and HFD
    hmd_df = hmd.generate_hmd_df(download)
    hfd_df = hfd.generate_hfd_df(download)

    # merge data from HMD and HFD
    hmd_hfd_df = merge_hmd_hfd_df(hmd_df, hfd_df)

    # export
    path = os.path.join(OUT_PATH, "life_table.csv")
    hmd_hfd_df.to_csv(path, index=False)

    log.log("succesfully generated the merged life table: " + path)
    return path