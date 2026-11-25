# Step 11: reads the reviewers' sheets, measures how much they agree and builds the final labels.
#   source("scripts/11_read_review.R")
# Reads data/raw/review_<year>_<name>.csv (one file per reviewer). Disagreements go to
# data/raw/review_<year>_to_resolve.csv (title, abstract, each reviewer's label and note): after discussing
# them, write the decision in data/raw/review_<year>_resolved.csv (columns openalex_id, relevance) and run this
# step again. Writes data/validation/review_<year>_final.csv (ids and labels only: safe to commit).
source("R/queries.R"); source("R/validation.R"); source("R/review.R")
files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
rec <- readRDS(files[length(files)]); year <- max(rec$year[rec$core_any])
rv <- read_review_files("data/raw", year)
total <- sum(rec$core_any & rec$year == year)
cat(sprintf("\nCORE PAPERS OF %s: %d. LABELS PER REVIEWER (2 core, 1 indirect, 0 not relevant, ? unsure, - missing)\n", year, total))
lab <- sapply(rv$reviewers, function(r) table(factor(ifelse(is.na(rv$wide[[r]]), "-", rv$wide[[r]]), c("2", "1", "0", "?", "-"))))
print(lab)
ag <- review_agreement(rv$wide)
if (!is.null(ag)) { cat("\nAGREEMENT ON 'ON TOPIC' (1 or 2 against 0)\n"); ag$agree_on_topic <- sprintf("%.0f%%", 100 * ag$agree_on_topic); ag$kappa <- round(ag$kappa, 2); print(ag, row.names = FALSE) }

resolved_path <- sprintf("data/raw/review_%s_resolved.csv", year)
resolved <- if (file.exists(resolved_path)) utils::read.csv(resolved_path, stringsAsFactors = FALSE, colClasses = "character") else NULL
fin <- review_final(rv$wide, resolved)
cat("\nSTATUS OF THE PAPERS\n"); print(table(fin$status))
pend <- fin[fin$status == "to_resolve", ]
if (nrow(pend)) {
  sheet <- utils::read.csv(sprintf("data/raw/review_%s.csv", year), stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
  out <- sheet[match(pend$openalex_id, sheet$openalex_id), c("openalex_id", "journal", "title", "abstract")]
  for (r in rv$reviewers) {
    out[[r]] <- rv$wide[[r]][match(pend$openalex_id, rv$wide$openalex_id)]
    out[[paste0(r, "_note")]] <- rv$long$notes[match(paste(pend$openalex_id, r), paste(rv$long$openalex_id, rv$long$reviewer))]
  }
  out$relevance <- ""                         # the decision: copy these two columns into review_<year>_resolved.csv
  utils::write.csv(out, sprintf("data/raw/review_%s_to_resolve.csv", year), row.names = FALSE, na = "", fileEncoding = "UTF-8")
  message(nrow(pend), " papers to resolve: see data/raw/review_", year, "_to_resolve.csv. Fill `relevance` (2, 1 or 0), save the columns ",
          "openalex_id and relevance as ", resolved_path, ", and run this step again.")
} else {
  ok <- fin$final %in% c("1", "2")
  cat(sprintf("\nCONFIRMED ON TOPIC: %d of %d core papers of %s (%.0f%%): %d core, %d indirect.\n", sum(ok), nrow(fin), year, 100 * mean(ok),
              sum(fin$final == "2", na.rm = TRUE), sum(fin$final == "1", na.rm = TRUE)))
}
dir.create("data/validation", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(fin, sprintf("data/validation/review_%s_final.csv", year), row.names = FALSE, na = "")
message("Wrote data/validation/review_", year, "_final.csv. Run scripts/09_build_papers.R to show the result on the page.")
