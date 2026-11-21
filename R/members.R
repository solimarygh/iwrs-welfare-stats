# Members map: counts per country from the membership list. Only counts leave the list.

# Lower case, no accents, letters and digits only ("México" -> "mexico", "U.S.A." -> "u s a").
norm_country <- function(x) {
  x <- tolower(enc2utf8(as.character(x)))
  # one regex per letter (not chartr), so it behaves the same in any session locale
  for (m in list(c("\u00e1\u00e0\u00e2\u00e3\u00e4\u00e5", "a"), c("\u00e9\u00e8\u00ea\u00eb", "e"),
                 c("\u00ed\u00ec\u00ee\u00ef", "i"), c("\u00f3\u00f2\u00f4\u00f5\u00f6", "o"),
                 c("\u00fa\u00f9\u00fb\u00fc", "u"), c("\u00f1", "n"), c("\u00e7", "c"), c("\u00fd\u00ff", "y")))
    x <- gsub(paste0("[", m[1], "]"), m[2], x, perl = TRUE)
  trimws(gsub("[^a-z0-9]+", " ", x))
}

read_country_lookup <- function(path = "data/reference/country_names.csv") {
  utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
}

# Reads the list (xlsx, xls or csv) as a table of text. Only headers appear in error messages.
read_member_table <- function(path, cfg) {
  if (!file.exists(path)) stop("Membership file not found: ", path, "\nPut it in data/private/ (not tracked by git).", call. = FALSE)
  if (tolower(tools::file_ext(path)) %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE)) stop("Install readxl: install.packages(\"readxl\")", call. = FALSE)
    as.data.frame(readxl::read_excel(path, sheet = cfg$members$sheet %||% 1, col_types = "text"), stringsAsFactors = FALSE)
  } else utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8")
}

# The country column is `members.country_column` in the config, or the only column whose header
# mentions a country.
country_of <- function(df, cfg) {
  col <- cfg$members$country_column
  if (is.null(col)) {
    hit <- grep("countr|pa[i\u00ed]s|nation|resid", names(df), ignore.case = TRUE, value = TRUE)
    if (length(hit) != 1)
      stop(if (length(hit)) "More than one column looks like a country: " else "No column looks like a country. ",
           "Set members.country_column in config/config.yml to one of: ", paste0('"', names(df), '"', collapse = ", "), call. = FALSE)
    col <- hit
  }
  if (!col %in% names(df)) stop("Column \"", col, "\" not found. Columns: ", paste0('"', names(df), '"', collapse = ", "), call. = FALSE)
  df[[col]]
}

read_member_countries <- function(path, cfg) country_of(read_member_table(path, cfg), cfg)

# ---- filters: free-text expertise columns -> counts per term and country -------------------------

# Positions of the columns whose header starts with any of `headers` (case-insensitive). By
# position, because a CSV can hold two columns with the same header.
facet_columns <- function(df, headers) {
  which(vapply(names(df), function(nm) any(startsWith(tolower(nm), tolower(headers))), logical(1)))
}

# One character vector of terms per row: split, lower-cased, tidied; empty and "n/a"-like dropped.
split_terms <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("(?<![a-z])n/a(?![a-z])", "na", x, perl = TRUE)      # "N/A" must not be split on the slash
  parts <- strsplit(x, "[,;/\n|]+|\\s+and\\s+", perl = TRUE)
  parts[is.na(x)] <- list(character(0))
  lapply(parts, function(p) {
    p <- gsub("\\s+", " ", trimws(gsub("[\"'.]+", "", p)))
    unique(p[nzchar(p) & !p %in% c("n/a", "na", "none", "no", "-", "n.a")])
  })
}

# Aliases: CSV with columns term, canonical and (optional) facet. A `term` starting with "regex:"
# is a regular expression (first matching rule wins, after exact terms). A row with a facet applies
# only to that filter and beats a row without one. An empty canonical drops the term.
read_term_aliases <- function(path) {
  empty <- data.frame(term = character(), canonical = character(), facet = character(), stringsAsFactors = FALSE)
  if (is.null(path) || !file.exists(path)) return(empty)
  a <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
  if (is.null(a$facet)) a$facet <- ""
  data.frame(term = trimws(a$term), canonical = tolower(trimws(ifelse(is.na(a$canonical), "", a$canonical))),
             facet = trimws(ifelse(is.na(a$facet), "", a$facet)), stringsAsFactors = FALSE)
}

