import os
import pandas as pd
from src.python.helper import OUT_PATH, DOWNLOAD_FOLDER, SETTINGS
from src.python import log


# Path to hunter-gatherer data directory
HG_DATA_DIR = os.path.join(DOWNLOAD_FOLDER, "HG")


def load_hg_data(file_path: str) -> pd.DataFrame:
    """
    Load hunter-gatherer data from Excel or CSV file.
    Expected format: Age, lx, mx columns
    """
    # Check file extension
    file_ext = os.path.splitext(file_path)[1].lower()
    
    if file_ext == '.csv':
        # Read CSV
        df = pd.read_csv(file_path)
    elif file_ext in ['.xlsx', '.xls']:
        # Read Excel - first sheet only
        df = pd.read_excel(file_path, sheet_name=0)
    else:
        log.error(f"Unsupported file type: {file_ext}")
        return pd.DataFrame()
    
    # Rename the first column to 'Age' if it's unnamed
    if 'Unnamed: 0' in df.columns:
        df.rename(columns={'Unnamed: 0': 'Age'}, inplace=True)
    
    # Clean the data: remove rows with all NaN values
    df = df.dropna(how='all')
    
    # Clean column names (strip whitespace)
    df.columns = df.columns.str.strip()
    
    # Ensure Age column exists
    if 'Age' not in df.columns:
        log.error(f"No 'Age' column found in {os.path.basename(file_path)}")
        return pd.DataFrame()
    
    # Convert Age to numeric, replacing any non-numeric values with NaN
    df['Age'] = pd.to_numeric(df['Age'], errors='coerce')
    
    # Remove rows where Age is NaN (these are invalid rows)
    df = df.dropna(subset=['Age'])
    
    # Convert lx and mx to numeric as well
    df['lx'] = pd.to_numeric(df['lx'], errors='coerce')
    df['mx'] = pd.to_numeric(df['mx'], errors='coerce')
    
    # Fill any remaining NaN values in lx/mx with 0
    df['lx'] = df['lx'].fillna(0)
    df['mx'] = df['mx'].fillna(0)
    
    log.log(f"loaded hunter-gatherer data into memory: {os.path.basename(file_path)}")
    return df


def format_hg_data(df: pd.DataFrame, population_code: str, population_name: str) -> pd.DataFrame:
    """
    Format hunter-gatherer data to match HMD/HFD structure.
    
    Args:
        df: DataFrame with Age, lx, mx columns
        population_code: 3-letter code (e.g., 'ACH' for Ache)
        population_name: Full population name (e.g., 'Ache')
    
    Returns:
        Formatted DataFrame matching life_table structure
    """
    formatted = df.copy()
    
    # Ensure Age is integer (safe conversion now that blanks are removed)
    formatted['Age'] = formatted['Age'].astype(int)
    
    # Add identifying columns
    formatted['ISO3'] = population_code
    formatted['ISO3_suffix'] = 'HG'  # All hunter-gatherers get 'HG' suffix
    formatted['Year'] = 1980  # Placeholder year for HG populations
    
    # Verify lx starts at 1.0 (with tolerance for floating point)
    lx_at_zero = formatted.loc[formatted['Age'] == 0, 'lx'].values
    if len(lx_at_zero) > 0:
        lx_start = lx_at_zero[0]
        if not (0.99 <= lx_start <= 1.01):
            log.warn(f"{population_name}: lx at age 0 is {lx_start:.4f}, normalizing to 1.0")
            formatted['lx'] = formatted['lx'] / lx_start
        else:
            log.log(f"{population_name}: lx at age 0 = {lx_start:.4f} OK")
    else:
        log.warn(f"{population_name}: No data at age 0!")
    
    # Check data quality
    if formatted['lx'].isna().any():
        log.warn(f"{population_name}: Contains NA values in lx")
    if formatted['mx'].isna().any():
        log.warn(f"{population_name}: Contains NA values in mx")
    
    # Filter age range based on settings
    formatted = formatted[
        (formatted['Age'] >= SETTINGS['min_age']) & 
        (formatted['Age'] <= SETTINGS['max_age'])
    ]
    
    # Reorder columns to match life_table structure
    # ONLY include Age, lx, mx - R will calculate the rest
    columns_order = ['ISO3', 'ISO3_suffix', 'Year', 'Age', 'lx', 'mx']
    formatted = formatted[columns_order]
    
    log.log(f"formatted {population_name} data: {len(formatted)} rows")
    return formatted


def generate_hg_df() -> pd.DataFrame:
    """
    Generate formatted hunter-gatherer DataFrame.
    Combines all HG populations into single DataFrame.
    
    Supports both.csv files 
    """
    
    # Dictionary of HG populations
    # Format: 'filename': ('ISO3_code', 'population_name')
    # You can use EITHER .xlsx OR .csv files - just match your filename!
    hg_populations = {
        'Ache - Hurtado & Hill.csv': ('ACH', 'Ache'),
        'Hadza - Blurton Jones data.csv': ('HDZ', 'Hadza'),
        '!Kung - data.csv': ('KUN', '!Kung')
    }
    
    all_hg_data = []
    
    for filename, (code, name) in hg_populations.items():
        # Check if file exists in HG data directory
        file_path = os.path.join(HG_DATA_DIR, filename)
        
        if os.path.exists(file_path):
            log.log(f"processing {name} from {filename}...")
            
            try:
                # Load and format data
                raw_df = load_hg_data(file_path)
                
                if raw_df.empty:
                    log.warn(f"No valid data loaded from {filename}")
                    continue
                
                formatted_df = format_hg_data(raw_df, code, name)
                all_hg_data.append(formatted_df)
                
            except Exception as e:
                log.error(f"Error processing {filename}: {str(e)}")
                continue
        else:
            log.warn(f"file not found: {filename}, skipping {name}")
    
    if not all_hg_data:
        log.error("no hunter-gatherer data files found")
        return pd.DataFrame()
    
    # Combine all HG populations
    hg_df = pd.concat(all_hg_data, ignore_index=True)
    
    # Save to output
    path = os.path.join(OUT_PATH, "hg.csv")
    hg_df.to_csv(path, index=False)
    
    log.log(f"successfully generated HG dataset: {path}")
    log.log(f"  Total populations added: {len(hg_populations)}")
    log.log(f"  Total rows: {len(hg_df)}")
    
    return hg_df