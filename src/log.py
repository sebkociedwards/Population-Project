import os, sys
from src.helper import get_datetimestamp, OUT_PATH


LOG_FILE = "log_file.log"
path = os.path.join(OUT_PATH, LOG_FILE)


# write logs to info file and print to terminal
def write_log(level, message):
    line = f"[{get_datetimestamp()}] {level}: {message}"
    with open(path, "a") as f:
        f.write(line + "\n")
    print(line)


def log(message):  write_log("LOG", message)
def warn(message): write_log("WARNING", message)
def error(message, path=None):
    if path is not None: write_log("ERROR", f"{message}\n{path}")
    else: write_log("ERROR", message)
    sys.exit()
