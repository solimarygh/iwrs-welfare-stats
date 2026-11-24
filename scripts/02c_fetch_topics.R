# Step 2c: adds the OpenAlex topic (field, subfield, domain) to the records already downloaded
# and re-tags them, because the core definition now filters by field (config core.filters).
# Run after step 2b:
#   source("scripts/02c_fetch_topics.R")
# About 21,000 ids, 100 per call: a few minutes. Records downloaded by a newer step 2 already
# carry the topic and are skipped.
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R"); source("R/core.R"); source("R/outputs.R")
cfg <- read_config()
if (!nzchar(oa_api_key())) stop("Set OPENALEX_API_KEY in ~/.Renviron (see README).", call. = FALSE)

files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
if (length(files) == 0) stop("Run scripts/02_fetch_records.R first.")
path <- files[length(files)]
rec <- readRDS(path)
message("Using ", path, " (", nrow(rec), " records)")

if (is.null(rec$topic_field)) {
  tp <- fetch_topics(cfg, rec$openalex_id)
  message(sprintf("Topics returned for %d of %d records", nrow(tp), nrow(rec)))
  rec <- merge(rec, tp, by = "openalex_id", all.x = TRUE, sort = FALSE)
  rec <- rec[order(match(rec$openalex_id, readRDS(path)$openalex_id)), ]
}
message("Field of the records (top 12):"); print(head(sort(table(rec$topic_field, useNA = "ifany"), decreasing = TRUE), 12))

rec <- tag_records(rec, cfg)
saveRDS(rec, path)
write_records_outputs(rec, cfg)
message("Core papers: ", sum(rec$core_any), " (of ", sum(rec$pattern_sentience | rec$pattern_affect_emotion |
        rec$pattern_consciousness | rec$pattern_welfare | rec$pattern_nociception_pain), " matching the word pattern)")
message("Next: scripts/04b_evaluate_core_rules.R shows what the filters do to your labelled sample.")
