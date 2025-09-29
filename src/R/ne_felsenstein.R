args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("usage: Rscript <script_path.R> <life_table_path.csv> <country_table_path.csv>")
life_table_path <- args[1]
country_table_path <- args[2]

# read csv
life <- read.csv(life_table_path, header = TRUE)
country <- read.csv(country_table_path, header = TRUE)

# split into (country, year) groups
groups <- split(seq_len(nrow(life)), interaction(life$ISO3, life$ISO3_suffix, life$Year, drop = TRUE))

ne_list <- lapply(groups, function(g) {
  iso <- life$ISO3[g[1]]
  suffix <- life$ISO3_suffix[g[1]]
  year <- life$Year[g[1]]

  # index N1 where age == 1
  # i <- which(life$Age[g] == 1)
  # N1 <- life$K[g][i[1]]
  N1 <- 1 # relative N1 until we have age-1 census

  # T from country table for the same ISO3, suffix and year
  match_row <- which(country$ISO3 == iso & country$ISO3_suffix == suffix & country$Year == year)
  G <- country$G[match_row[1]]

  lx <- life$lx[g]
  sx <- life$sx[g]
  dx <- life$dx[g]
  vx <- life$vx[g]

  # Ne = (N1 * T) / sum(lx * sx * dx * v(x + 1)^2)
  numerator <- N1 * G

  # compute terms, keeping only rows where every factor is finite
  i <- seq_len(length(g) - 1L)
  ok <- is.finite(lx[i]) & is.finite(sx[i]) & is.finite(dx[i]) & is.finite(vx[i + 1])
  term <- lx[ok] * sx[ok] * dx[ok] * vx[i + 1][ok]^2
  denominator <- sum(term, na.rm = TRUE) # should have 1 + sum, but doesn't seem to work

  Ne <- numerator / denominator

  data.frame(
    ISO3 = iso,
    ISO3_suffix = suffix,
    Year = year,
    Ne = Ne,
    stringsAsFactors = FALSE
  )
})
Ne_df <- do.call(rbind, ne_list)

# merge into country table
out <- merge(country, Ne_df, by = c("ISO3", "ISO3_suffix", "Year"), all = TRUE)
out <- out[order(out$ISO3, out$ISO3_suffix, out$Year), ]

# write csv
write.csv(out, country_table_path, row.names = FALSE)
