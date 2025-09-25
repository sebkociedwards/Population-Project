from src import income_status
from src import log 


def generate_country_table():
    income_status_df = income_status.generate_income_status_df()