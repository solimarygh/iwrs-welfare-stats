# Step 7: where the core papers are published (groups of journals, per year and taxon group).
#   source("scripts/07_journal_distribution.R")
# Reads data/raw/... is NOT needed: it uses data/processed/records_meta.csv, which holds the
# journal and the core flags. Edit the journal groups in config/config.yml (`journals:`).
source("R/queries.R"); source("R/records.R"); source("R/journals.R")
cfg <- read_config()

rec <- utils::read.csv("data/processed/records_meta.csv", stringsAsFactors = FALSE)
if (!"core_any" %in% names(rec)) stop("records_meta.csv has no core flags: run scripts/02_fetch_records.R first.")
tabs <- journal_tables(rec, cfg)

utils::write.csv(tabs$by_year, "data/processed/journals_by_year.csv", row.names = FALSE)
top <- tabs$top[tabs$top$taxon == "ALL_INVERTEBRATES", c("journal", "group")]
top$core_papers <- vapply(tabs$top$counts[tabs$top$taxon == "ALL_INVERTEBRATES"], sum, 1)
utils::write.csv(top, "data/processed/journals_top.csv", row.names = FALSE)
write_journals_data(tabs, cfg)

tot <- tapply(tabs$by_year$n[tabs$by_year$taxon == "ALL_INVERTEBRATES"], tabs$by_year$group[tabs$by_year$taxon == "ALL_INVERTEBRATES"], sum)
lab <- journal_group_labels(cfg)
message("Core papers by journal group (all years, all invertebrates):")
print(data.frame(group = unname(lab[names(tot)]), papers = as.integer(tot), pct = round(100 * as.integer(tot) / sum(tot), 1))[order(-tot), ], row.names = FALSE)
message("\nMost frequent journals of the core that fall in 'other' (to decide whether a group is missing):")
print(head(top[top$group == "other", ], 15), row.names = FALSE)
message("Wrote data/processed/journals_by_year.csv, journals_top.csv and site/journals.js")
