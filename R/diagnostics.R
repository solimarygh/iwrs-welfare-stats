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
