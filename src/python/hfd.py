import os, requests, zipfile, io
import pandas as pd
from bs4 import BeautifulSoup
from src.python.helper import OUT_PATH, DOWNLOAD_FOLDER, EMAIL, PASSWORD, SETTINGS
from src.python import log


login_url = "https://www.humanfertility.org/Account/Login"
download_url = "https://www.humanfertility.org/File/Download/Files/zip/asfr.zip"
download_path = os.path.join(DOWNLOAD_FOLDER, "HFD")


def download_hfd():
    # run session to persist with cookies
    with requests.Session() as s:
        # get anti-forgery token
        r = s.get(login_url, timeout=60)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "html.parser")
        token = soup.find("input", {"name": "__RequestVerificationToken"}).get("value")
        if not token:
            log.error("could not fetch anti-forgery token for the HFD")
            raise RuntimeError()
        log.log("fetched anti-forgery token for the HFD")

        # post login credentials and token
        payload = {
        "Email": EMAIL,
        "Password": PASSWORD,
        "__RequestVerificationToken": token
        }

        r = s.post(login_url, data=payload, timeout=60)
        r.raise_for_status()
        if "Logout" not in r.text and "Log out" not in r.text:
            log.error("failed to login to the HFD")
            raise RuntimeError()
        log.log("successfully logged in to the HFD")

        # download content
        log.log("downloading .zip for HFD...")
        r = s.get(download_url, timeout=60)
        r.raise_for_status()
        if not r.content:
            log.error("could not download .zip content from the HFD")
            raise RuntimeError()
        log.log("successfully downloaded .zi from the HFD")

        # extract .zip file to output directory
        with zipfile.ZipFile(io.BytesIO(r.content)) as file:
            file.extractall(download_path)
        log.log("HFD .zip successfully extracted to: " + download_path)


# get specified path for hfd and load into dataframe
def load_hfd(path) -> pd.DataFrame:
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

    log.log("loaded the HFD into memory")
    return df


def format_hfd(df: pd.DataFrame) -> pd.DataFrame:
    df.rename(columns={"Code": "ISO3", "ASFR": "mx"}, inplace=True)
    df["Age"] = pd.to_numeric(df["Age"].str.extract(r"(\d+)")[0], errors="coerce") # force age to be numeric, get rid of signs (e.g. +)

    # drop first and last row of every group because 12- and 55+
    if SETTINGS["include_edge_data"] == False:
        df = (
            df.groupby(["ISO3", "Year"], group_keys=False)
            .apply(lambda g: g.iloc[1:-1])
        )

    log.log("formatted the HFD")
    return df


def generate_hfd_df():
    if SETTINGS["download"]: download_hfd()

    raw_hfd_df = load_hfd(download_path)
    hfd_df = format_hfd(raw_hfd_df)

    path = os.path.join(OUT_PATH, "hfd.csv")
    hfd_df.to_csv(path, index=False)

    log.log("successfully generated the HFD: " + path)
    return hfd_df