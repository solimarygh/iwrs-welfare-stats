# Offline tests for R/llm_label.R (no call to the API).   Rscript tests/test_llm_label.R
source("R/queries.R"); source("R/records.R"); source("R/llm_label.R")
cfg <- read_config(); llm <- cfg$llm
guide <- tempfile(); writeLines(c("RELEVANCE", "2 core", "0 not relevant"), guide)
sys <- label_system_text(guide)
stopifnot(grepl("=== LABELLING GUIDE ===", sys, fixed = TRUE), grepl("2 core", sys, fixed = TRUE))
stopifnot(grepl("no abstract available", label_user_text("T", "J", NA), fixed = TRUE), grepl("Abstract: Some text", label_user_text("T", "J", "Some text"), fixed = TRUE))

# request body: model, effort, cache on the system text, schema, no forbidden fields
b <- build_label_request(llm, sys, "user text")
stopifnot(b$model == "claude-opus-5-5", b$output_config$effort == "low", identical(b$system[[1]]$cache_control$type, "ephemeral"),
          is.null(b$thinking), is.null(b$temperature), identical(b$fallbacks, "default"), b$messages[[1]]$role == "user")
json <- jsonlite::toJSON(b, auto_unbox = TRUE)
stopifnot(grepl('"enum":["2","1","0","?"]', json, fixed = TRUE), grepl('"required":["relevance"', json, fixed = TRUE), grepl('"additionalProperties":false', json, fixed = TRUE))
stopifnot(is.null(build_label_request(llm, sys, "u", fallbacks = FALSE)$fallbacks))

ok <- function(rel, conf = "high", reason = "", note = "n", extra = list()) list(status = 200L, body = c(list(
  stop_reason = "end_turn", content = list(list(type = "thinking", thinking = ""), list(type = "text", text = as.character(jsonlite::toJSON(
    list(relevance = rel, reason_if_0 = reason, confidence = conf, note = note), auto_unbox = TRUE)))),
  usage = list(input_tokens = 100, output_tokens = 40, cache_read_input_tokens = 2000, cache_creation_input_tokens = 0)), extra))
r <- parse_label_response(ok("2")); stopifnot(r$relevance == "2", r$confidence == "high", r$reason_if_0 == "")
r <- parse_label_response(ok("0", "medium", "venom_pharm")); stopifnot(r$relevance == "0", r$reason_if_0 == "venom_pharm")
r <- parse_label_response(ok("1", reason = "other")); stopifnot(r$reason_if_0 == "")                      # a reason only with relevance 0
bad <- list(status = 200L, body = list(stop_reason = "end_turn", content = list(list(type = "text", text = "not json"))))
stopifnot(parse_label_response(bad)$relevance == "?")
stopifnot(parse_label_response(list(status = 200L, body = list(stop_reason = "refusal", content = list())))$note == "the model declined to answer")
stopifnot(parse_label_response(list(status = 200L, body = list(stop_reason = "max_tokens", content = list())))$note == "the answer was cut off")
e <- parse_label_response(list(status = 529L, body = list(error = list(message = "overloaded")))); stopifnot(e$relevance == "?", grepl("529", e$note))
wrong <- list(status = 200L, body = list(stop_reason = "end_turn", content = list(list(type = "text", text = '{"relevance":"5","reason_if_0":"","confidence":"high","note":""}'))))
stopifnot(parse_label_response(wrong)$relevance == "?")                                                      # a code outside 2/1/0/? is not accepted

# one paper: usage kept; retry without `fallbacks` when the API rejects that field
calls <- list()
mock <- function(body) { calls[[length(calls) + 1]] <<- body; ok("2") }
row <- label_paper(llm, sys, "T", "J", "A", mock)
stopifnot(row$relevance == "2", row$input_tokens == 100, row$cache_read_tokens == 2000, length(calls) == 1)
calls <- list()
mock400 <- function(body) { calls[[length(calls) + 1]] <<- body
  if (!is.null(body$fallbacks)) list(status = 400L, body = list(error = list(message = "Unknown field: fallbacks"))) else ok("1") }
row <- label_paper(llm, sys, "T", "J", "A", mock400)
stopifnot(row$relevance == "1", length(calls) == 2, is.null(calls[[2]]$fallbacks))

