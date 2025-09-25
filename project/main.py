from src import log
from src.hmd_hfd import generate_hmd_hfd_df
    
    
if __name__ == "__main__":
    log.register_start_time()

    generate_hmd_hfd_df()

    log.register_start_time()