apply_aliases <- function(person_terms, aliases, facet = NULL) {
  if (is.null(aliases$facet)) aliases$facet <- ""
  keep_case <- startsWith(aliases$term, "regex:")                           # patterns keep their case
  aliases$term[!keep_case] <- tolower(aliases$term[!keep_case])
  if (!is.null(facet)) aliases <- aliases[aliases$facet %in% c("", facet), , drop = FALSE]
  aliases <- aliases[order(aliases$facet == ""), , drop = FALSE]            # facet-specific rows first
  rx <- startsWith(aliases$term, "regex:")
  exact <- aliases[!rx, , drop = FALSE]; rules <- aliases[rx, , drop = FALSE]
  pats <- sub("^regex:", "", rules$term)
  lapply(person_terms, function(t) {
    out <- vapply(t, function(x) {
      i <- match(x, exact$term)
      if (!is.na(i)) return(exact$canonical[i])
      hit <- which(vapply(pats, function(r) grepl(r, x, perl = TRUE), logical(1)))
      if (length(hit)) rules$canonical[hit[1]] else x
    }, character(1))
    unique(out[nzchar(out)])
  })
}

# Terms per person for one filter: the columns are merged, then aliases applied.
member_terms <- function(df, headers, aliases, facet = NULL, split = TRUE) {
  cols <- facet_columns(df, headers)
  if (!length(cols)) stop("No column starts with: ", paste0('"', headers, '"', collapse = ", "),
                          ". Columns: ", paste0('"', names(df), '"', collapse = ", "), call. = FALSE)
  one <- function(x) { x <- tolower(trimws(as.character(x))); lapply(x, function(v) if (is.na(v) || !nzchar(v)) character(0) else v) }
  per_col <- lapply(cols, function(i) if (split) split_terms(df[[i]]) else one(df[[i]]))
  merged <- lapply(seq_len(nrow(df)), function(i) unique(unlist(lapply(per_col, `[[`, i))))
  apply_aliases(merged, aliases, facet)
}

# Members per term, and per country within each term. Only terms stated by at least min_cell
# members are kept; a country cell below min_cell carries no number.
facet_counts <- function(person_terms, iso3, min_cell = 3, max_terms = 40) {
  tot <- sort(table(unlist(person_terms)), decreasing = TRUE)
  keep <- head(names(tot)[tot >= min_cell], max_terms)
  terms <- lapply(keep, function(tm) {
    has <- vapply(person_terms, function(x) tm %in% x, logical(1))
    cn <- table(iso3[has & !is.na(iso3)])
    n <- as.integer(cn)
    list(term = tm, total = sum(has),
         countries = data.frame(iso3 = names(cn), n = ifelse(n < min_cell, NA, n), small = n < min_cell, stringsAsFactors = FALSE))
  })
  list(terms = terms, distinct = length(tot), published = length(keep), tot = tot)
}

# Counts members per ISO3 country. Rows whose country is not recognised are reported, not guessed.
members_by_country <- function(countries, lookup, min_cell = 3) {
  blank <- is.na(countries) | !nzchar(trimws(countries))
  iso3 <- lookup$iso3[match(norm_country(countries), lookup$name_norm)]
  iso3[blank] <- NA
  unmatched <- sort(table(trimws(countries[!blank & is.na(iso3)])), decreasing = TRUE)
  tab <- table(iso3[!is.na(iso3)])
  df <- data.frame(iso3 = names(tab), n = as.integer(tab), stringsAsFactors = FALSE)
  df$country <- lookup$country[match(df$iso3, lookup$iso3)]
  df <- df[order(-df$n, df$country), ]
  df$small <- df$n < min_cell
  rownames(df) <- NULL
  list(table = df, total = length(countries), located = sum(df$n), blank = sum(blank),
       unmatched = unmatched, min_cell = min_cell)
}

# Writes site/members.js. Countries with fewer than min_cell members carry no number.
write_members_data <- function(agg, path = "site/members.js", as_of = format(Sys.Date()), facets = NULL) {
  d <- agg$table
  out <- list(as_of = as_of, total = agg$total, located = agg$located, min_cell = agg$min_cell,
              countries = data.frame(iso3 = d$iso3, name = d$country, n = ifelse(d$small, NA, d$n), small = d$small))
  if (length(facets)) out$facets <- facets
  json <- jsonlite::toJSON(out, auto_unbox = TRUE, dataframe = "rows", na = "null", null = "null")
  writeLines(paste0("// Generated by scripts/06_build_member_map_data.R from counts only. Do not edit by hand.\n",
                    "window.IWRS_MEMBERS = ", json, ";"), path, useBytes = TRUE)
}
