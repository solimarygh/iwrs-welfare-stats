# Minimal OpenAlex client. The HTTP call is injectable (`fetch`) so the logic
# can be tested offline with a mock.

# Optional API key. OpenAlex needs a free key to page past the first page of
# results (cursor paging, used by scripts/02). Kept in the environment variable
# OPENALEX_API_KEY so it is never committed.
oa_api_key <- function() Sys.getenv("OPENALEX_API_KEY", unset = "")

# Query parameters sent with every request (pure, so it can be tested offline).
oa_query_params <- function(query, mailto, api_key = "") {
  p <- c(query, list(mailto = mailto))
  if (nzchar(api_key)) p$api_key <- api_key
  p
}

default_fetch <- function(url, query, mailto) {
  req <- httr2::request(url)
  req <- httr2::req_url_query(req, !!!oa_query_params(query, mailto, oa_api_key()))
  req <- httr2::req_user_agent(req, "iwrs-welfare-stats (https://github.com/solimarygh/iwrs-welfare-stats)")
  req <- httr2::req_retry(req, max_tries = 5, backoff = function(i) 2^i)
  httr2::resp_body_json(httr2::req_perform(req))
}

# Contact address for the OpenAlex "polite pool". Read from the environment
# variable OPENALEX_MAILTO so a personal address never has to be committed;
# config/config.yml is only a fallback.
oa_mailto <- function(cfg) {
  m <- Sys.getenv("OPENALEX_MAILTO", unset = "")
  if (!nzchar(m)) m <- cfg$openalex$mailto
  if (is.null(m) || !nzchar(m) || grepl("CHANGE_ME", m, fixed = TRUE))
    stop("Set your contact email: add OPENALEX_MAILTO=you@example.org to ~/.Renviron ",
         "(then restart R), or edit openalex.mailto in config/config.yml.", call. = FALSE)
  m
}

# Works matching `filter`, counted per publication year (one API call).
# Returns a data.frame(year, n); years with no works are absent from the API
# answer and are filled with 0 so every series has the same rows.
oa_counts_by_year <- function(cfg, filter, fetch = default_fetch) {
  res <- fetch(paste0(cfg$openalex$base_url, "/works"),
               list(filter = filter, group_by = "publication_year"),
               oa_mailto(cfg))
  groups <- res$group_by
  got <- if (length(groups) == 0) {
    data.frame(year = integer(), n = integer())
  } else {
    data.frame(year = as.integer(vapply(groups, function(g) as.integer(g$key), integer(1))),
               n = vapply(groups, function(g) as.integer(g$count), integer(1)))
  }
  years <- seq(cfg$project$years[1], cfg$project$years[2])
  got <- got[got$year %in% years, , drop = FALSE]
  out <- data.frame(year = years, n = 0L)
  out$n[match(got$year, out$year)] <- got$n
  out
}
