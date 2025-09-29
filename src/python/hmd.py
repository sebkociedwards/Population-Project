import os, requests, zipfile, io
import pandas as pd
from bs4 import BeautifulSoup
from src.python.helper import SETTINGS, OUT_PATH, EMAIL, PASSWORD, DOWNLOAD_FOLDER
from src.python import log


login_url = "https://www.mortality.org/Account/Login"
download_url = "https://www.mortality.org/File/GetDocument/hmd.v6/zip/by_statistic/lt_female.zip"
download_path = os.path.join(DOWNLOAD_FOLDER, "HMD")


# downloads the hmd
def download_hmd():
    # run session to persist with cookies
    with requests.Session() as s:
        # get anti-forgery token
        r = s.get(login_url, timeout=60)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "html.parser")
        token = soup.find("input", {"name": "__RequestVerificationToken"}).get("value")
        if not token:
            log.error("could not fetch anti-forgery token for the HMD")
            raise RuntimeError()
        log.log("fetched anti-forgery token for the HMD")

        # post login credentials and token
        payload = {
        "Email": EMAIL,
        "Password": PASSWORD,
        "__RequestVerificationToken": token
        }

        r = s.post(login_url, data=payload, timeout=60)
        r.raise_for_status()
        if "Logout" not in r.text and "Log out" not in r.text:
            log.error("failed to login to the HMD")
            raise RuntimeError()
        log.log("successfully logged in to the HMD")

        # download content
        log.log("downloading .zip for HMD...")
        r = s.get(download_url, timeout=60)
        r.raise_for_status()
        if not r.content:
            log.error("could not download .zip content from the HMD")
            raise RuntimeError()
        log.log("successfully downloaded .zip from the HMD")

        # extract .zip file to output directory
        with zipfile.ZipFile(io.BytesIO(r.content)) as file:
            file.extractall(download_path)
        log.log("HMD .zip successfully extracted to: " + download_path)


# get specified path for hmd and load into dataframe
def load_hmd(path) -> pd.DataFrame:
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

    log.log("loaded the HMD into memory")
    return df


def format_hmd(df: pd.DataFrame) -> pd.DataFrame:
    # TODO possibly implement formating for age clases

    hmd_variables = ["PopName", "Year", "Age", "lx"] # alter accordingly to variables found in HMD life tables
    df = df[hmd_variables].copy() # filter for selected columns
    df.rename(columns={"PopName": "ISO3"}, inplace=True) 
    df["Age"] = pd.to_numeric(df["Age"].str.extract(r"(\d+)")[0], errors="coerce") # force age to be numeric, get rid of signs (e.g. +)

    # keep original survivorship as K (radix scale, e.g. per 100,000)
    df.rename(columns={"lx": "K"}, inplace=True)
    df["K"] = pd.to_numeric(df["K"], errors="coerce")

    # base at Age==0 when present
    base0 = (
    df.loc[df["Age"] == 0, ["ISO3", "Year", "K"]].rename(columns={"K": "K0"}))

    # merge K0
    df = df.merge(base0, on=["ISO3", "Year"], how="left")

    # normalise lx with l0 = 1
    df["lx"] = df["K"] / df["K0"]
    df.drop(columns="K0", inplace=True)

    # drop last row of every group because values are 110+, not 110
    if SETTINGS["include_edge_data"] == False:
        df = (
            df.groupby(["ISO3", "Year"], group_keys=False)
            .apply(lambda g: g.iloc[:-1])
        )

    log.log("formatted the HMD")
    return df


def generate_hmd_df() -> pd.DataFrame:
    if SETTINGS["download"]: download_hmd()

    raw_hmd_df = load_hmd(download_path)
    hmd_df = format_hmd(raw_hmd_df)

    path = os.path.join(OUT_PATH, "hmd.csv")
    hmd_df.to_csv(path, index=False)

    log.log("successfully generated the HMD: " + path)
    return hmd_df