# many papers: cache by id, model, effort and guide; a rerun costs nothing
papers <- data.frame(openalex_id = paste0("W", 1:3), title = c("a", "b", "c"), journal = "J", abstract = c("x", NA, "z"), stringsAsFactors = FALSE)
n <- 0; counting <- function(body) { n <<- n + 1; ok(c("2", "0", "?")[n %% 3 + 1]) }
cp <- tempfile(fileext = ".rds")
l1 <- label_papers(llm, papers, sys, counting, cp, progress = FALSE); stopifnot(nrow(l1) == 3, n == 3, identical(l1$openalex_id, papers$openalex_id))
l2 <- label_papers(llm, papers, sys, counting, cp, progress = FALSE); stopifnot(n == 3, identical(l1, l2))       # all from the cache
llm2 <- llm; llm2$effort <- "high"; invisible(label_papers(llm2, papers[1, ], sys, counting, cp, progress = FALSE)); stopifnot(n == 4)   # other effort: asked again
sys2 <- paste(sys, "changed"); invisible(label_papers(llm, papers[1, ], sys2, counting, cp, progress = FALSE)); stopifnot(n == 5)      # other guide: asked again

# who goes to a person; cost
lab <- data.frame(relevance = c("2", "?", "0", "1"), confidence = c("high", "high", "low", "medium"), stringsAsFactors = FALSE)
stopifnot(identical(llm_doubtful(lab, llm), c(FALSE, TRUE, TRUE, FALSE)))
est <- estimate_label_cost(llm, sys, papers); stopifnot(est$papers == 3, est$usd > 0, est$input_tokens > 0)
stopifnot(abs(spent_usd(llm, data.frame(input_tokens = 1e6, output_tokens = 1e6, cache_read_tokens = 1e6, cache_write_tokens = 1e6)) - (4 + 20 + 0.2 + 5)) < 1e-9)
# no key: a clear message, not a stack trace from the HTTP library
old <- Sys.getenv("ANTHROPIC_API_KEY", unset = NA); Sys.unsetenv("ANTHROPIC_API_KEY")
err <- tryCatch(default_claude_call(b), error = function(e) conditionMessage(e)); stopifnot(grepl("ANTHROPIC_API_KEY", err))
if (!is.na(old)) Sys.setenv(ANTHROPIC_API_KEY = old)
# model against a person
human <- c("2", "1", "0", "0", "2", "0", "1", "0")
llm_rows <- data.frame(relevance = c("2", "0", "0", "1", "?", "0", "2", "0"),
                       confidence = c("high", "low", "high", "high", "high", "high", "high", "high"), stringsAsFactors = FALSE)
cmp <- compare_labels(human, llm_rows, llm)
# flagged: row 2 (low confidence) and row 5 ('?'); automatic part = rows 1, 3, 4, 6, 7, 8
stopifnot(cmp$n == 8, cmp$flagged == 2, cmp$auto_n == 6, abs(cmp$share_flagged - 2 / 8) < 1e-9)
# automatic part: 1 yes/yes, 3 no/no, 4 no/yes (noise kept), 6 no/no, 7 yes/yes, 8 no/no -> 5 of 6 agree
stopifnot(abs(cmp$auto_agree - 5 / 6) < 1e-9, cmp$kept_noise == 1, cmp$kept_total == 3, cmp$dropped_on_topic == 0, cmp$on_topic_total == 4)
# decided rows (no '?'): 1,2,3,4,6,7,8 -> on topic human: 1 y,2 y,3 n,4 n,6 n,7 y,8 n ; model: y,n,n,y,n,y,n -> agree 5/7
stopifnot(abs(cmp$agree_on_topic - 5 / 7) < 1e-9, cmp$table["2", "2"] == 1)
cmp2 <- compare_labels(c("2", "0"), data.frame(relevance = c("0", "0"), confidence = "high"), llm)
stopifnot(cmp2$dropped_on_topic == 1)
err <- tryCatch(compare_labels("?", data.frame(relevance = "0", confidence = "high"), llm), error = function(e) "err"); stopifnot(err == "err")
est2 <- estimate_label_cost(llm, sys, papers)
err <- tryCatch(confirm_spend(est2), error = function(e) conditionMessage(e)); stopifnot(grepl("Not sent", err))        # no console, no LLM_CONFIRM: nothing is sent
Sys.setenv(LLM_CONFIRM = "yes"); invisible(capture.output(res <- confirm_spend(est2))); stopifnot(isTRUE(res)); Sys.unsetenv("LLM_CONFIRM")
cat("test_llm_label.R: all checks passed\n")
