# Offline tests for R/review.R.   Rscript tests/test_review.R
source("R/queries.R"); source("R/validation.R"); source("R/review.R")
rec <- data.frame(openalex_id = paste0("W", 1:6), doi = NA, year = c(2026, 2026, 2026, 2026, 2026, 2025), source_name = "J",
                  title = paste("Title", 1:6), abstract = c("a", NA, "c", "d", "e", "f"), core_any = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE), stringsAsFactors = FALSE)
sh <- make_review_sheet(rec, 2026)
stopifnot(nrow(sh) == 4, setequal(sh$openalex_id, c("W1", "W2", "W3", "W4")), all(sh$relevance == ""), !"core_welfare" %in% names(sh))
stopifnot(identical(sh$openalex_id, make_review_sheet(rec, 2026)$openalex_id))                       # same order every time
err <- tryCatch(make_review_sheet(rec, 2030), error = function(e) conditionMessage(e)); stopifnot(grepl("No core papers", err))

d <- tempfile(); dir.create(d)
wr <- function(name, rel, notes = "") utils::write.csv(data.frame(row = 1:4, openalex_id = paste0("W", 1:4), relevance = rel, reason_if_0 = "", notes = notes), file.path(d, name), row.names = FALSE)
wr("review_2026_ana.csv", c("2", "0", "1", "?"), c("", "", "x", "unsure"))
wr("review_2026_bo.csv",  c("1", "0", "0", "2"))
wr("review_2026.csv", rep("", 4)); wr("review_2026_resolved.csv", rep("", 4))                          # these two are not reviewers
r <- read_review_files(d, 2026)
stopifnot(identical(r$reviewers, c("ana", "bo")), nrow(r$wide) == 4, r$wide$ana[4] == "?")
ag <- review_agreement(r$wide)
# on topic: W1 yes/yes, W2 no/no, W3 yes/no, W4 excluded ('?'): 3 papers, agreement 2/3
stopifnot(ag$n == 3, abs(ag$agree_on_topic - 2 / 3) < 1e-9)
pa <- c(TRUE, FALSE, TRUE); pb <- c(TRUE, FALSE, FALSE); po <- 2 / 3; pe <- mean(pa) * mean(pb) + (1 - mean(pa)) * (1 - mean(pb))
stopifnot(abs(ag$kappa - (po - pe) / (1 - pe)) < 1e-9)
f <- review_final(r$wide)
stopifnot(identical(f$final, c("1", "0", NA, NA)), identical(f$status, c("agreed", "agreed", "to_resolve", "to_resolve")))   # 2 and 1 give 1
f2 <- review_final(r$wide, data.frame(openalex_id = c("W3", "W4"), relevance = c("0", "2"), stringsAsFactors = FALSE))
stopifnot(identical(f2$final, c("1", "0", "0", "2")), identical(f2$status, c("agreed", "agreed", "resolved", "resolved")))
err <- tryCatch(review_final(r$wide, data.frame(openalex_id = "W9", relevance = "1")), error = function(e) conditionMessage(e)); stopifnot(grepl("not in the review", err))
err <- tryCatch(review_final(r$wide, data.frame(openalex_id = "W3", relevance = "?")), error = function(e) conditionMessage(e)); stopifnot(grepl("must be 0, 1 or 2", err))
# one reviewer only: no agreement, labels stand
one <- r$wide[, c("openalex_id", "bo")]
stopifnot(is.null(review_agreement(one)), identical(review_final(one)$status[1:2], c("single", "single")))
# a wrong code is refused
wr("review_2026_cy.csv", c("2", "5", "1", "0"))
err <- tryCatch(read_review_files(d, 2026), error = function(e) conditionMessage(e)); stopifnot(grepl("not 2, 1, 0", err))
err <- tryCatch(read_review_files(tempfile(), 2026), error = function(e) conditionMessage(e)); stopifnot(grepl("No reviewer file", err))
cat("test_review.R: all checks passed\n")
