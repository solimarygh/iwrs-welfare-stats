# Step 12: how well does the language model agree with the author? Run it BEFORE trusting its labels (step 13).
#   source("scripts/12_llm_vs_human.R")
# Reads the labelled fresh sample (data/raw/validation_sample_2.csv, your labels), has the model label the same papers
# from the same title, journal and abstract, and reports: the table of your label against the model's, how often they
# agree on "on topic" (1 or 2 against 0), kappa, and what the automatic part of the pipeline would do to this sample:
# how many on-topic papers it would drop and how much noise it would keep, among the papers the model does not flag
# for a person. Writes data/validation/llm_labels_sample_2.csv (ids and labels only) and the disagreements to
# data/raw/llm_vs_human_mismatches.csv (with the text, not tracked).
# Costs money: it prints an estimate and asks first. Needs ANTHROPIC_API_KEY in ~/.Renviron.
# A first test on 5 papers: Sys.setenv(LLM_LIMIT = 5) before source() (the comparison is meaningless with so few).
source("R/queries.R"); source("R/records.R"); source("R/validation.R"); source("R/llm_label.R")
cfg <- read_config(); llm <- cfg$llm
rnd <- Sys.getenv("VALIDATION_ROUND", unset = "_2")
path <- sprintf("data/raw/validation_sample%s.csv", rnd)
sheet <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
hum <- read_labels(path)
use <- hum$status == "ok" & hum$relevance %in% c("0", "1", "2")
message(sprintf("%d of %d rows have your label 0, 1 or 2 (the ? rows and the empty ones are left out).", sum(use), nrow(sheet)))
papers <- sheet[use, ]
papers$human <- hum$relevance[use]
limit <- as.integer(Sys.getenv("LLM_LIMIT", "0"))          # LLM_LIMIT=5: a first test on 5 papers only
if (!is.na(limit) && limit > 0) { papers <- head(papers, limit); message("LLM_LIMIT: only the first ", nrow(papers), " papers.") }

sys <- label_system_text(llm$guide)
confirm_spend(estimate_label_cost(llm, sys, papers))
lab <- label_papers(llm, papers, sys, call = default_claude_call)
spent <- spent_usd(llm, lab); message(sprintf("Spent: about US$ %.2f", spent))

report_llm_vs_human(papers, lab, llm, rnd)
