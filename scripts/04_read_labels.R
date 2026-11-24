# Step 4: reads your labels and estimates how many of the papers are really on topic, per block.
#   source("scripts/04_read_labels.R")
# Input: the labelled file data/raw/validation_sample.csv (columns relevance, reason_if_0) and
# data/validation/sample_ids.csv (which stratum each paper came from).
# Output: data/validation/labels.csv (ids and labels only, no titles or abstracts: safe to commit),
# data/processed/validation_summary.csv, and a summary in the console.
source("R/queries.R"); source("R/records.R"); source("R/validation.R")
cfg <- read_config()

lab <- read_labels("data/raw/validation_sample.csv")
ids <- utils::read.csv("data/validation/sample_ids.csv", stringsAsFactors = FALSE)
message(sprintf("%d rows: %d labelled, %d empty, %d with a value that is not 2, 1, 0 or ?",
                nrow(lab), sum(lab$status == "ok"), sum(lab$status == "unlabeled"), sum(lab$status == "invalid")))
if (any(lab$status == "invalid")) { message("Fix these values (row number in the file, header = 1):"); print(which(lab$status == "invalid") + 1) }
if (!any(lab$status == "ok")) stop("No labels yet: fill the column `relevance` of data/raw/validation_sample.csv.", call. = FALSE)
if (any(lab$status == "unlabeled")) message("Unlabelled rows are left out of the estimates (", sum(lab$status == "unlabeled"), ").")

dir.create("data/validation", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(lab[lab$status == "ok", c("openalex_id", "relevance", "reason_if_0")], "data/validation/labels.csv", row.names = FALSE)

est <- estimate_precision(lab, ids)
pct <- function(x) sprintf("%4.0f%%", 100 * x)
cat("\nPER BLOCK (share of the papers of each stratum that are on topic; 95% interval in brackets)\n")
print(data.frame(block = est$block, papers = est$N, labelled = est$labelled, `?` = est$unsure,
                 core = sprintf("%s [%s-%s]", pct(est$core_share), trimws(pct(est$core_lo)), trimws(pct(est$core_hi))),
                 `core or indirect` = sprintf("%s [%s-%s]", pct(est$on_topic_share), trimws(pct(est$on_topic_lo)), trimws(pct(est$on_topic_hi))),
                 check.names = FALSE), row.names = FALSE)

sm <- summarise_validation(est, names(cfg$core$states))
cat(sprintf("\nWHOLE CORE: %s papers; %.0f%% are core or indirect (about %s papers), %.0f%% are strictly core.\n",
            format(sm$core_papers, big.mark = ","), 100 * sm$precision_on_topic, format(round(sm$core_on_topic), big.mark = ","), 100 * sm$precision_strict))
if (!is.na(sm$broad_only_papers))
  cat(sprintf("WHAT THE CORE LEAVES OUT: %s papers are in the broad set but not in the core; about %s of them are on topic.\n  Share of on-topic papers (of those retrieved) that the core catches: about %.0f%%.\n",
              format(sm$broad_only_papers, big.mark = ","), format(round(sm$broad_only_on_topic), big.mark = ","), 100 * sm$recall_in_retrieved))
rt <- reason_table(lab, ids)
if (!is.null(rt)) { cat("\nWHY PAPERS WERE NOT RELEVANT (rows = stratum, columns = reason code)\n"); print(rt) }
utils::write.csv(cbind(est, as.data.frame(sm)[rep(1, nrow(est)), ]), "data/processed/validation_summary.csv", row.names = FALSE)
message("\nWrote data/validation/labels.csv and data/processed/validation_summary.csv")
