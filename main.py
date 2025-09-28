import os, subprocess
from src.python.life_table import generate_life_table
from src.python.country_table import generate_country_table
from src.python.helper import DOWNLOAD_FOLDER as raw, OUTPUT_FOLDER as processed, R_PATH
from src.python import log  
    

life_table_derivatives_R = "src/R/life_table_derivatives.R"
generation_time_R = "src/R//generation_time.R"


def run_r(path: str, *args: str):
    cmd = ["Rscript", path, *map(str, args)]
    log.log(f"running R: {path}")
    res = subprocess.run(cmd,capture_output=True, text=True)
    if res.stdout:
        log.log(res.stdout.strip())
    if res.stderr: # apparently some R packages write informative messages to stderr, so logging them to log.log, not to log.error
        log.log(f"[R stderr] {res.stderr.strip()}")
    if res.returncode != 0:
        log.error(f"R script failed: {os.path.basename(path)} (exit {res.returncode})")


if __name__ == "__main__":
    # make sure folders exist
    for p in (raw, processed, "outputs"):
        os.makedirs(p, exist_ok=True)

    # python prep
    log.log("=== python pipeline: start ===")
    life_table_path = generate_life_table()
    country_table_path = generate_country_table()
    log.log("=== python pipeline: done ===")

    # r analysis
    log.log("=== r pipeline: start ===")
    run_r(life_table_derivatives_R, life_table_path, life_table_path) # compute fields like dx, sx, qx etc...
    run_r(generation_time_R, country_table_path, country_table_path) # calculation generation time
    log.log("=== r pipeline: done ===")
