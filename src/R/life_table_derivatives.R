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
df$dx <- NA
df$sx <- NA
df$px <- NA
df$qx <- NA
df$vx <- NA

groups <- split(seq_len(n), paste(df$ISO3, df$Year), sep=":")

for (g in groups) {
  n <- length(g)
  lx <- as.numeric(df$lx[g])
  mx <- as.numeric(df$mx[g])
  
  dx <- matrix(NA, n-1)
  sx <- matrix(NA, n - 1)
  px <- matrix(NA, n)
  qx <- matrix(NA, n)
  vx <- matrix(NA, n)
  
  # dx and sx
  for (i in 1:(n-1)) {
    # dx = 1 - l(x + 1) / l(x)
    dx[i] <- 1 - lx[i+1] / lx[i]
    
    # sx = 1 - d(x)
    sx[i] <- 1 - dx[i]
  }
  df$dx[g] <- dx 
  df$sx[g] <- sx
  
  # px (lxmx)
  # lxmx = lx * mx
  px <- lx * mx
  px_clean <- ifelse(is.na(px), 0, px)
  R0 <- sum(px_clean)
  df$px[g] <- px
  
  # qx
  px[is.na(px)] <- 0 # treat NA as 0 for sum
  n = length(px)
  
  for (i in 1:n) {
    # qx = sum(px[x>n])
    qx[i] <- sum(px[i:n])
  }
  df$qx[g] <- qx
  
  # vx
  vx <- qx * lx
  #for (i in 1:n) {
    # vx = q(x + 1)^2 / l(x + 1)^2
  #  vx[i] <- qx[i] / lx[i]
    #vx[i] <- qx[i] / (R0 * lx[i]) # normalised with R0
  #}
  df$vx[g] <- vx
}

# write csv
write.csv(df, path, row.names = FALSE)