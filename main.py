from src import log
from src.hmd_hfd import generate_hmd_hfd_df
from src.income_status import generate_income_status_df
    
    
if __name__ == "__main__":
    generate_hmd_hfd_df()
    generate_income_status_df()