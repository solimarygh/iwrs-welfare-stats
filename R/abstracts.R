# Recover abstracts that OpenAlex searches but does not return, using the DOI.
# Sources (free, no key): Crossref, then Europe PMC. HTTP is injectable for tests.

# JSON GET returning the parsed body, or NULL on any failure or non-200 answer.
default_json_fetch <- function(url, query = list(), mailto = NULL) {
  req <- httr2::request(url)
  if (length(query)) req <- httr2::req_url_query(req, !!!query)
  req <- httr2::req_user_agent(req, paste0("iwrs-welfare-stats (mailto:", mailto, ")"))
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  req <- httr2::req_retry(req, max_tries = 3,
                          is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504))
  resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
  if (is.null(resp) || httr2::resp_status(resp) != 200) return(NULL)
  tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
}

# JATS/HTML markup -> plain text.
strip_markup <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) return(NA_character_)
  x <- gsub("<[^>]*>", " ", x)
  m <- gregexpr("&#[0-9]+;", x)
  regmatches(x, m) <- lapply(regmatches(x, m), function(e)
    vapply(e, function(s) intToUtf8(as.integer(gsub("[^0-9]", "", s))), character(1)))
  for (ent in list(c("&amp;", "&"), c("&lt;", "<"), c("&gt;", ">"), c("&quot;", "\""), c("&apos;", "'")))
    x <- gsub(ent[1], ent[2], x, fixed = TRUE)
  x <- trimws(gsub("[[:space:]]+", " ", x))
  x <- sub("^(?i)abstract[:.]?[[:space:]]+", "", x, perl = TRUE)
  if (!nzchar(x)) NA_character_ else x
}

encode_doi <- function(doi) gsub("\\?", "%3F", gsub("#", "%23", utils::URLencode(doi, reserved = FALSE)))

crossref_abstract <- function(doi, fetch, mailto) {
  res <- fetch(paste0("https://api.crossref.org/works/", encode_doi(doi)), list(mailto = mailto), mailto)
  strip_markup(res$message$abstract %||% NA_character_)
}

europepmc_abstract <- function(doi, fetch, mailto) {
  res <- fetch("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
               list(query = paste0('DOI:"', doi, '"'), resultType = "core", format = "json", pageSize = 1), mailto)
  r <- res$resultList$result
  if (length(r) == 0) return(NA_character_)
  strip_markup(r[[1]]$abstractText %||% NA_character_)
}

# Fills `abstract` where it is missing and a DOI exists; `abstract_source` says
# where each abstract came from. Answers (including "not found") are cached by
# DOI, so an interrupted run resumes; delete the cache file to retry failures.
recover_abstracts <- function(rec, cfg, fetch = default_json_fetch, min_chars = 100,
                              cache_path = "data/raw/abstract_cache.rds", progress_every = 100) {
  if (!"abstract_source" %in% names(rec))
    rec$abstract_source <- ifelse(is.na(rec$abstract), NA_character_, "openalex")
  doi <- sub("^https?://(dx\\.)?doi\\.org/", "", rec$doi, ignore.case = TRUE)
  todo <- which(is.na(rec$abstract) & !is.na(doi) & nzchar(doi))
  cache <- if (!is.null(cache_path) && file.exists(cache_path)) readRDS(cache_path) else list()
  mailto <- oa_mailto(cfg)
  usable <- function(txt) !is.na(txt) && nchar(txt) >= min_chars
  save_cache <- function() if (!is.null(cache_path)) saveRDS(cache, cache_path)
  message(length(todo), " records without abstract and with a DOI")
  for (k in seq_along(todo)) {
    i <- todo[k]; d <- doi[i]
    hit <- cache[[d]]
    if (is.null(hit)) {
      hit <- list(text = NA_character_, source = NA_character_)
      txt <- crossref_abstract(d, fetch, mailto)
      if (usable(txt)) hit <- list(text = txt, source = "crossref") else {
        txt <- europepmc_abstract(d, fetch, mailto)
        if (usable(txt)) hit <- list(text = txt, source = "europepmc")
      }
      cache[[d]] <- hit
    }
    if (!is.na(hit$text)) { rec$abstract[i] <- hit$text; rec$abstract_source[i] <- hit$source }
    if (k %% progress_every == 0) {
      message(sprintf("%d / %d checked, %d recovered so far", k, length(todo),
                      sum(rec$abstract_source[todo[seq_len(k)]] %in% c("crossref", "europepmc"))))
      save_cache()
    }
  }
  save_cache()
  rec
}
