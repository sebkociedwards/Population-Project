library(data.table)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("usage: Rscript <script_path.R> <life_table_path.csv> <country_table_path.csv>")
life_table_path <- args[1]
country_table_path <- args[2]

# === TIMING: Start ===
script_start <- Sys.time()
cat("=== Ne Pipeline Started ===\n")

# === TIMING: Read CSVs ===
read_start <- Sys.time()
cat("Reading CSVs...\n")
life <- fread(life_table_path)
country <- fread(country_table_path)
cat(sprintf("  CSV reading took: %.2f seconds\n", difftime(Sys.time(), read_start, units="secs")))
cat(sprintf("  Life table rows: %d\n", nrow(life)))
cat(sprintf("  Country table rows: %d\n", nrow(country)))

# === TIMING: Calculations ===
calc_start <- Sys.time()
cat("Calculating Ne for each country-year...\n")

# Set N1 constant
N1 <- 1000

# Calculate Ne for each group using data.table
Ne_results <- life[, {
  # Get the T value for this group from country table
  T_val <- country[ISO3 == .BY[[1]] & ISO3_suffix == .BY[[2]] & Year == .BY[[3]], T]
  
  # If no match found, return NA
  if (length(T_val) == 0 || is.na(T_val)) {
    list(N_sum = NA_real_, Ne = NA_real_, N_ratio = NA_real_)
  } else {
    # Calculate N_sum
    N_sum <- sum(N, na.rm = TRUE)
    
    # Calculate Ne numerator
    numerator <- N1 * T_val
    
    # Calculate Ne denominator
    # Need to exclude last row (no vx+1 for last age)
    n_rows <- .N
    if (n_rows > 1) {
      # Create indices for all but last row
      i <- 1:(n_rows - 1)
      
      # Check which rows have all finite values
      ok <- is.finite(lx[i]) & is.finite(sx[i]) & is.finite(dx[i]) & is.finite(vx[i + 1])
      
      # Calculate terms only for valid rows
      term <- lx[i][ok] * sx[i][ok] * dx[i][ok] * vx[i + 1][ok]
      denominator <- sum(term, na.rm = TRUE) + 1
    } else {
      denominator <- 1
    }
    
    Ne <- numerator / denominator
    N_ratio <- Ne / N_sum
    
    list(N_sum = N_sum, Ne = Ne, N_ratio = N_ratio)
  }
}, by = .(ISO3, ISO3_suffix, Year)]

cat(sprintf("  Calculations took: %.2f seconds\n", difftime(Sys.time(), calc_start, units="secs")))
cat(sprintf("  Calculated Ne for %d country-years\n", nrow(Ne_results)))

# === TIMING: Merge ===
merge_start <- Sys.time()
cat("Merging results with country table...\n")
out <- merge(country, Ne_results, by = c("ISO3", "ISO3_suffix", "Year"), all = TRUE)
setorder(out, ISO3, ISO3_suffix, Year)
cat(sprintf("  Merge took: %.2f seconds\n", difftime(Sys.time(), merge_start, units="secs")))

# === TIMING: Write ===
write_start <- Sys.time()
cat("Writing output CSV...\n")
fwrite(out, country_table_path)
cat(sprintf("  Writing took: %.2f seconds\n", difftime(Sys.time(), write_start, units="secs")))

# === TIMING: Total ===
total_time <- difftime(Sys.time(), script_start, units="secs")
cat(sprintf("\n=== Ne Pipeline Complete: %.2f seconds total ===\n", total_time))