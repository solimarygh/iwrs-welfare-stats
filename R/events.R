# Events and theses: read the template that IWRS fills in, check every row, count per year.
# The template is built by tools/build_events_template.py; its dropdown lists are mirrored here.

events_lists <- function() list(
  item_type = c("Talk", "Symposium", "Workshop", "Panel", "Other event"),
  venue_type = c("Major conference", "Other conference", "Standalone event"),
  event_series = c("ESA annual meeting", "International Congress of Entomology", "Insects as Food and Feed (IAFF)",
                   "Other major conference", "Not applicable"),
  taxon_scope = c("Insects", "Crustaceans", "Cephalopods", "Other invertebrates", "Invertebrates (general)", "Multiple groups"),
  topic = c("Welfare", "Sentience", "Welfare and sentience", "Related (pain, cognition, ethics, ...)"),
  format = c("In person", "Online", "Hybrid"),
  degree = c("PhD", "Master's"))

EVENT_REQUIRED  <- c("item_type", "year", "event_name", "venue_type", "title", "topic")
THESIS_REQUIRED <- c("degree", "year", "country", "institution", "title", "topic")
ON_TOPIC <- c("Welfare", "Sentience", "Welfare and sentience")      # "Related" rows are kept but not counted

# Reads sheets "Events" and "Theses" of the xlsx (or events.csv and theses.csv in a folder).
read_events_file <- function(path) {
  rd <- function(sheet, csv) {
    if (dir.exists(path)) return(utils::read.csv(file.path(path, csv), stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8", colClasses = "character"))
    if (!requireNamespace("readxl", quietly = TRUE)) stop("Install readxl: install.packages(\"readxl\")", call. = FALSE)
    as.data.frame(readxl::read_excel(path, sheet = sheet, col_types = "text"), stringsAsFactors = FALSE)
  }
  if (!file.exists(path)) stop("File not found: ", path, "\nSave the filled template there (see data/templates/).", call. = FALSE)
  list(events = rd("Events", "events.csv"), theses = rd("Theses", "theses.csv"))
}

# Checks one sheet. Returns the cleaned rows (values as in the lists) and a table of problems.
check_sheet <- function(df, sheet, required, lists, years, this_year) {
  prob <- data.frame(sheet = character(), row = integer(), column = character(), message = character(),
                     severity = character(), stringsAsFactors = FALSE)
  add <- function(row, col, msg, sev = "error") prob[nrow(prob) + 1, ] <<- list(sheet, row, col, msg, sev)
  names(df) <- trimws(names(df))
  miss <- setdiff(required, names(df))
  if (length(miss)) { add(NA, paste(miss, collapse = ", "), "required column(s) missing: do not rename or delete columns of the template"); return(list(rows = df[0, ], problems = prob)) }
  df[] <- lapply(df, function(x) trimws(as.character(x)))
  empty <- rowSums(!is.na(df) & nzchar(as.matrix(df))) == 0
  keep <- !empty & !startsWith(toupper(ifelse(is.na(df$notes), "", df$notes)), "EXAMPLE")
  df$.row <- seq_len(nrow(df)) + 1L                     # the row number in the spreadsheet
  df <- df[keep, , drop = FALSE]
  ok <- rep(TRUE, nrow(df))
  for (i in seq_len(nrow(df))) {
    r <- df$.row[i]
    for (cl in required) if (is.na(df[[cl]][i]) || !nzchar(df[[cl]][i])) { add(r, cl, "is empty"); ok[i] <- FALSE }
    for (cl in intersect(names(lists), names(df))) {
      v <- df[[cl]][i]; if (is.na(v) || !nzchar(v)) next
      m <- match(tolower(v), tolower(lists[[cl]]))
      if (is.na(m)) { add(r, cl, sprintf("'%s' is not in the list; pick one of: %s", v, paste(lists[[cl]], collapse = " | "))); ok[i] <- FALSE }
      else df[[cl]][i] <- lists[[cl]][m]
    }
    y <- suppressWarnings(as.integer(df$year[i]))
    if (!is.na(df$year[i]) && nzchar(df$year[i]) && (is.na(y) || y < 1990 || y > this_year + 1)) { add(r, "year", sprintf("'%s' is not a year between 1990 and %d", df$year[i], this_year + 1)); ok[i] <- FALSE }
    if (any(grepl("[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[a-z]{2,}", unlist(df[i, setdiff(names(df), ".row")]), ignore.case = TRUE)))
      { add(r, "(any)", "looks like an e-mail address: remove personal data"); ok[i] <- FALSE }
  }
  df$year <- suppressWarnings(as.integer(df$year))
  list(rows = df[ok, , drop = FALSE], problems = prob)
}

check_events <- function(raw, this_year = as.integer(format(Sys.Date(), "%Y"))) {
  l <- events_lists()
  e <- check_sheet(raw$events, "Events", EVENT_REQUIRED, l, NULL, this_year)
  t <- check_sheet(raw$theses, "Theses", THESIS_REQUIRED, l, NULL, this_year)
  ev <- e$rows; th <- t$rows; prob <- rbind(e$problems, t$problems)
  warn <- function(df, sheet, key) {
    d <- which(duplicated(df[key]) | duplicated(df[key], fromLast = TRUE))
    if (length(d)) prob[nrow(prob) + seq_along(d), ] <<- data.frame(sheet = sheet, row = df$.row[d], column = "(duplicate)",
        message = "same entry appears more than once: keep one", severity = "warning", stringsAsFactors = FALSE)
  }
  if (nrow(ev)) {
    warn(ev, "Events", c("item_type", "year", "event_name", "title"))
    bad <- ev$venue_type == "Major conference" & ev$event_series == "Not applicable" & !is.na(ev$event_series)
    if (any(bad)) prob[nrow(prob) + seq_len(sum(bad)), ] <- data.frame(sheet = "Events", row = ev$.row[bad], column = "event_series",
      message = "a major conference should name its series (or 'Other major conference')", severity = "warning", stringsAsFactors = FALSE)
  }
  if (nrow(th)) warn(th, "Theses", c("degree", "year", "institution", "title"))
  list(events = ev, theses = th, problems = prob)
}

# Counts per year. Only rows on topic (welfare, sentience, or both) are counted.
events_counts <- function(chk, years) {
  ev <- chk$events[chk$events$topic %in% ON_TOPIC, , drop = FALSE]; th <- chk$theses[chk$theses$topic %in% ON_TOPIC, , drop = FALSE]
  by <- function(d, key, levels) {
    if (!nrow(d)) return(data.frame(year = integer(), key = character(), n = integer(), stringsAsFactors = FALSE))
    tb <- as.data.frame(table(year = factor(d$year, levels = years), key = factor(d[[key]], levels = levels)), stringsAsFactors = FALSE)
    data.frame(year = as.integer(tb$year), key = tb$key, n = tb$Freq, stringsAsFactors = FALSE)
  }
  l <- events_lists(); major <- ev$venue_type == "Major conference"
  list(talks = by(ev[ev$item_type == "Talk" & major, ], "event_series", l$event_series),
       sessions = by(ev[ev$item_type %in% c("Symposium", "Workshop", "Panel") & major, ], "item_type", c("Symposium", "Workshop", "Panel")),
       events = by(ev[ev$item_type != "Talk", ], "item_type", setdiff(l$item_type, "Talk")),
       theses = by(th, "degree", l$degree),
       related = c(events = sum(!chk$events$topic %in% ON_TOPIC), theses = sum(!chk$theses$topic %in% ON_TOPIC)))
}

write_events_data <- function(chk, counts, years, path = "site/events.js", as_of = format(Sys.Date())) {
  pub <- function(d) lapply(seq_len(nrow(d)), function(i) list(year = d$year[i], key = d$key[i], n = d$n[i]))
  keep_url <- function(u) {                              # a link only if there is one and it is a web address
    if (is.null(u) || length(u) != 1 || is.na(u)) return(NULL)
    if (grepl("^https?://", u)) u else NULL
  }
  items <- c(lapply(seq_len(nrow(chk$events)), function(i) { r <- chk$events[i, ]
      list(kind = "event", year = r$year, type = r$item_type, name = r$event_name, title = r$title, topic = r$topic, url = keep_url(r$source_url)) }),
    lapply(seq_len(nrow(chk$theses)), function(i) { r <- chk$theses[i, ]
      list(kind = "thesis", year = r$year, type = r$degree, name = r$institution, title = r$title, topic = r$topic, url = keep_url(r$repository_url)) }))
  out <- list(as_of = as_of, years = years, talks = pub(counts$talks), sessions = pub(counts$sessions), events = pub(counts$events),
              theses = pub(counts$theses), items = items)
  json <- jsonlite::toJSON(out, auto_unbox = TRUE, null = "null", digits = NA)
  writeLines(paste0("// Generated by scripts/08_build_events_data.R from the template filled by IWRS. Do not edit by hand.\n",
                    "window.IWRS_EVENTS = ", json, ";"), path, useBytes = TRUE)
}
