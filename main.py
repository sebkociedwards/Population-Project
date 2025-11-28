import os, subprocess, argparse, sys
from sys import stderr, stdout
from src.python.life_table import generate_life_table
from src.python.country_table import generate_country_table
from src.python.helper import DOWNLOAD_FOLDER as raw, OUTPUT_FOLDER as processed, R_PATH, SETTINGS
from src.python import log  
    

life_table_derivatives_R = "src/R/life_table_derivatives.R"
generation_time_R = "src/R/generation_time.R"
ne_felsenstein_R = "src/R/ne_felsenstein.R"
plots_Ne_T_by_group_R = "src/R/plots_Ne_T_by_group.R"

out_dir = "outputs"


def run_r(path: str, *args: str):
    version = SETTINGS["r_version"]

    # find correct OS to run the r from
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
        log.error(f"R script failed: {os.path.basename(path)} (exit {res.returncode}). [R stderr] {res.stderr.strip()}")


def env_contains_values():
    # check if .env has email and password and exists
    try:
        with open(".env") as f:
            for line in f:
                if line.strip().endswith("="):  
                    return False
        return True
    except:
        return False
    
    
if __name__ == "__main__":
    #debug
    import os
    log.log(f"Python is running from: {os.getcwd()}")
    log.log(f"ShinyPipeline.R exists here: {os.path.exists('ShinyPipeline.R')}")
    


     # if .env is not correct, generate
    if not env_contains_values():
        email = input("Enter your email (HMD/HFD): ")
        password = input("Enter your password (HMD/HFD): ")
        
        with open(".env", "w") as f:
            f.write(f"EMAIL={email}\n")
            f.write(f"PASSWORD={password}\n")
        
        # rerun the program
        os.execv(sys.executable, [sys.executable] + sys.argv)
        
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

    # generate data
    run_r(life_table_derivatives_R, life_table_path) # compute fields like dx, sx, qx etc...
    run_r(generation_time_R, life_table_path, country_table_path) # calculation generation time
    run_r(ne_felsenstein_R, life_table_path, country_table_path) # calculate Ne according to felsenstein
    run_r("src/R/mx_shape_metrics.R", life_table_path, country_table_path) #calculate mx with skew
    run_r("src/R/prr_calculation.R", life_table_path, country_table_path)
    # plot data; had to get rid of run r as r needs to keep running for r shiny
    
    log.log(f"SHINY_DATA_DIR is set to: {processed}")


    latest_data_directory = os.path.dirname(life_table_path)
    os.environ["SHINY_DATA_DIR"] = latest_data_directory
    log.log(f"SHINY_DATA_DIR is set to: {latest_data_directory}")
    import webbrowser #using Popen isntead of run; lets Rshiny keep running
    import time

    log.log("population project V1.0 starting...")
    shiny_process =subprocess.Popen(
        ["Rscript","ShinyPipeline.R"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1 #buffered line
    )

    time.sleep(5)
   
    if shiny_process.poll() is not None:
        log.error(f"Shiny crashed Exit code {shiny_process.returncode}")
        log.error(f"R stdout: {stdout}")
        log.error(f"R stderr: {stderr}")

    else:
        log.log("Shiny process is running!")
        webbrowser.open("http://127.0.0.1:7398")
        log.log("Press Ctrl=c in the treminal to stop the app")
        shiny_process.wait()

log.log("== r pipeline: done ==")
   

