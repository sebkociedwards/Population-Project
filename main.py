import os, subprocess, argparse
from src.python.life_table import generate_life_table
from src.python.country_table import generate_country_table
from src.python.helper import DOWNLOAD_FOLDER as raw, OUTPUT_FOLDER as processed, R_PATH, SETTINGS
from src.python import log  
    

life_table_derivatives_R = "src/R/life_table_derivatives.R"
generation_time_R = "src/R/generation_time.R"
ne_felsenstein_R = "src/R/ne_felsenstein.R"


def run_r(path: str, *args: str):
    version = SETTINGS["r_version"]

    try: # MacOS
        cmd = ["Rscript", path, *map(str, args)]
        res = subprocess.run(cmd,capture_output=True, text=True)
        log.log(f"ran R (MacOS): {path}")
    except: 
        try: # Win 64
            rscript_path = fr"C:\Program Files\R\{version}\bin\Rscript"
            cmd = [rscript_path, "--vanilla", path, *map(str, args)]
            res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
            log.log(f"ran R (Win x64): {path}")
        except: # Win 86
            rscript_path = fr"C:\Program Files (x86)\R\{version}\bin\Rscript"
            cmd = [rscript_path, "--vanilla", path, *map(str, args)]
            res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
            log.log(f"ran R (Win x86): {path}")
    
    if res.stdout:
        log.log(res.stdout.strip())
    if res.stderr: # apparently some R packages write informative messages to stderr, so logging them to log.log, not to log.error
        log.log(f"[R stderr] {res.stderr.strip()}")
    if res.returncode != 0:
        log.error(f"R script failed: {os.path.basename(path)} (exit {res.returncode})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--download", action="store_true", help="Download data")
    args = parser.parse_args()

    # make sure folders exist
    for p in (raw, processed, "outputs"):
        os.makedirs(p, exist_ok=True)

    # python prep
    log.log("=== python pipeline: start ===")
    life_table_path = generate_life_table(args.download)
    country_table_path = generate_country_table(life_table_path, args.download)
    log.log("=== python pipeline: done ===")

    # r analysis
    log.log("=== r pipeline: start ===")
    run_r(life_table_derivatives_R, life_table_path) # compute fields like dx, sx, qx etc...
    run_r(generation_time_R, life_table_path, country_table_path) # calculation generation time
    run_r(ne_felsenstein_R, life_table_path, country_table_path) # calculate Ne according to felsenstein
    log.log("=== r pipeline: done ===")
