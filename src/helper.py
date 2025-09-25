from datetime import datetime
import json5, os
import pandas as pd

 
SETTINGS_FILE = "settings.json5"


# timestamp functions
def get_datetimestamp(): return datetime.now().strftime("%Y-%m-%d %H:%M:%S")
def get_timestamp(): return datetime.now().strftime("%H:%M:%S")


# initiate settings as global variable
with open(SETTINGS_FILE, "r") as f:
    SETTINGS = json5.load(f)


# find next avaible output data folder
i = 1
while True:
    candidate = os.path.join(SETTINGS["output_folder"], f"data{i}")
    if os.path.isdir(candidate):
        i += 1
    else:
        os.makedirs(candidate, exist_ok=True)
        OUT_PATH =  candidate
        break