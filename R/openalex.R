# Minimal OpenAlex client. The HTTP call is injectable (`fetch`) so the logic
# can be tested offline with a mock.

default_fetch <- function(url, query, mailto) {
  req <- httr2::request(url)
  req <- httr2::req_url_query(req, !!!query, mailto = mailto)
  req <- httr2::req_user_agent(req, "iwrs-welfare-stats (https://github.com/solimarygh/iwrs-welfare-stats)")
  req <- httr2::req_retry(req, max_tries = 5, backoff = function(i) 2^i)
  httr2::resp_body_json(httr2::req_perform(req))
}

# Works matching `filter`, counted per publication year (one API call).
# Returns a data.frame(year, n); years with no works are absent from the API
# answer and are filled with 0 so every series has the same rows.
oa_counts_by_year <- function(cfg, filter, fetch = default_fetch) {
  res <- fetch(paste0(cfg$openalex$base_url, "/works"),
               list(filter = filter, group_by = "publication_year"),
               cfg$openalex$mailto)
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
