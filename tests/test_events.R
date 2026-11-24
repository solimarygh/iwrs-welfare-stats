# Offline tests for R/events.R.   Rscript tests/test_events.R
source("R/queries.R"); source("R/records.R"); source("R/events.R")
cfg <- read_config()

# the template's dropdown lists and the lists in R must be the same
if (requireNamespace("readxl", quietly = TRUE) && file.exists("data/templates/IWRS_events_and_theses_template.xlsx")) {
  ls <- suppressMessages(as.data.frame(readxl::read_excel("data/templates/IWRS_events_and_theses_template.xlsx", sheet = "Lists", col_types = "text")))
  for (k in names(events_lists())) stopifnot(identical(as.character(na.omit(ls[[k]])), events_lists()[[k]]))
  ev0 <- suppressMessages(as.data.frame(readxl::read_excel("data/templates/IWRS_events_and_theses_template.xlsx", sheet = "Events", col_types = "text")))
  stopifnot(all(EVENT_REQUIRED %in% names(ev0)), nrow(ev0) == 0)                        # the template ships empty
  th0 <- suppressMessages(as.data.frame(readxl::read_excel("data/templates/IWRS_events_and_theses_template.xlsx", sheet = "Theses", col_types = "text")))
  stopifnot(all(THESIS_REQUIRED %in% names(th0)), nrow(th0) == 0)
}

d <- tempfile(); dir.create(d)
ev <- data.frame(item_type = c("Talk", "talk", "Symposium", "Workshop", "Other event", "Talk", "Talk", "Panel", "Talk", NA, "Talk", "Talk"),
  year = c("2025", "2025", "2025", "2024", "2023", "2025", "abc", "2024", "2025", NA, "2025", "2025"),
  event_name = c("Entomology 2025", "Entomology 2025", "Entomology 2025", "IAFF 2024", "Online workshop", "Entomology 2025", "X", "ICE 2024", "Entomology 2025", NA, "Entomology 2025", "Entomology 2025"),
  venue_type = c("Major conference", "Major conference", "Major conference", "Major conference", "Standalone event", "Major conference", "Major conference", "Major conference", "Major conference", NA, "Major conference", "Major conference"),
  event_series = c("ESA annual meeting", "ESA annual meeting", "ESA annual meeting", "Insects as Food and Feed (IAFF)", "Not applicable", "ESA annual meeting", "ESA annual meeting", "International Congress of Entomology", "Not applicable", NA, "ESA annual meeting", "ESA annual meeting"),
  title = c("Talk A", "Talk B", "Symposium S", "Workshop W", "Event E", "Talk C", "Talk D", "Panel P", "Talk F", NA, "Talk G", "Talk A"),
  topic = c("Welfare", "Sentience", "Welfare and sentience", "Welfare", "Welfare", "Related (pain, cognition, ethics, ...)", "Welfare", "Sentience", "Welfare", NA, "Welfare", "Welfare"),
  notes = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, "contact me at someone@example.org", NA), stringsAsFactors = FALSE)
th <- data.frame(degree = c("PhD", "Master's", "phd", "Doctorate"), year = c("2023", "2023", "2024", "2024"), country = "Brazil", institution = "Univ X",
  title = c("T1", "T2", "T3", "T4"), topic = "Welfare", notes = c(NA, NA, "EXAMPLE, not real", NA), stringsAsFactors = FALSE)
utils::write.csv(ev, file.path(d, "events.csv"), row.names = FALSE); utils::write.csv(th, file.path(d, "theses.csv"), row.names = FALSE)
chk <- check_events(read_events_file(d), this_year = 2026)
p <- chk$problems
# problems carry the spreadsheet row (header = row 1) and the column
stopifnot(any(p$row == 8 & p$column == "year"))                       # "abc"
stopifnot(any(p$row == 12 & p$column == "(any)"))                     # an e-mail address is refused
stopifnot(any(p$row == 12 & p$severity == "error"), any(p$sheet == "Theses" & p$column == "degree"))   # "Doctorate" is not a degree
stopifnot(any(p$severity == "warning" & p$column == "(duplicate)"))   # row 13 repeats row 2 (Talk A twice)
stopifnot(!any(p$row == 12 & p$column == "year"), !any(p$row == 11))            # an empty row is skipped without a complaint
# "talk" and "phd" are accepted in any case and normalised; the EXAMPLE thesis row is skipped
stopifnot(sum(chk$events$item_type == "Talk") >= 3, all(chk$theses$degree %in% c("PhD", "Master's")), !"T3" %in% chk$theses$title)
stopifnot(!"Talk G" %in% chk$events$title)                            # the row with the e-mail is left out of the counts

cnt <- events_counts(chk, 2020:2026)
n <- function(d, y, k) d$n[d$year == y & d$key == k]
stopifnot(n(cnt$talks, 2025, "ESA annual meeting") == 3)              # Talk A, Talk B, and the repeated Talk A; Talk C is 'Related'; Talk F is 'Not applicable' series
stopifnot(n(cnt$talks, 2025, "Not applicable") == 1)
stopifnot(n(cnt$sessions, 2025, "Symposium") == 1, n(cnt$sessions, 2024, "Workshop") == 1, n(cnt$sessions, 2024, "Panel") == 1)
stopifnot(n(cnt$events, 2023, "Other event") == 1, n(cnt$events, 2025, "Talk") == 0 || !"Talk" %in% cnt$events$key)  # talks are not events
stopifnot(n(cnt$theses, 2023, "PhD") == 1, n(cnt$theses, 2023, "Master's") == 1, cnt$related[["events"]] == 1)
stopifnot(all(cnt$talks$year %in% 2020:2026), all(cnt$talks$n >= 0))

tmp <- tempfile(fileext = ".js"); write_events_data(chk, cnt, 2020:2026, tmp, "2026-11-24")
j <- jsonlite::fromJSON(sub(";\\s*$", "", sub("^.*window.IWRS_EVENTS = ", "", paste(readLines(tmp), collapse = "\n"))), simplifyVector = FALSE)
stopifnot(identical(unlist(j$years), 2020:2026), length(j$items) == nrow(chk$events) + nrow(chk$theses))
stopifnot(!any(grepl("@", readLines(tmp))), !"notes" %in% unlist(lapply(j$items, names)))         # notes and personal data never leave
# a missing required column is reported, not guessed
bad <- check_events(list(events = ev[, setdiff(names(ev), "title")], theses = th), 2026)
stopifnot(any(bad$problems$column == "title" & is.na(bad$problems$row)))
cat("test_events.R: all checks passed\n")
