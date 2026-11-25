# Reads title + abstract with a language model and labels each paper 2, 1, 0 or ? following the labelling guide.
# Plain HTTP (httr2) because there is no R SDK. The call is injectable (`call`) so the logic is tested offline.

REASONS <- c("human_welfare", "venom_pharm", "human_emotion", "plant_damage", "vertebrate", "other")

# The instructions: a short role and the guide itself (stable text, so the API caches it between papers).
label_system_text <- function(guide_path) {
  paste0("You label scientific papers for a study of invertebrate sentience and welfare. For each paper you receive ",
         "the title, the journal and the abstract (or only the title). Apply the labelling guide below exactly.\\n",
         "Answer with relevance 2, 1, 0 or ?, a reason_if_0 only when relevance is 0 (otherwise an empty string), your confidence ",
         "(high, medium or low) and a note of at most one sentence that says what you relied on. Use confidence low when the ",
         "decision between two codes could reasonably go the other way.\\n\\n=== LABELLING GUIDE ===\\n",
         paste(readLines(guide_path, warn = FALSE, encoding = "UTF-8"), collapse = "\\n"))
}

label_user_text <- function(title, journal, abstract) {
  ab <- if (is.na(abstract) || !nzchar(trimws(abstract))) "(no abstract available: judge by the title)" else abstract
  paste0("Title: ", ifelse(is.na(title), "", title), "\\nJournal: ", ifelse(is.na(journal), "", journal), "\\nAbstract: ", ab)
}

label_schema <- function() list(
  type = "object",
  properties = list(
    relevance = list(type = "string", enum = as.list(c("2", "1", "0", "?"))),
    reason_if_0 = list(type = "string", enum = as.list(c("", REASONS))),
    confidence = list(type = "string", enum = as.list(c("high", "medium", "low"))),
    note = list(type = "string")),
  required = as.list(c("relevance", "reason_if_0", "confidence", "note")),
  additionalProperties = FALSE)

claude_api_key <- function() Sys.getenv("ANTHROPIC_API_KEY", unset = "")

# The request body of one paper. Thinking stays at its default (it cannot be turned off on this model);
# `effort` sets its depth. The system text carries cache_control: it is the same for every paper.
build_label_request <- function(llm, system_text, user_text, fallbacks = isTRUE(llm$fallbacks)) {
  body <- list(model = llm$model, max_tokens = llm$max_tokens,
               system = list(list(type = "text", text = system_text, cache_control = list(type = "ephemeral"))),
               messages = list(list(role = "user", content = user_text)),
               output_config = list(effort = llm$effort, format = list(type = "json_schema", schema = label_schema())))
  if (fallbacks) body$fallbacks <- "default"
  body
}

default_claude_call <- function(body) {
  key <- claude_api_key()
  if (!nzchar(key)) stop("Set ANTHROPIC_API_KEY in ~/.Renviron (console.anthropic.com > API keys) and restart R.", call. = FALSE)
  req <- httr2::request("https://api.anthropic.com/v1/messages")
  hdr <- list(`x-api-key` = key, `anthropic-version` = "2026-10-21")
  if (!is.null(body$fallbacks)) hdr$`anthropic-beta` <- "server-side-fallback-2026-07-01"
  req <- httr2::req_headers(req, !!!hdr)
  req <- httr2::req_user_agent(req, "iwrs-welfare-stats")
  req <- httr2::req_body_json(req, body, auto_unbox = TRUE)
  req <- httr2::req_retry(req, max_tries = 5, is_transient = function(r) httr2::resp_status(r) %in% c(408, 409, 429, 500, 502, 503, 529),
                          backoff = function(i) 2^i)
  req <- httr2::req_error(req, is_error = function(r) FALSE)
  resp <- httr2::req_perform(req)
  list(status = httr2::resp_status(resp), body = httr2::resp_body_json(resp))
}

# Turns an API answer into one row. A refusal, a cut-off answer or an unreadable answer give relevance "?".
parse_label_response <- function(res) {
  unsure <- function(note) data.frame(relevance = "?", reason_if_0 = "", confidence = "low", note = note, stringsAsFactors = FALSE)
  b <- res$body
  if (!identical(as.integer(res$status), 200L)) return(unsure(paste0("API error ", res$status, ": ", substr(b$error$message %||% "", 1, 120))))
  if (identical(b$stop_reason, "refusal")) return(unsure("the model declined to answer"))
  if (identical(b$stop_reason, "max_tokens")) return(unsure("the answer was cut off"))
  txt <- NULL
  for (blk in b$content) if (identical(blk$type, "text")) txt <- blk$text
  out <- tryCatch(jsonlite::fromJSON(txt %||% "", simplifyVector = TRUE), error = function(e) NULL)
  ok <- is.list(out) && out$relevance %in% c("2", "1", "0", "?") && out$confidence %in% c("high", "medium", "low")
  if (!isTRUE(ok)) return(unsure("the answer could not be read"))
  data.frame(relevance = out$relevance, reason_if_0 = if (out$relevance == "0") (out$reason_if_0 %||% "") else "",
             confidence = out$confidence, note = out$note %||% "", stringsAsFactors = FALSE)
}

# One paper. When the API rejects the request because of the `fallbacks` field, tries once without it.
label_paper <- function(llm, system_text, title, journal, abstract, call = default_claude_call) {
  body <- build_label_request(llm, system_text, label_user_text(title, journal, abstract))
  res <- call(body)
  if (identical(as.integer(res$status), 400L) && grepl("fallback", res$body$error$message %||% "", ignore.case = TRUE) && !is.null(body$fallbacks)) {
    body$fallbacks <- NULL; res <- call(body)
  }
  row <- parse_label_response(res)
  u <- res$body$usage
  row$input_tokens <- u$input_tokens %||% 0; row$output_tokens <- u$output_tokens %||% 0
  row$cache_read_tokens <- u$cache_read_input_tokens %||% 0; row$cache_write_tokens <- u$cache_creation_input_tokens %||% 0
  row
}

