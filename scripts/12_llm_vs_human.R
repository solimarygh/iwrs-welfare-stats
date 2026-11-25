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

cmp <- compare_labels(papers$human, lab, llm)
cat("\nYOUR LABEL (rows) AGAINST THE MODEL'S (columns)\n"); print(cmp$table)
cat(sprintf("\nAGREEMENT ON 'ON TOPIC' (1 or 2 against 0), papers the model decided: %.0f%%, kappa %.2f\n", 100 * cmp$agree_on_topic, cmp$kappa))
cat(sprintf("THE MODEL FLAGS %d of %d papers for a person (label ? or low confidence): %.0f%%\n", cmp$flagged, cmp$n, 100 * cmp$share_flagged))
cat(sprintf("THE AUTOMATIC PART (%d papers): agrees with you on %.0f%%; drops %d of the %d on-topic papers of the sample; keeps %d papers you labelled 0 among the %d it keeps.\n",
            cmp$auto_n, 100 * cmp$auto_agree, cmp$dropped_on_topic, cmp$on_topic_total, cmp$kept_noise, cmp$kept_total))
cat("\nAGREEMENT BY CONFIDENCE\n")
print(sapply(split(seq_len(nrow(lab)), lab$confidence), function(i) c(papers = length(i), agree_on_topic = round(mean((papers$human[i] != "0") == (lab$relevance[i] %in% c("1", "2"))), 2))))

dir.create("data/validation", showWarnings = FALSE, recursive = TRUE)
out <- lab[, c("openalex_id", "relevance", "reason_if_0", "confidence", "note")]
utils::write.csv(out, sprintf("data/validation/llm_labels_sample%s.csv", rnd), row.names = FALSE)
mm <- (papers$human != "0") != (lab$relevance %in% c("1", "2")) | papers$human != lab$relevance
mism <- data.frame(openalex_id = papers$openalex_id, journal = papers$journal, title = papers$title, you = papers$human,
                   model = lab$relevance, model_confidence = lab$confidence, model_reason = lab$reason_if_0, model_note = lab$note, abstract = papers$abstract)[mm, ]
utils::write.csv(mism, "data/raw/llm_vs_human_mismatches.csv", row.names = FALSE, fileEncoding = "UTF-8")
message(sprintf("Wrote data/validation/llm_labels_sample%s.csv; %d papers where the two differ are in data/raw/llm_vs_human_mismatches.csv.", rnd, nrow(mism)))
