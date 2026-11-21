# Step 2: download every record matching "any invertebrate name x any state term"
# (title, abstract, journal, year, ...) and tag it with taxon groups, state blocks and
# the strict core definition. Run from the repository root:
#   source("scripts/02_fetch_records.R")
# Needs OPENALEX_MAILTO, OPENALEX_API_KEY and network access; ~16,000 records take a few minutes.
#
# Abstract text is publisher content: it goes to data/raw/ (not tracked by git).
# What is tracked is data/processed/records_meta.csv (no title, no abstract).
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R"); source("R/core.R"); source("R/outputs.R")
cfg <- read_config()

# OpenAlex requires a free API key to page past the first page of results.
if (!nzchar(oa_api_key()))
  stop("Set OPENALEX_API_KEY (free key: https://openalex.org/settings/api). ",
       "Add OPENALEX_API_KEY=your-key to ~/.Renviron and restart R.", call. = FALSE)

# One query per taxon group (the whole list of animal names would not fit in one request);
# a record found by several groups is kept once.
parts <- lapply(names(cfg$taxa), function(g) {
  message("== ", g)
  r <- fetch_records(cfg, build_filter(cfg, build_search(taxon_terms(cfg, g), all_state_terms(cfg))))
  api_n <- attr(r, "api_count")
  message(sprintf("   downloaded %d; OpenAlex reports %s", nrow(r), format(api_n)))
  if (!is.na(api_n) && nrow(r) != api_n)
    warning(g, ": downloaded ", nrow(r), " but OpenAlex reports ", api_n, "; do not use this file.")
  r$retrieved_by <- g
  r
})
all <- do.call(rbind, parts)
by <- tapply(all$retrieved_by, all$openalex_id, function(x) paste(sort(unique(x)), collapse = ";"))
rec <- all[!duplicated(all$openalex_id), ]
rec$retrieved_by <- unname(by[rec$openalex_id])
message(sprintf("%d records after removing duplicates across groups (%d before).", nrow(rec), nrow(all)))

message(sprintf("Records without abstract: %.1f%%", 100 * mean(is.na(rec$abstract))))
rec <- tag_records(rec, cfg)

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
saveRDS(rec, sprintf("data/raw/records_%s.rds", format(Sys.Date())))

write_records_outputs(rec, cfg)
message("Next: scripts/02b_recover_abstracts.R fills abstracts that OpenAlex does not return.")
