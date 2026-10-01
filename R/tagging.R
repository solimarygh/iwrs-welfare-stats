# Local tagging of records with the same terms as the search, so each record
# carries its taxon groups and state blocks (the API only returns counts per
# query). Approximate by construction: OpenAlex's tokenizer is not ours, so
# script 02 reports how closely the local tags reproduce the API counts.

term_to_regex <- function(term) {
  x <- trimws(term)
  x <- gsub("([][{}()+?.^$|\\\\])", "\\\\\\1", x, perl = TRUE)   # escape regex specials
  x <- gsub("\\*", "[\\\\p{L}\\\\p{N}_]*", x)                    # wildcard: rest of the word
  x <- gsub("[[:space:]]+", "[[:space:]]+", x)                   # any whitespace in phrases
  paste0("(?<![\\p{L}\\p{N}_])", x, "(?![\\p{L}\\p{N}_])")       # whole words only
}

tag_terms <- function(text, terms) {
  text <- enc2utf8(ifelse(is.na(text), "", text))
  pat <- paste0("(?i)(?:", paste(vapply(terms, term_to_regex, character(1)), collapse = "|"), ")")
  grepl(pat, text, perl = TRUE)
}

# Adds taxon_<group>, state_<block> and is_arthropod columns (logical).
tag_records <- function(rec, cfg) {
  text <- paste(rec$title, rec$abstract)
  for (g in names(cfg$taxa)) rec[[paste0("taxon_", g)]] <- tag_terms(text, taxon_terms(cfg, g))
  for (b in names(cfg$states)) rec[[paste0("state_", b)]] <- tag_terms(text, state_terms(cfg, b))
  arth <- paste0("taxon_", arthropod_groups(cfg))
  rec$is_arthropod <- Reduce(`|`, lapply(arth, function(cl) rec[[cl]]))
  rec
}
