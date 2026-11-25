# Step 3b: a FRESH validation sample, drawn after the core filters were added (config core.filters).
#   source("scripts/03b_make_fresh_validation_sample.R")
# Differences from step 3: another seed (sampling_round2.seed), the papers of round 1 are left out
# (the filters were designed after reading their labels, so they cannot test the filters), and the
# strata use the current core. The estimate then describes the papers NOT drawn in round 1.
# Writes data/raw/validation_sample_2.csv (NOT tracked) and data/validation/sample_ids_2.csv (tracked).
# Label it with docs/labeling_guide.md, then read it with
#   Sys.setenv(VALIDATION_ROUND = "_2"); source("scripts/04_read_labels.R")
source("R/queries.R"); source("R/tagging.R"); source("R/core.R"); source("R/sampling.R")
cfg <- read_config()
r2 <- cfg$sampling_round2
cfg$sampling$seed <- r2$seed

files <- sort(Sys.glob("data/raw/records_*.rds"))
if (length(files) == 0) stop("Run scripts/02_fetch_records.R first.")
rec <- readRDS(files[length(files)])
if (is.null(rec$keep_welfare)) stop("Run scripts/02c_fetch_topics.R first: the records carry the old core.", call. = FALSE)
message("Using ", files[length(files)], " (", nrow(rec), " records)")
rec <- exclude_sampled(rec, r2$exclude_ids)
message(nrow(rec), " records left after removing the papers of round 1")

smp <- make_validation_sample(rec, cfg)
message(sprintf("Sample: %d records", nrow(smp)))
print(table(smp$stratum_block))

ids <- smp[, c("openalex_id", "stratum_block", "primary_taxon", "stratum_N", "stratum_n", "weight")]
ids$seed <- r2$seed
utils::write.csv(ids, sprintf("data/validation/sample_ids%s.csv", r2$suffix), row.names = FALSE)
lab <- data.frame(
  row = seq_len(nrow(smp)), openalex_id = smp$openalex_id, year = smp$year,
  doi = smp$doi, journal = smp$source_name, title = smp$title,
  abstract = smp$abstract, abstract_source = smp$abstract_source,
  relevance = "", reason_if_0 = "", notes = "", stringsAsFactors = FALSE)
utils::write.csv(lab, sprintf("data/raw/validation_sample%s.csv", r2$suffix), row.names = FALSE, na = "", fileEncoding = "UTF-8")
message(sprintf("Open data/raw/validation_sample%s.csv and fill `relevance`, `reason_if_0`, `notes`.", r2$suffix))
