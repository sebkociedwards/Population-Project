args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("usage: Rscript <script_path.R> <path.csv>")
path <- args[1]

# read csv
df <- read.csv(path, header = TRUE)

# require these columns
required <- c("ISO3", "Year", "Age", "lx", "mx")
missing <- setdiff(required, names(df))
if (length(missing) > 0) {
  stop("missing required columns: ", paste(missing, collapse = ", "))
}

# initialise
n <- nrow(df)

# Initialize all required columns with correct length
df$dx <- rep(NA, n)
df$N <- rep(NA, n)
df$sx <- rep(NA, n)
df$lxmx_STAND <- rep(NA, n)
df$vx <- rep(NA, n)
df$lxmx_STAND_SUM_qx <- rep(NA, n)
df$lxmx <- rep(NA, n)
df$mx_ADJ <- rep(NA, n)

# Calculate and store N for all rows 
df$N <- df$lx * 1000 

# Create groups using ISO3, ISO3_suffix, AND Year
groups <- split(seq_len(n), paste(df$ISO3, df$ISO3_suffix, df$Year, sep=":"))

# Diagnostic - see what groups we have
cat("Number of groups:", length(groups), "\n")
for (group_name in head(names(groups), 3)) {
  g <- groups[[group_name]]
  cat("Group:", group_name, "has", length(g), "rows\n")
}

# Process each group
for (group_name in names(groups)) {
  g <- groups[[group_name]]
  n_group <- length(g)
  
  # Skip if group is too small
  if (n_group < 2) {
    cat("Skipping group", group_name, "- too small\n")
    next
  }
  
  lx <- as.numeric(df$lx[g])
  mx <- as.numeric(df$mx[g])
 
  # Initialize vectors with correct length
  dx <- rep(NA, n_group - 1)
  sx <- rep(NA, n_group - 1)
  lxmx_raw <- rep(NA, n_group)
  lxmx <- rep(NA, n_group)
  lxmx_STAND <- rep(NA, n_group)
  mx_ADJ <- rep(NA, n_group)
  lxmx_STAND_SUM_qx <- rep(NA, n_group)
  vx <- rep(NA, n_group - 1)

  # dx and sx (only for n_group - 1 elements)
  for (i in 1:(n_group - 1)) {
    dx[i] <- 1 - lx[i+1] / lx[i]
    sx[i] <- 1 - dx[i]
  }
  
  # CRITICAL: Only assign to the first (n_group - 1) positions
  df$dx[g[1:(n_group-1)]] <- dx 
  df$sx[g[1:(n_group-1)]] <- sx
  
  # Andy correction: lxmx calculations
  lxmx_raw <- lx * mx
  lxmx <- ifelse(is.na(lxmx_raw), 0, lxmx_raw)
  lxmx_SUM <- sum(lxmx)
  lxmx_STAND <- lxmx / lxmx_SUM
  mx_ADJ <- lxmx_STAND / lx
  
  df$lxmx[g] <- lxmx
  df$mx_ADJ[g] <- mx_ADJ
  df$lxmx_STAND[g] <- lxmx_STAND

  # Calculate cumulative sum
  for (i in 1:n_group) {
    lxmx_STAND_SUM_qx[i] <- sum(lxmx_STAND[i:n_group])
  }
  df$lxmx_STAND_SUM_qx[g] <- lxmx_STAND_SUM_qx

  # vx (only for n_group - 1 elements)
  for (i in 1:(n_group - 1)) {
    vx[i] <- lxmx_STAND_SUM_qx[i+1]^2 / lx[i+1]^2
  }
  df$vx[g[1:(n_group-1)]] <- vx
}

# write csv
write.csv(df, path, row.names = FALSE)