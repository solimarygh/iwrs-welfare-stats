# Diagnostics against the live API.

# For each work, asks OpenAlex which individual search terms match it, one call
# per term (taxon terms and state terms), using the same field as the real query.
# Use it to understand why a record that shows no search term in its title or
# abstract was returned by the query.
#   source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/diagnostics.R")
#   explain_match(c("W2741809807"))
explain_match <- function(ids, cfg = read_config(), fetch = default_fetch) {
  ids <- sub("^https://openalex.org/", "", ids)
  tax <- union_terms(cfg, names(cfg$taxa))
  sta <- all_state_terms(cfg)
  matches <- function(id, term) {
    f <- paste0("openalex:", id, ",", cfg$openalex$search_field, ":", quote_term(term))
    res <- fetch(paste0(cfg$openalex$base_url, "/works"),
                 list(filter = f, `per-page` = 1), oa_mailto(cfg))
    (res$meta$count %||% 0) > 0
  }
  show <- function(x) if (length(x)) paste(x, collapse = ", ") else "(none)"
  out <- list()
  for (id in ids) {
    message("Checking ", id, " (", length(tax) + length(sta), " calls)")
    hit_t <- tax[vapply(tax, function(t) matches(id, t), logical(1))]
    hit_s <- sta[vapply(sta, function(t) matches(id, t), logical(1))]
    out[[id]] <- list(taxon = hit_t, state = hit_s)
    cat("\n", id, "\n  taxon terms matched: ", show(hit_t),
        "\n  state terms matched: ", show(hit_s), "\n", sep = "")
  }
  invisible(out)
}

# Counts and a random sample of titles for one candidate definition of "on topic".
# `filter` is a complete OpenAlex filter string. Returns list(count, titles, error).
probe_definition <- function(label, filter, cfg = read_config(), fetch = default_fetch, n_titles = 10) {
  res <- tryCatch(
    fetch(paste0(cfg$openalex$base_url, "/works"),
          list(filter = filter, select = "id,title,publication_year", `per-page` = n_titles,
               sample = n_titles, seed = 42), oa_mailto(cfg)),
    error = function(e) {
      body <- tryCatch(httr2::resp_body_string(httr2::last_response()), error = function(e2) "")
      list(error = paste(conditionMessage(e), body))
    })
  if (!is.null(res$error)) return(list(label = label, count = NA, titles = character(), error = res$error))
  titles <- vapply(res$results, function(w) paste0("(", w$publication_year %||% "?", ") ", w$title %||% "(no title)"), character(1))
  list(label = label, count = res$meta$count %||% NA, titles = titles, error = NULL)
}
