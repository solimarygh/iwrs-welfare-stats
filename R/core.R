# The CORE (strict) definition, applied locally to title + abstract.
# A paper is core for a block when an animal word and one of the block's state words
# occur within `proximity` words of each other (any order). Animal words are the
# `taxa` terms of the config, so there is a single list of names to maintain.

# Splits terms into phrases (joined into one token before tokenising), exact tokens
# and prefixes (terms ending in *).
core_matcher <- function(terms) {
  t <- tolower(trimws(unlist(terms)))
  multi <- unique(t[grepl("[[:space:]-]", t) & !grepl("\\*", t)])
  joined <- gsub("[[:space:]-]+", "_", t)
  list(multi = multi[order(-nchar(multi))],
       exact = unique(joined[!endsWith(joined, "*")]),
       prefix = unique(sub("\\*$", "", joined[endsWith(joined, "*")])))
}

token_is <- function(tokens, m) {
  hit <- tokens %in% m$exact
  for (p in m$prefix) hit <- hit | startsWith(tokens, p)
  hit
}

# "honey bee" / "honey-bee" -> "honey_bee", so a phrase is one token.
core_join_phrases <- function(text, multi) {
  for (p in multi) {
    pat <- paste0("(?<![\\p{L}\\p{N}_])", gsub("[[:space:]-]+", "[\\\\s-]+", p), "(?![\\p{L}\\p{N}_])")
    text <- gsub(pat, gsub("[[:space:]-]+", "_", p), text, perl = TRUE)
  }
  text
}

# Adds core_<block> (logical) for each block of cfg$core$states, and core_any.
tag_core <- function(rec, cfg, proximity = cfg$core$proximity) {
  noun_m <- core_matcher(union_terms(cfg, names(cfg$taxa)))     # respects search.include_noisy
  excl_m <- core_matcher(cfg$core$noun_exclude)
  st_m <- lapply(cfg$core$states, core_matcher)
  multi <- unique(c(noun_m$multi, unlist(lapply(st_m, `[[`, "multi"))))
  multi <- multi[order(-nchar(multi))]

  title <- ifelse(is.na(rec$title), "", rec$title)
  abstract <- ifelse(is.na(rec$abstract), "", rec$abstract)
  text <- core_join_phrases(tolower(enc2utf8(paste(title, abstract))), multi)
  tokens <- strsplit(trimws(gsub("[^\\p{L}\\p{N}_]+", " ", text, perl = TRUE)), " ", fixed = TRUE)

  uniq <- unique(unlist(tokens))
  is_noun <- token_is(uniq, noun_m) & !token_is(uniq, excl_m)
  is_state <- lapply(st_m, function(m) token_is(uniq, m))

  blocks <- names(cfg$core$states)
  out <- matrix(FALSE, nrow = length(tokens), ncol = length(blocks), dimnames = list(NULL, blocks))
  for (i in seq_along(tokens)) {
    ti <- match(tokens[[i]], uniq)
    pn <- which(is_noun[ti])
    if (!length(pn)) next
    for (b in blocks) {
      ps <- which(is_state[[b]][ti])
      if (length(ps) && any(abs(outer(pn, ps, "-")) <= proximity)) out[i, b] <- TRUE
    }
  }
  for (b in blocks) rec[[paste0("core_", b)]] <- out[, b]
  rec$core_any <- rowSums(out) > 0
  rec
}

# The core can only find papers the broad search retrieved: every core state word must
# be matched by some broad state term. Returns the words that are not (empty when fine).
core_uncovered_words <- function(cfg) {
  words <- unique(unlist(cfg$core$states))
  probe <- sub("\\*$", "", words)
  words[!vapply(probe, function(w) tag_terms(w, all_state_terms(cfg)), logical(1))]
}
