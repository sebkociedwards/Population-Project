import os
from src.python import income_status
from src.python.helper import SETTINGS, OUT_PATH


def generate_country_table():
    income_status_df, path = income_status.generate_income_status_df()

    country_table_df = income_status_df # TODO temp

    path = os.path.join(OUT_PATH, "country_table.csv")
    country_table_df.to_csv(path, index=False)
    return path