# A rough estimate before anything is sent: characters / 4 for the tokens, the guide counted once as a cache
# write and once per paper as a cache read (the real figures come back in the usage of each answer).
estimate_label_cost <- function(llm, system_text, papers, out_tokens = 350) {
  p <- llm$price_per_mtok
  sys_tok <- nchar(system_text) / 4
  per <- (nchar(ifelse(is.na(papers$title), "", papers$title)) + nchar(ifelse(is.na(papers$abstract), "", papers$abstract)) + 60) / 4
  n <- nrow(papers)
  usd <- (sys_tok * p$cache_write + (n - 1) * sys_tok * p$cache_read + sum(per) * p$input + n * out_tokens * p$output) / 1e6
  list(papers = n, input_tokens = round(sys_tok + sum(per)), usd = usd)
}

# Spent so far, from the usage of the answers.
spent_usd <- function(llm, rows) {
  p <- llm$price_per_mtok
  (sum(rows$input_tokens) * p$input + sum(rows$output_tokens) * p$output +
     sum(rows$cache_read_tokens) * p$cache_read + sum(rows$cache_write_tokens) * p$cache_write) / 1e6
}

# Labels every row of `papers` (openalex_id, title, journal, abstract). Answers are kept in `cache_path` under a key
# that includes the model, the effort and the guide, so a rerun only pays for what is missing and a changed guide
# or model labels everything again. Saved every 25 papers: an interruption loses nothing.
label_papers <- function(llm, papers, system_text, call = default_claude_call, cache_path = llm$cache, progress = TRUE) {
  gh <- text_hash(system_text)
  key <- function(id) paste(id, llm$model, llm$effort, gh, sep = "|")
  cache <- if (!is.null(cache_path) && file.exists(cache_path)) readRDS(cache_path) else list()
  out <- vector("list", nrow(papers))
  for (i in seq_len(nrow(papers))) {
    k <- key(papers$openalex_id[i])
    if (is.null(cache[[k]])) {
      cache[[k]] <- label_paper(llm, system_text, papers$title[i], papers$journal[i], papers$abstract[i], call)
      if (!is.null(cache_path) && i %% 25 == 0) { dir.create(dirname(cache_path), showWarnings = FALSE, recursive = TRUE); saveRDS(cache, cache_path) }
      if (progress && i %% 25 == 0) message(sprintf("labelled %d of %d", i, nrow(papers)))
    }
    out[[i]] <- cbind(openalex_id = papers$openalex_id[i], cache[[k]], stringsAsFactors = FALSE)
  }
  if (!is.null(cache_path)) { dir.create(dirname(cache_path), showWarnings = FALSE, recursive = TRUE); saveRDS(cache, cache_path) }
  do.call(rbind, out)
}

# Papers a person has to read: labelled ? or with a confidence listed in `doubtful_confidence`.
llm_doubtful <- function(labels, llm) labels$relevance == "?" | labels$confidence %in% unlist(llm$doubtful_confidence)

# A short stable fingerprint of the guide text (base R, no extra package).
text_hash <- function(x) {
  v <- utf8ToInt(enc2utf8(paste(x, collapse = "")))
  h <- 5381
  for (ch in v) h <- (h * 33 + ch) %% 2^31
  sprintf("%08x", as.integer(h))
}

# Asks before anything is billed. In a console it waits for y; in a script run without a console, LLM_CONFIRM=yes.
confirm_spend <- function(est) {
  cat(sprintf("\n%d papers, about %s input tokens. Estimated cost: about US$ %.2f (the real figure is lower when the cache works).\n",
              est$papers, format(est$input_tokens, big.mark = ","), est$usd))
  ok <- if (interactive()) tolower(trimws(readline("Send them to the API? [y/N] "))) %in% c("y", "yes") else identical(Sys.getenv("LLM_CONFIRM"), "yes")
  if (!ok) stop("Not sent. (Answer y at the question, or set LLM_CONFIRM=yes when running without a console.)", call. = FALSE)
  invisible(TRUE)
}

# The model against a person on the same papers. `human`: 0, 1 or 2 (no "?"); `llm`: data.frame(relevance, confidence).
# On topic = 1 or 2. What matters for the pipeline: of the papers the model does NOT flag for a person,
# how many on-topic papers does it drop (human on topic, model 0) and how much noise does it keep (human 0, model 1 or 2).
compare_labels <- function(human, llm, llm_cfg) {
  stopifnot(length(human) == nrow(llm), all(human %in% c("0", "1", "2")))
  flag <- llm_doubtful(llm, llm_cfg)
  yh <- human != "0"; ym <- llm$relevance %in% c("1", "2"); decided <- llm$relevance != "?"
  kappa <- function(a, b) { po <- mean(a == b); pe <- mean(a) * mean(b) + (1 - mean(a)) * (1 - mean(b)); if (isTRUE(all.equal(pe, 1))) NA_real_ else (po - pe) / (1 - pe) }
  auto <- !flag
  list(table = table(human = human, model = llm$relevance),
       n = length(human), flagged = sum(flag), share_flagged = mean(flag),
       agree_on_topic = mean(yh[decided] == ym[decided]), kappa = kappa(yh[decided], ym[decided]),
       auto_n = sum(auto), auto_agree = if (any(auto)) mean(yh[auto] == ym[auto]) else NA_real_,
       dropped_on_topic = sum(auto & yh & !ym), on_topic_total = sum(yh),
       kept_noise = sum(auto & !yh & ym), kept_total = sum(auto & ym))
}
