# Step 4b: what the two core filters (config core.filters) would have done to the labelled sample.
#   source("scripts/04b_evaluate_core_rules.R")
# Needs step 2c done and data/raw/validation_sample.csv (your labels). The sample was drawn with the
# word pattern alone, so every labelled paper is in the table whether or not the filters keep it.
# Careful: these papers are the ones the filters were designed after, so the numbers are optimistic.
# The figure to publish comes from a fresh sample (another seed) drawn with the filters on.
source("R/queries.R"); source("R/records.R"); source("R/validation.R")
cfg <- read_config()
files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
rec <- readRDS(files[length(files)])
if (is.null(rec$pass_field)) stop("Run scripts/02c_fetch_topics.R first.", call. = FALSE)
lab <- read_labels("data/raw/validation_sample.csv")
ids <- utils::read.csv("data/validation/sample_ids.csv", stringsAsFactors = FALSE)
ev <- evaluate_core_rules(rec, lab, ids, names(cfg$core$states))
pct <- function(x) sprintf("%3.0f%%", 100 * x)
b <- ev$by_block
cat("\nPER VARIANT AND BLOCK (papers kept = estimated size of the block after the filter;\n  on topic = share of the kept papers that are on topic; on-topic kept = share of the on-topic papers of the unfiltered core still there)\n")
print(data.frame(variant = b$variant, block = b$block, papers_kept = round(b$papers_kept),
                 on_topic = pct(b$share_on_topic), on_topic_kept = pct(b$on_topic_kept)), row.names = FALSE)
cat("\nLABELLED PAPERS BY OPENALEX FIELD (how many were on topic)\n"); print(ev$by_field, row.names = FALSE)

# The labelled papers that were on topic and that the filters remove, to read them one by one.
raw <- utils::read.csv("data/raw/validation_sample.csv", stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
d <- merge(merge(lab[lab$status == "ok" & lab$relevance %in% c("1", "2"), c("openalex_id", "relevance")], ids[, c("openalex_id", "stratum_block")], by = "openalex_id"),
           rec[, c("openalex_id", "pass_field", "pass_subject", "topic_field", "animal_mentions", "animal_in_title")], by = "openalex_id")
d <- merge(d, raw[, c("openalex_id", "title")], by = "openalex_id")
lost <- d[!(d$pass_field & d$pass_subject), ]
cat(sprintf("\nON-TOPIC LABELLED PAPERS REMOVED BY THE FILTERS: %d of %d\n", nrow(lost), nrow(d)))
if (nrow(lost)) print(data.frame(block = lost$stratum_block, label = lost$relevance,
                                 removed_by = ifelse(!lost$pass_field & !lost$pass_subject, "field+subject", ifelse(!lost$pass_field, "field", "subject")),
                                 field = lost$topic_field, animal_mentions = lost$animal_mentions,
                                 title = substr(lost$title, 1, 90)), row.names = FALSE)
