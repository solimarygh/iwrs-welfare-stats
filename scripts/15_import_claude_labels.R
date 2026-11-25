# Step 15: uses the labels that Claude made by reading in a conversation (the same outputs as step 13 / step 12).
#   source("scripts/15_import_claude_labels.R")                        # the core: data/validation/claude_labels_core.csv
#   Sys.setenv(READ_SET = "sample"); source("scripts/15_import_claude_labels.R")  # the sample: compares with YOUR labels
# The label files are written to the repository by Claude (git pull to get them). They are checked against the papers
# (every id once, valid codes) before anything is built from them.
source("R/queries.R"); source("R/records.R"); source("R/validation.R"); source("R/llm_label.R")
cfg <- read_config(); llm <- cfg$llm
set <- Sys.getenv("READ_SET", unset = "core")
if (set == "core") {
  files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
  rec <- readRDS(files[length(files)]); core <- rec[rec$core_any, ]
  papers <- data.frame(openalex_id = core$openalex_id, year = core$year, title = core$title, journal = core$source_name, abstract = core$abstract, stringsAsFactors = FALSE)
  lab <- read_claude_labels("data/validation/claude_labels_core.csv", papers)
  write_core_label_outputs(papers, lab, llm)
} else if (set == "sample") {
  rnd <- Sys.getenv("VALIDATION_ROUND", unset = "_2")
  path <- sprintf("data/raw/validation_sample%s.csv", rnd)
  sheet <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
  hum <- read_labels(path); use <- hum$status == "ok" & hum$relevance %in% c("0", "1", "2")
  papers <- sheet[use, ]; papers$human <- hum$relevance[use]
  lab <- read_claude_labels(sprintf("data/validation/claude_labels_sample%s.csv", rnd), papers, allow_extra = TRUE)   # the file has all the papers; the comparison uses those you labelled 0, 1 or 2
  message(sprintf("%d papers labelled by you and by Claude.", nrow(papers)))
  report_llm_vs_human(papers, lab, llm, rnd)
} else stop("READ_SET must be core or sample.", call. = FALSE)
