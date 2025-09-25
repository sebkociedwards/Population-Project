import os, sys
from src.helper import get_datetimestamp, OUT_PATH


LOG_FILE = "log_file.log"

path = os.path.join(OUT_PATH, LOG_FILE)
start_time = None
end_time = None


def prepend_header():
    header = f"Logs begin at {start_time}, and end at {end_time}:\n"
    with open(path, "r") as f:
        content = f.read()
    with open(path, "w") as f:
        f.write(header + content)


def register_start_time(): start_time = get_datetimestamp()
def register_end_time(): 
    end_time = get_datetimestamp()
    prepend_header()


# write logs to info file and print to terminal
def write_log(level, message):
    line = f"[{get_datetimestamp()}] {level}: {message}"
    with open(path, "a") as f:
        f.write(line + "\n")
    print(line)


def log(message):  write_log("LOG", message)
def warn(message): write_log("WARN", message)
def error(message, path=None):
    if path is not None: write_log("ERROR", f"{message}\n{path}")
    else: write_log("ERROR", message)
    sys.exit()
