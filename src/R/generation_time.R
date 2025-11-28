library(data.table)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("usage: Rscript <script_path.R> <life_table_path.csv> <country_table_path.csv>")
life_table_path <- args[1]
country_table_path <- args[2]

# === TIMING: Start ===
script_start <- Sys.time()
cat("=== Generation Time Pipeline Started ===\n")

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
cat("Calculating generation time (T) for each country-year...\n")

# Calculate T for each group using data.table
T_results <- life[, {
  # Calculate T = sum(x * lx * mx) / sum(lx * mx)
  numerator <- sum(Age * lx * mx, na.rm = TRUE)
  denominator <- sum(lx * mx, na.rm = TRUE)
  
  if (denominator == 0 || is.na(denominator)) {
    T_val <- NA_real_
  } else {
    T_val <- numerator / denominator
  }
  
  list(T = T_val)
}, by = .(ISO3, ISO3_suffix, Year)]

cat(sprintf("  Calculations took: %.2f seconds\n", difftime(Sys.time(), calc_start, units="secs")))
cat(sprintf("  Calculated T for %d country-years\n", nrow(T_results)))

# === TIMING: Merge ===
merge_start <- Sys.time()
cat("Merging results with country table...\n")
out <- merge(country, T_results, by = c("ISO3", "ISO3_suffix", "Year"), all.x = TRUE)
setorder(out, ISO3, ISO3_suffix, Year)
cat(sprintf("  Merge took: %.2f seconds\n", difftime(Sys.time(), merge_start, units="secs")))

# === TIMING: Write ===
write_start <- Sys.time()
cat("Writing output CSV...\n")
fwrite(out, country_table_path)
cat(sprintf("  Writing took: %.2f seconds\n", difftime(Sys.time(), write_start, units="secs")))

# === TIMING: Total ===
total_time <- difftime(Sys.time(), script_start, units="secs")
cat(sprintf("\n=== Generation Time Pipeline Complete: %.2f seconds total ===\n", total_time))