# TODO look into finding a way to collapse extra ISO3 codes into (e.g. DEUTNP -> DEU)

import os
from src import hmd, hfd
import pandas as pd
from src.helper import SETTINGS, OUT_PATH
from src import log


def merge_hmd_hfd(hmd_df: pd.DataFrame, hfd_df: pd.DataFrame):
    log.log("merging data from HMD and HFD...")

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

    return df


def add_calculate_variables(df: pd.DataFrame):
    # TODO no safety in case variables are not in table

    log.log("calculating additional fields...")

    # force into numbers if not already
    df["lx"] = pd.to_numeric(df["lx"], errors="coerce")
    df["ASFR"] = pd.to_numeric(df["ASFR"], errors="coerce")

    # calculations
    df["lxmx"] = df["lx"] * df["ASFR"]
    df["lx_next"] = df.groupby(["ISO3", "Year"])["lx"].shift(-1)
    df["dx"] = df["lx"] - df["lx_next"]
    df["qx"] = 1 - (df["lx_next"] / df["lx"])
    df["sx"] = 1 - df["qx"]
    df["cum_lxmx"] = (
        df.groupby(["ISO3", "Year"])["lxmx"]
        .transform(lambda x: x[::-1].cumsum()[::-1])
    )
    df["vx"] = df["cum_lxmx"] / df["lx"]

    # delete unneeded columns used for caluculations
    df.drop(columns=["lx_next", "cum_lxmx"], inplace=True)

    return df


def generate_hmd_hfd_df():
    hmd_df = hmd.generate_hmd_df()
    hfd_df = hfd.generate_hfd_df()

    hmd_hfd_df = merge_hmd_hfd(hmd_df, hfd_df)
    hmd_hfd_df = add_calculate_variables(hmd_hfd_df)

    path = os.path.join(OUT_PATH, "hmd_hfd.csv")
    hmd_hfd_df.to_csv(path, index=False)

    log.log("mereged HMD and HFD dataset successfully, exported as: " + path)