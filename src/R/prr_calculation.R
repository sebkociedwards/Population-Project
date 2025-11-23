# prr_calculation_v2.R
# Calculate Postreproductive Representation (PrR) following Levitis Appendix 3
# Key fix: Use mx directly (NOT lx*mx) for B and M calculation
# Use Tx (person-years) calculation for PrR

library(data.table)

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Usage: Rscript prr_calculation.R <life_table_path.csv> <country_table_path.csv>")
}
life_table_path <- args[1]
country_table_path <- args[2]

# === START ===
script_start <- Sys.time()
cat("=== PrR Calculation Pipeline (v2 - Levitis Method) ===\n\n")

# === READ DATA ===
cat("1. Reading CSVs...\n")
if (!file.exists(life_table_path)) stop(paste("Life table not found:", life_table_path))
if (!file.exists(country_table_path)) stop(paste("Country table not found:", country_table_path))

life <- fread(life_table_path)
country <- fread(country_table_path)

cat(sprintf("   ✓ Life table: %d rows, %d columns\n", nrow(life), ncol(life)))
cat(sprintf("   ✓ Country table: %d rows, %d columns\n", nrow(country), ncol(country)))

# Check required columns
required_cols <- c("ISO3", "Year", "Age", "lx", "mx")
missing <- setdiff(required_cols, names(life))
if (length(missing) > 0) {
  stop(paste("Missing columns in life_table:", paste(missing, collapse=", ")))
}

# Add ISO3_suffix if missing
if (!"ISO3_suffix" %in% names(life)) {
  cat("   ⚠ Adding ISO3_suffix column to life_table\n")
  life[, ISO3_suffix := ""]
}
if (!"ISO3_suffix" %in% names(country)) {
  cat("   ⚠ Adding ISO3_suffix column to country_table\n")
  country[, ISO3_suffix := ""]
}

# === DATA QUALITY CHECKS ===
cat("\n2. Data quality checks...\n")
cat(sprintf("   mx NAs: %d (%.1f%%) - will be replaced with 0\n", 
            sum(is.na(life$mx)), 100*mean(is.na(life$mx))))
cat(sprintf("   lx NAs: %d (%.1f%%) - will be replaced with 0\n",
            sum(is.na(life$lx)), 100*mean(is.na(life$lx))))

# Replace NAs
life[is.na(mx), mx := 0]
life[is.na(lx), lx := 0]

# Show sample
cat("\n   Sample data:\n")
print(head(life[, .(ISO3, ISO3_suffix, Year, Age, lx, mx)], 10))

# === CALCULATE B, M, Z, PrR ===
cat("\n3. Calculating B, M, Z, and PrR...\n")
calc_start <- Sys.time()

prr_results <- life[, {
  # Sort by age
  setorder(.SD, Age)
  
  lx_vec <- lx
  mx_vec <- mx
  age_vec <- Age
  n <- length(lx_vec)
  
  # Initialize results
  B <- NA_real_
  M <- NA_real_
  Z <- NA_real_
  T_B <- NA_real_
  T_M <- NA_real_
  PrR <- NA_real_
  prop_survive_to_B <- NA_real_
  prop_survive_to_M <- NA_real_
  
  # === KEY FIX: Following Levitis Appendix 3 Lines 53-58 ===
  # Use cumsum(mx) NOT cumsum(lx*mx) for B and M
  # "Calculate age B as the minimum age at which sum of mx from 0 to x 
  #  is more than 0.05 * sum of mx from 0 to infinity"
  
  total_mx <- sum(mx_vec)
  
  if (total_mx > 0) {
    cum_mx <- cumsum(mx_vec)
    
    # Age B: where cumsum(mx) >= 5% of total mx
    B_idx <- which(cum_mx >= 0.05 * total_mx)[1]
    if (!is.na(B_idx)) {
      B <- age_vec[B_idx]
    }
    
    # Age M: where cumsum(mx) >= 95% of total mx
    M_idx <- which(cum_mx >= 0.95 * total_mx)[1]
    if (!is.na(M_idx)) {
      M <- age_vec[M_idx]
    }
  }
  
  # === Age Z: Based on survival ===
  total_lx <- sum(lx_vec)
  if (total_lx > 0) {
    cum_lx <- cumsum(lx_vec)
    Z_idx <- which(cum_lx >= 0.95 * total_lx)[1]
    if (!is.na(Z_idx)) {
      Z <- age_vec[Z_idx]
    }
  }
  
  # === Calculate Tx (person-years) following Levitis Lines 63-74 ===
  if (!is.na(B) && !is.na(M) && n > 1) {
    # Calculate dx (deaths in each interval)
    lx_shifted <- c(lx_vec[-1], 0)
    dx_vec <- lx_vec - lx_shifted
    
    # Calculate Lx (person-years lived in each age interval)
    # Lx = lx[x+1] + 0.5 * dx
    Lx <- lx_shifted + (0.5 * dx_vec)
    
    # Calculate Tx (cumulative person-years from age x onward)
    Tx <- numeric(n)
    for (i in 1:n) {
      Tx[i] <- sum(Lx[i:n])
    }
    
    # Get indices for B and M
    B_idx <- which(age_vec == B)[1]
    M_idx <- which(age_vec == M)[1]
    
    if (!is.na(B_idx) && !is.na(M_idx) && B_idx <= n && M_idx <= n) {
      T_B <- Tx[B_idx]
      T_M <- Tx[M_idx]
      
      # PrR = T(M) / T(B) following Levitis Line 74
      if (T_B > 0) {
        PrR <- T_M / T_B
      }
      
      # Survival proportions at B and M
      prop_survive_to_B <- lx_vec[B_idx]
      prop_survive_to_M <- lx_vec[M_idx]
    }
  }
  
  list(
    B = B,
    M = M,
    Z = Z,
    T_B = T_B,
    T_M = T_M,
    PrR = PrR,
    prop_survive_to_B = prop_survive_to_B,
    prop_survive_to_M = prop_survive_to_M
  )
}, by = .(ISO3, ISO3_suffix, Year)]

