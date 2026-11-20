# Step 3: stratified sample of records for manual relevance labelling.
#   source("scripts/03_make_validation_sample.R")
# Reads the newest data/raw/records_*.rds written by step 2.
# Writes
#   data/raw/validation_sample.csv      title + abstract + empty label columns (NOT tracked)
#   data/validation/sample_ids.csv      IDs, strata and weights (tracked; no publisher text)
# Label the sample following docs/labeling_guide.md.
source("R/queries.R"); source("R/tagging.R"); source("R/sampling.R")
cfg <- read_config()

files <- sort(Sys.glob("data/raw/records_*.rds"))
if (length(files) == 0) stop("Run scripts/02_fetch_records.R first.")
rec <- readRDS(files[length(files)])
message("Using ", files[length(files)], " (", nrow(rec), " records)")

smp <- make_validation_sample(rec, cfg)
message(sprintf("Sample: %d records", nrow(smp)))
print(table(smp$stratum_block))

dir.create("data/validation", showWarnings = FALSE, recursive = TRUE)
ids <- smp[, c("openalex_id", "stratum_block", "primary_taxon", "stratum_N", "stratum_n", "weight")]
ids$seed <- cfg$sampling$seed
utils::write.csv(ids, "data/validation/sample_ids.csv", row.names = FALSE)

lab <- data.frame(
  row = seq_len(nrow(smp)), openalex_id = smp$openalex_id, year = smp$year,
  doi = smp$doi, journal = smp$source_name, title = smp$title,
  abstract = smp$abstract, abstract_source = smp$abstract_source,
  matched_state = smp$primary_state, matched_taxon = smp$primary_taxon,
  relevance = "", reason_if_0 = "", notes = "", stringsAsFactors = FALSE)
utils::write.csv(lab, "data/raw/validation_sample.csv", row.names = FALSE, na = "", fileEncoding = "UTF-8")
message("Open data/raw/validation_sample.csv and fill `relevance`, `reason_if_0`, `notes`.")
