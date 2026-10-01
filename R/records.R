# Download and parse OpenAlex records (title, abstract, journal, ...).
# Uses cursor pagination; the HTTP call is injectable for offline tests.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

oa_select_fields <- paste("id", "doi", "title", "publication_year", "type", "primary_location",
                          "abstract_inverted_index", "cited_by_count", "language", sep = ",")

# OpenAlex ships abstracts as an inverted index {word: [positions]} (0-based).
reconstruct_abstract <- function(idx) {
  if (is.null(idx) || length(idx) == 0) return(NA_character_)
  pos <- lapply(idx, function(p) as.integer(unlist(p)))
  words <- character(max(unlist(pos)) + 1L)
  for (w in names(pos)) words[pos[[w]] + 1L] <- w
  paste(words[nzchar(words)], collapse = " ")
}

parse_work <- function(w) {
  src <- w$primary_location$source
  data.frame(
    openalex_id = w$id %||% NA_character_,
    doi = w$doi %||% NA_character_,
    title = w$title %||% NA_character_,
    year = as.integer(w$publication_year %||% NA),
    type = w$type %||% NA_character_,
    source_id = src$id %||% NA_character_,
    source_name = src$display_name %||% NA_character_,
    issn_l = src$issn_l %||% NA_character_,
    cited_by_count = as.integer(w$cited_by_count %||% NA),
    language = w$language %||% NA_character_,
    abstract = reconstruct_abstract(w$abstract_inverted_index),
    stringsAsFactors = FALSE
  )
}

# All works matching `filter`, 200 per call. The total OpenAlex reports for the
# query is kept in attr(, "api_count") so the caller can check nothing was lost.
fetch_records <- function(cfg, filter, fetch = default_fetch, per_page = 200,
                          max_pages = 1000, progress = TRUE) {
  cursor <- "*"; pages <- list(); i <- 0L; api_count <- NA
  repeat {
    res <- fetch(paste0(cfg$openalex$base_url, "/works"),
                 list(filter = filter, select = oa_select_fields,
                      `per-page` = per_page, cursor = cursor),
                 oa_mailto(cfg))
    if (is.na(api_count)) api_count <- res$meta$count %||% NA
    if (length(res$results) == 0) break
    i <- i + 1L
    pages[[i]] <- do.call(rbind, lapply(res$results, parse_work))
    if (progress) message(sprintf("page %d: %d records (query total: %s)", i,
                                  nrow(pages[[i]]), format(api_count)))
    cursor <- res$meta$next_cursor
    if (is.null(cursor) || i >= max_pages) break
  }
  if (i >= max_pages) warning("Stopped at max_pages; the result is incomplete.")
  out <- if (i == 0) parse_work(list())[0, ] else do.call(rbind, pages)
  attr(out, "api_count") <- api_count
  out
}
