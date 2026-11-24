# Step 8: counts of talks, symposia, events and theses per year, from the template IWRS fills in.
#   source("scripts/08_build_events_data.R")
# Reads the file named in config/config.yml (events.file; default data/curated/IWRS_events_and_theses.xlsx),
# checks every row (values from the dropdown lists, valid years, no e-mail addresses), prints the
# problems with their spreadsheet row, and writes site/events.js and data/processed/events_by_year.csv.
source("R/queries.R"); source("R/records.R"); source("R/events.R")
cfg <- read_config()
years <- seq(cfg$project$years[1], cfg$project$years[2])

raw <- read_events_file(cfg$events$file)
chk <- check_events(raw)
if (nrow(chk$problems)) {
  message("Problems found (row = row in the spreadsheet):")
  print(chk$problems, row.names = FALSE)
}
if (any(chk$problems$severity == "error"))
  message("\nRows with errors were left out of the counts. Fix them in the spreadsheet and run this script again.")
cnt <- events_counts(chk, years)

all <- rbind(cbind(stat = "talks at major conferences", cnt$talks), cbind(stat = "symposia, workshops and panels at major conferences", cnt$sessions),
             cbind(stat = "academic events of any kind", cnt$events), cbind(stat = "theses", cnt$theses))
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(all, "data/processed/events_by_year.csv", row.names = FALSE)
write_events_data(chk, cnt, years)

tot <- tapply(all$n, all$stat, sum)
message("\nCounted (on topic, ", years[1], "-", years[length(years)], "):"); print(tot)
message("Rows marked 'Related' (kept in the list, not counted): ", cnt$related[["events"]], " events, ", cnt$related[["theses"]], " theses")
message("Wrote site/events.js and data/processed/events_by_year.csv")
