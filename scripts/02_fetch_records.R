# Step 2: download every record matching "any invertebrate x any state term"
# (title, abstract, journal, year, ...) and tag it with taxon groups and state
# blocks. Run from the repository root:
#   source("scripts/02_fetch_records.R")
# Needs OPENALEX_MAILTO, OPENALEX_API_KEY and network access; ~16,000 records take a few minutes.
#
# Abstract text is publisher content: it goes to data/raw/ (not tracked by git).
# What is tracked is data/processed/records_meta.csv (no title, no abstract).
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R"); source("R/outputs.R")
cfg <- read_config()

# OpenAlex requires a free API key to page past the first page of results.
if (!nzchar(oa_api_key()))
  stop("Set OPENALEX_API_KEY (free key: https://openalex.org/settings/api). ",
       "Add OPENALEX_API_KEY=your-key to ~/.Renviron and restart R.", call. = FALSE)

search <- build_search(union_terms(cfg, names(cfg$taxa)), all_state_terms(cfg))
rec <- fetch_records(cfg, build_filter(cfg, search))
api_n <- attr(rec, "api_count")
message(sprintf("Downloaded %d records; OpenAlex reports %s for this query.", nrow(rec), format(api_n)))
if (!is.na(api_n) && nrow(rec) != api_n) warning("Downloaded and reported totals differ; do not use this file.")
if (anyDuplicated(rec$openalex_id)) warning("Duplicate OpenAlex IDs found.")

message(sprintf("Records without abstract: %.1f%%", 100 * mean(is.na(rec$abstract))))
rec <- tag_records(rec, cfg)

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
saveRDS(rec, sprintf("data/raw/records_%s.rds", format(Sys.Date())))

write_records_outputs(rec, cfg)
message("Next: scripts/02b_recover_abstracts.R fills abstracts that OpenAlex does not return.")