calc_time <- difftime(Sys.time(), calc_start, units="secs")
cat(sprintf("   ✓ Calculations took: %.2f seconds\n", calc_time))

# === DIAGNOSTICS ===
cat("\n4. Results summary...\n")
n_groups <- nrow(prr_results)
n_valid_B <- sum(!is.na(prr_results$B))
n_valid_M <- sum(!is.na(prr_results$M))
n_valid_Z <- sum(!is.na(prr_results$Z))
n_valid_PrR <- sum(!is.na(prr_results$PrR))

cat(sprintf("   Total country-years: %d\n", n_groups))
cat(sprintf("   Valid B: %d/%d (%.1f%%)\n", n_valid_B, n_groups, 100*n_valid_B/n_groups))
cat(sprintf("   Valid M: %d/%d (%.1f%%)\n", n_valid_M, n_groups, 100*n_valid_M/n_groups))
cat(sprintf("   Valid Z: %d/%d (%.1f%%)\n", n_valid_Z, n_groups, 100*n_valid_Z/n_groups))
cat(sprintf("   Valid PrR: %d/%d (%.1f%%)\n", n_valid_PrR, n_groups, 100*n_valid_PrR/n_groups))

if (n_valid_PrR > 0) {
  cat("\n   Summary statistics (valid values only):\n")
  cat(sprintf("   B: %.1f years (range: %.0f-%.0f)\n", 
              mean(prr_results$B, na.rm=TRUE),
              min(prr_results$B, na.rm=TRUE),
              max(prr_results$B, na.rm=TRUE)))
  cat(sprintf("   M: %.1f years (range: %.0f-%.0f)\n",
              mean(prr_results$M, na.rm=TRUE),
              min(prr_results$M, na.rm=TRUE),
              max(prr_results$M, na.rm=TRUE)))
  cat(sprintf("   Z: %.1f years (range: %.0f-%.0f)\n",
              mean(prr_results$Z, na.rm=TRUE),
              min(prr_results$Z, na.rm=TRUE),
              max(prr_results$Z, na.rm=TRUE)))
  cat(sprintf("   PrR: %.3f (%.1f%% post-fertile, range: %.3f-%.3f)\n",
              mean(prr_results$PrR, na.rm=TRUE),
              100*mean(prr_results$PrR, na.rm=TRUE),
              min(prr_results$PrR, na.rm=TRUE),
              max(prr_results$PrR, na.rm=TRUE)))
  
  cat("\n   Sample of results:\n")
  print(head(prr_results[!is.na(PrR)][order(-PrR), .(ISO3, Year, B, M, Z, PrR)], 10))
} else {
  cat("\n   ⚠ WARNING: No valid PrR values calculated!\n")
  cat("   This usually means mx is all zeros or NAs.\n")
  cat("   Check that fertility data (mx) was properly loaded.\n")
}

# === MERGE ===
cat("\n5. Merging with country table...\n")
cat(sprintf("   Before: country table has %d columns\n", ncol(country)))

out <- merge(country, prr_results, by = c("ISO3", "ISO3_suffix", "Year"), all.x = TRUE)
setorder(out, ISO3, ISO3_suffix, Year)

new_cols <- setdiff(names(out), names(country))
cat(sprintf("   After: country table has %d columns\n", ncol(out)))
cat(sprintf("   Added: %s\n", paste(new_cols, collapse=", ")))

# === SAVE ===
cat("\n6. Saving output...\n")
fwrite(out, country_table_path)
cat(sprintf("   ✓ Saved to: %s\n", country_table_path))

# === DONE ===
total_time <- difftime(Sys.time(), script_start, units="secs")
cat(sprintf("\n=== Pipeline Complete: %.2f seconds ===\n", total_time))

if (n_valid_PrR == 0) {
  cat("\n===WARNING===\n")
  cat("No PrR values were calculated!\n")
  cat("This means mx (fertility) data is missing or all zero.\n")
  cat("Check your HFD data loading and merging process.\n")
}