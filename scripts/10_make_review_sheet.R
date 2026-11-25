# Step 10: the sheet for reviewing by hand ALL the core papers of the latest year.
#   source("scripts/10_make_review_sheet.R")
# Writes data/raw/review_<year>.csv (title + abstract + empty label columns; NOT tracked: it holds abstracts).
# Make one copy per reviewer, fill it following docs/labeling_guide.md and save it as
#   data/raw/review_<year>_<name>.csv        (for example review_2026_solimary.csv, review_2026_iwrs1.csv)
# then run scripts/11_read_review.R.
source("R/queries.R"); source("R/validation.R"); source("R/review.R")
files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
if (length(files) == 0) stop("Run scripts/02_fetch_records.R first.")
rec <- readRDS(files[length(files)])
year <- max(rec$year[rec$core_any])
sheet <- make_review_sheet(rec, year)
path <- sprintf("data/raw/review_%s.csv", year)
utils::write.csv(sheet, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
message(sprintf("%d core papers of %s, %d without abstract.", nrow(sheet), year, sum(is.na(sheet$abstract))))
message("Wrote ", path, ". Give each reviewer a copy and ask for relevance (2, 1, 0 or ?), reason_if_0 and notes.")
