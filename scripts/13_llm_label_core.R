# Step 13: the language model reads every core paper (title, journal, abstract) and labels it 2, 1, 0 or ?.
#   source("scripts/13_llm_label_core.R")
# Run step 12 first: it measures how far to trust these labels. A paper labelled ? or with low confidence goes to a
# person. Writes
#   data/validation/llm_labels_core.csv        ids, labels, confidence, note, doubtful (no abstracts: safe to commit)
#   data/raw/llm_doubtful.csv                  the papers a person has to read, with title and abstract (not tracked)
#   data/raw/review_<year>_claude.csv          the model's labels of the latest year in the format of step 11, so that
#                                              it can be one more reviewer next to the people (not tracked)
# Costs money: it prints an estimate and asks first. Answers are cached (config llm.cache): a rerun, or an interruption,
# only pays for what is missing. Needs ANTHROPIC_API_KEY in ~/.Renviron.
source("R/queries.R"); source("R/records.R"); source("R/validation.R"); source("R/llm_label.R")
cfg <- read_config(); llm <- cfg$llm
files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
rec <- readRDS(files[length(files)])
core <- rec[rec$core_any, ]
papers <- data.frame(openalex_id = core$openalex_id, year = core$year, title = core$title, journal = core$source_name,
                     abstract = core$abstract, stringsAsFactors = FALSE)
message(sprintf("%d core papers, %d without abstract (judged by title).", nrow(papers), sum(is.na(papers$abstract))))
limit <- as.integer(Sys.getenv("LLM_LIMIT", "0"))          # LLM_LIMIT=5: a first test on 5 papers only
if (!is.na(limit) && limit > 0) { papers <- head(papers, limit); message("LLM_LIMIT: only the first ", nrow(papers), " papers.") }

sys <- label_system_text(llm$guide)
confirm_spend(estimate_label_cost(llm, sys, papers))
lab <- label_papers(llm, papers, sys, call = default_claude_call)
message(sprintf("Spent: about US$ %.2f (answers that came from the cache count as 0).", spent_usd(llm, lab)))
write_core_label_outputs(papers, lab, llm)
