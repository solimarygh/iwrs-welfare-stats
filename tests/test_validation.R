# Offline tests for R/validation.R.   Rscript tests/test_validation.R
source("R/queries.R"); source("R/records.R"); source("R/validation.R")
ids <- data.frame(openalex_id = paste0("W", 1:12), stratum_block = rep(c("welfare", "broad_only"), each = 6),
                  primary_taxon = rep(c("insects", "insects", "insects", "crustaceans", "crustaceans", "crustaceans"), 2),
                  stratum_N = c(rep(300, 3), rep(60, 3), rep(1000, 3), rep(100, 3)), stratum_n = 3,
                  stringsAsFactors = FALSE)
ids$weight <- ids$stratum_N / ids$stratum_n
tmp <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(openalex_id = paste0("W", 1:12),
  relevance = c("2", "2", "0", "1", "0", "?",     "0", "0", "1", "0", "0", ""),
  reason_if_0 = c("", "", "venom_pharm", "", "human_emotion", "",    "other", "other", "", "other", "plant_damage", ""),
  stringsAsFactors = FALSE), tmp, row.names = FALSE)
lab <- read_labels(tmp)
stopifnot(identical(lab$status, c(rep("ok", 11), "unlabeled")))
bad <- lab; bad$relevance[1] <- "3"; utils::write.csv(bad[, 1:3], tmp, row.names = FALSE)
stopifnot(identical(read_labels(tmp)$status[1], "invalid"))

est <- estimate_precision(lab, ids, B = 300)
w <- est[est$block == "welfare", ]
# welfare: insects 2 core, 1 not (N=300, n=3 -> w=100 each); crustaceans 1 indirect, 1 not, 1 unsure (unsure left out)
# crustaceans: 2 rows kept ('?' left out) -> weight 60/2 = 30 each
# strict = 100*2 / (300 + 60) = 200/360 ; on topic = (200 + 30)/360
stopifnot(abs(w$core_share - 200 / 360) < 1e-9, abs(w$on_topic_share - 230 / 360) < 1e-9, w$unsure == 1, w$labelled == 5)
stopifnot(w$core_lo <= w$core_share, w$core_share <= w$core_hi, w$on_topic_lo <= w$on_topic_share, w$on_topic_share <= w$on_topic_hi)
stopifnot(w$N == 360, abs(w$est_on_topic - 230) < 1e-6)
sm <- summarise_validation(est, "welfare")
b <- est[est$block == "broad_only", ]                                   # the last row has no label and is left out
stopifnot(b$labelled == 5, sm$core_papers == 360, !is.na(sm$recall_in_retrieved), sm$recall_in_retrieved > 0, sm$recall_in_retrieved < 1)
stopifnot(abs(sm$precision_on_topic - 230 / 360) < 1e-9)
rt <- reason_table(lab, ids)
stopifnot(rt["welfare", "venom_pharm"] == 1, rt["broad_only", "other"] == 3, rt["welfare", "human_emotion"] == 1)
# same seed, same intervals
stopifnot(identical(estimate_precision(lab, ids, B = 300), est))
cat("test_validation.R: all checks passed\n")
