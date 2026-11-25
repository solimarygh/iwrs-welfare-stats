# Step 9: the list of core papers with their authors, for the page and for download.
#   source("scripts/09_build_papers.R")
# Needs the records of step 2 (data/raw/records_*.rds, with the filters of step 2c) and the OpenAlex API
# (OPENALEX_MAILTO and OPENALEX_API_KEY): authors are not part of the downloaded records, so they are
# fetched here, 100 papers per call (about 13 calls). Abstracts are NOT written anywhere: they are
# publisher text. Each paper links to its source through the DOI.
# Writes data/processed/core_papers.csv (tracked), site/papers.js (the papers of the latest year, for the page)
# and site/downloads/*.csv (the files the page offers for download).
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/journals.R"); source("R/papers.R")
cfg <- read_config()
if (!nzchar(oa_api_key())) stop("Set OPENALEX_API_KEY in ~/.Renviron (see README).", call. = FALSE)

files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
if (length(files) == 0) stop("Run scripts/02_fetch_records.R first.")
rec <- readRDS(files[length(files)])
if (is.null(rec$keep_welfare)) stop("Run scripts/02c_fetch_topics.R first: the records carry the old core.", call. = FALSE)
message("Using ", files[length(files)], ": ", sum(rec$core_any), " core papers")

authors <- fetch_authors(cfg, rec$openalex_id[rec$core_any])
message(sprintf("Authors found for %d of %d papers", sum(nzchar(authors$authors)), sum(rec$core_any)))
tbl <- build_papers_table(rec, authors, cfg)
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(tbl, "data/processed/core_papers.csv", row.names = FALSE, na = "", fileEncoding = "UTF-8")

snaps <- sort(list.files("data/snapshots", "^queries_.*\\.json$", full.names = TRUE))
run_date <- jsonlite::read_json(snaps[length(snaps)])$run_date
latest <- max(tbl$year)
write_papers_js(papers_site_data(tbl, latest, run_date))
message("site/papers.js: ", sum(tbl$year == latest), " papers of ", latest)

dir.create("site/downloads", showWarnings = FALSE, recursive = TRUE)
for (f in c("core_papers.csv", "core_counts_by_year.csv", "journals_by_year.csv", "journals_top.csv"))
  if (file.exists(file.path("data/processed", f))) file.copy(file.path("data/processed", f), file.path("site/downloads", f), overwrite = TRUE)
message("Copied the downloadable files to site/downloads/. Commit data/processed, site/papers.js and site/downloads/.")
