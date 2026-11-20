# Step 5: exports the processed counts to site/data.js, the file the static site reads.
#   source("scripts/05_build_site_data.R")
# Open site/index.html in a browser afterwards (double-click works; no server needed).
source("R/site.R")

counts <- utils::read.csv("data/processed/counts_by_year.csv", stringsAsFactors = FALSE)
snaps <- sort(list.files("data/snapshots", "^queries_.*\\.json$", full.names = TRUE))
if (length(snaps) == 0) stop("No query snapshot found; run scripts/01_publication_counts.R first.")
run_date <- jsonlite::read_json(snaps[length(snaps)])$run_date

write_site_data(build_site_data(counts, run_date))
message("Wrote site/data.js (counts of ", run_date, ")")
