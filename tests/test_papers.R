# Offline tests for R/papers.R and fetch_authors().   Rscript tests/test_papers.R
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/journals.R"); source("R/papers.R")
cfg <- read_config()
Sys.setenv(OPENALEX_MAILTO = "test@example.org"); on.exit(Sys.unsetenv("OPENALEX_MAILTO"))

# authors: batches, missing authors, order of names
calls <- 0
mock <- function(url, query, mailto) {
  calls <<- calls + 1
  stopifnot(query$select == "id,authorships", grepl("^openalex:W", query$filter))
  ids <- strsplit(sub("^openalex:", "", query$filter), "|", fixed = TRUE)[[1]]
  list(results = lapply(ids, function(i) list(id = paste0("https://openalex.org/", i),
       authorships = if (i == "W3") list() else list(list(author = list(display_name = paste("Ann", i))), list(author = list(display_name = "Bo Li"))))))
}
a <- fetch_authors(cfg, paste0("https://openalex.org/W", 1:5), fetch = mock, batch = 2, progress = FALSE)
stopifnot(calls == 3, nrow(a) == 5, a$authors[a$openalex_id == "https://openalex.org/W1"] == "Ann W1; Bo Li",
          a$n_authors[a$openalex_id == "https://openalex.org/W3"] == 0, a$authors[a$openalex_id == "https://openalex.org/W3"] == "")

# table of core papers
rec <- data.frame(openalex_id = paste0("https://openalex.org/W", 1:4), doi = c("https://doi.org/10.1/a", NA, "https://doi.org/10.1/c", "https://doi.org/10.1/d"),
                  year = c(2025, 2026, 2026, 2026), title = c("Old", "Bees feel pain", "Crab welfare", "Not core"),
                  source_name = c("Animals", "Animal Sentience", NA, "X"), type = "article", language = "en", cited_by_count = 1:4,
                  is_arthropod = c(TRUE, TRUE, TRUE, FALSE), core_any = c(TRUE, TRUE, TRUE, FALSE), stringsAsFactors = FALSE)
for (g in names(cfg$taxa)) rec[[paste0("taxon_", g)]] <- FALSE
rec$taxon_insects <- c(TRUE, TRUE, FALSE, FALSE); rec$taxon_crustaceans <- c(FALSE, FALSE, TRUE, FALSE)
for (b in names(cfg$core$states)) rec[[paste0("core_", b)]] <- FALSE
rec$core_nociception_pain <- c(FALSE, TRUE, FALSE, FALSE); rec$core_welfare <- c(TRUE, FALSE, TRUE, FALSE)
authors <- data.frame(openalex_id = rec$openalex_id[1:3], authors = c("A A", "B B; C C; D D; E E; F F; G G; H H", ""), stringsAsFactors = FALSE)
tbl <- build_papers_table(rec, authors, cfg)
stopifnot(nrow(tbl) == 3, !"Not core" %in% tbl$title, identical(tbl$year, c(2026, 2026, 2025)))      # newest first, core only
r2 <- tbl[tbl$title == "Bees feel pain", ]
stopifnot(r2$taxa == "insects;ALL_ARTHROPODS", r2$themes == "nociception_pain", r2$journal_group == "animal_welfare")
r3 <- tbl[tbl$title == "Crab welfare", ]
stopifnot(r3$taxa == "crustaceans;ALL_ARTHROPODS", r3$themes == "welfare", is.na(r3$authors) || r3$authors == "")
stopifnot(!"abstract" %in% names(tbl))                                                                # no publisher text

# what the page gets: latest year only, authors cut after 6, no NA
site <- papers_site_data(tbl, 2026, "2026-11-21")
stopifnot(site$year == 2026, nrow(site$items) == 2, !anyNA(site$items))
stopifnot(site$items$authors[site$items$title == "Bees feel pain"] == "B B, C C, D D, E E, F F, G G, et al.")
tmp <- tempfile(fileext = ".js"); write_papers_js(site, tmp)
txt <- readLines(tmp, warn = FALSE)
stopifnot(startsWith(txt[2], "window.IWRS_PAPERS = {"), grepl("\"items\":\\[", txt[2]))
cat("test_papers.R: all checks passed\n")
