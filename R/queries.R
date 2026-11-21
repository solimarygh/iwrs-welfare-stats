# Build OpenAlex search expressions from config/config.yml.
# Pure functions: no network access, so they can be tested offline.

read_config <- function(path = "config/config.yml") {
  yaml::read_yaml(path)
}

# Multi-word or hyphenated terms must be quoted phrases.
quote_term <- function(x) {
  x <- trimws(x)
  if (grepl("[[:space:]-]", x)) paste0('"', x, '"') else x
}

or_group <- function(terms) {
  stopifnot(length(terms) > 0)
  paste0("(", paste(vapply(terms, quote_term, character(1)), collapse = " OR "), ")")
}

build_search <- function(taxa_terms, state_terms) {
  paste(or_group(taxa_terms), "AND", or_group(state_terms))
}

# Terms of one taxon group, with the noisy ones only if requested.
taxon_terms <- function(cfg, group, include_noisy = isTRUE(cfg$search$include_noisy)) {
  g <- cfg$taxa[[group]]
  if (is.null(g)) stop("Unknown taxon group: ", group)
  terms <- unlist(g$terms)
  if (include_noisy) terms <- c(terms, unlist(g$noisy))
  unique(terms)
}

arthropod_groups <- function(cfg) {
  names(Filter(function(g) isTRUE(g$arthropod), cfg$taxa))
}

# Union of several groups (used for ALL_ARTHROPODS and ALL_INVERTEBRATES).
union_terms <- function(cfg, groups) {
  unique(unlist(lapply(groups, taxon_terms, cfg = cfg)))
}

state_terms <- function(cfg, block) {
  s <- cfg$states[[block]]
  if (is.null(s)) stop("Unknown state block: ", block)
  unlist(s$terms)
}

all_state_terms <- function(cfg) {
  unique(unlist(lapply(names(cfg$states), state_terms, cfg = cfg)))
}

# Filter shared by every query: publication window + document type + source type.
build_filter <- function(cfg, search = NULL) {
  yrs <- cfg$project$years
  parts <- c(
    paste0("from_publication_date:", yrs[1], "-01-01"),
    paste0("to_publication_date:", yrs[2], "-12-31"),
    paste0("type:", paste(unlist(cfg$openalex$work_types), collapse = "|")),
    paste0("primary_location.source.type:", cfg$openalex$source_type)
  )
  if (!is.null(search)) parts <- c(parts, paste0(cfg$openalex$search_field, ":", search))
  paste(parts, collapse = ",")
}

# ---- core (strict) definition: animal word NEAR state word ----------------------------
# One phrase per animal x state word, e.g. "insects welfare"~6 (words within 6 positions,
# any order, so "welfare of farmed insects" also matches).
core_phrases <- function(cfg, block, proximity = cfg$core$proximity) {
  words <- cfg$core$states[[block]]
  if (is.null(words)) stop("Unknown core block: ", block)
  grid <- expand.grid(n = unlist(cfg$core$taxon_nouns), w = unlist(words), stringsAsFactors = FALSE)
  p <- paste0('"', grid$n, " ", grid$w, '"')
  if (!is.null(proximity) && proximity > 0) p <- paste0(p, "~", proximity)
  p
}

build_core_search <- function(cfg, blocks = names(cfg$core$states), proximity = cfg$core$proximity) {
  paste0("(", paste(unlist(lapply(blocks, core_phrases, cfg = cfg, proximity = proximity)), collapse = " OR "), ")")
}
