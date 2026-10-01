# Step 2: download every record matching "any invertebrate x any state term"
# (title, abstract, journal, year, ...) and tag it with taxon groups and state
# blocks. Run from the repository root:
#   source("scripts/02_fetch_records.R")
# Needs OPENALEX_MAILTO and network access; ~16,000 records take a few minutes.
#
# Abstract text is publisher content: it goes to data/raw/ (not tracked by git).
# What is tracked is data/processed/records_meta.csv (no title, no abstract).
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R")
cfg <- read_config()

search <- build_search(union_terms(cfg, names(cfg$taxa)), all_state_terms(cfg))
rec <- fetch_records(cfg, build_filter(cfg, search))
api_n <- attr(rec, "api_count")
message(sprintf("Downloaded %d records; OpenAlex reports %s for this query.", nrow(rec), format(api_n)))
if (!is.na(api_n) && nrow(rec) != api_n) warning("Downloaded and reported totals differ; do not use this file.")
if (anyDuplicated(rec$openalex_id)) warning("Duplicate OpenAlex IDs found.")

message(sprintf("Records without abstract: %.1f%%", 100 * mean(is.na(rec$abstract))))
rec <- tag_records(rec, cfg)

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
saveRDS(rec, sprintf("data/raw/records_%s.rds", format(Sys.Date())))

meta <- rec[, setdiff(names(rec), c("title", "abstract"))]
meta$has_abstract <- !is.na(rec$abstract)
meta$run_date <- format(Sys.Date())
utils::write.csv(meta, "data/processed/records_meta.csv", row.names = FALSE)

# Fidelity of the local tags against the API: for every taxon group x state block,
# records tagged locally vs the count OpenAlex returned in step 1 (all years).
counts <- utils::read.csv("data/processed/counts_by_year.csv")
fid <- do.call(rbind, lapply(names(cfg$taxa), function(g) do.call(rbind, lapply(names(cfg$states), function(b) {
  api <- sum(counts$n[counts$taxon_group == g & counts$state_block == b])
  loc <- sum(rec[[paste0("taxon_", g)]] & rec[[paste0("state_", b)]])
  data.frame(taxon_group = g, state_block = b, api = api, local = loc,
             ratio = ifelse(api > 0, round(loc / api, 3), NA))
}))))
utils::write.csv(fid, "data/processed/tagging_fidelity.csv", row.names = FALSE)
message("Local tags / API counts (1.000 = identical):")
print(summary(fid$ratio))
message("Cells where the ratio is outside 0.9-1.1:")
print(fid[!is.na(fid$ratio) & (fid$ratio < 0.9 | fid$ratio > 1.1), ])
