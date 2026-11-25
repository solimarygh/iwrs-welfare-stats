# Step 14: files for having the papers read in a conversation with Claude (no API, no cost).
#   source("scripts/14_export_for_reading.R")                         # the core papers
#   Sys.setenv(READ_SET = "sample"); source("scripts/14_export_for_reading.R")   # the fresh sample, WITHOUT your labels
# Writes data/raw/to_read/<set>_001.csv, _002.csv, ... of BATCH rows each (default 100): id, year, journal, title, abstract.
# Nothing in them says which block matched a paper, and the sample files carry none of your labels, so the reading is blind.
# Attach the files to the conversation (data/raw is not tracked: abstracts are publisher text and stay out of GitHub).
source("R/queries.R"); source("R/records.R"); source("R/validation.R"); source("R/llm_label.R")
set <- Sys.getenv("READ_SET", unset = "core"); size <- as.integer(Sys.getenv("BATCH", unset = "100"))
if (set == "core") {
  files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
  rec <- readRDS(files[length(files)]); core <- rec[rec$core_any, ]
  papers <- data.frame(openalex_id = core$openalex_id, year = core$year, journal = core$source_name, title = core$title, abstract = core$abstract, stringsAsFactors = FALSE)
  papers <- papers[order(-papers$year, papers$openalex_id), ]
} else if (set == "sample") {
  rnd <- Sys.getenv("VALIDATION_ROUND", unset = "_2")
  papers <- utils::read.csv(sprintf("data/raw/validation_sample%s.csv", rnd), stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
  papers <- papers[, intersect(c("openalex_id", "year", "journal", "title", "abstract"), names(papers))]
} else stop("READ_SET must be core or sample.", call. = FALSE)
f <- write_reading_batches(papers, "data/raw/to_read", set, size)
message(sprintf("%d papers (%d without abstract) in %d files of up to %d: %s ... %s", nrow(papers), sum(is.na(papers$abstract) | papers$abstract == ""), length(f), size, basename(f[1]), basename(f[length(f)])))
message("Attach the files to the conversation. Claude returns the labels as data/validation/claude_labels_", set, if (set == "sample") "_2" else "", ".csv in the repository.")
