# Offline tests for R/journals.R.   Rscript tests/test_journals.R
source("R/queries.R"); source("R/records.R"); source("R/journals.R")
cfg <- read_config()
g <- function(x) journal_group_of(x, cfg)
stopifnot(identical(g(c("Nature", "Science", "Proceedings of the National Academy of Sciences", "Nature Communications")), rep("multidisciplinary", 4)))
stopifnot(identical(g(c("Animal Welfare", "Applied Animal Behaviour Science", "Animal Sentience", "Animals")), rep("animal_welfare", 4)))
stopifnot(identical(g(c("Journal of Insect Physiology", "Insects", "American Entomologist", "Journal of Insects as Food and Feed")), rep("entomology", 4)))
stopifnot(identical(g(c("Aquaculture Reports", "Frontiers in Marine Science")), rep("aquaculture", 2)), identical(g("Scientific Reports"), "megajournal"))
# anchors keep "Science of the Total Environment" and "Nature Reviews X" out of the multidisciplinary group
stopifnot(identical(g(c("Science of the Total Environment", NA, "")), rep("other", 3)))
stopifnot(identical(g(c("Toxins", "Cureus", "Clinical Toxicology")), rep("medicine_toxicology", 3)), identical(g(c("Foods", "Food Quality and Preference")), rep("food", 2)))
stopifnot(identical(g(c("Frontiers in Psychology", "Journal of Consciousness Studies")), rep("psychology_philosophy", 2)))
stopifnot(identical(g(c("eLife", "Journal of Experimental Biology", "Frontiers in Physiology", "Biology Letters")), rep("general_biology", 4)))
stopifnot(identical(g("Nature Reviews Neuroscience"), "general_biology"))     # not multidisciplinary: the anchors keep it out of that group
stopifnot(identical(g("Animal Behaviour"), "animal_welfare"), identical(g("Animal Cognition"), "animal_welfare"))   # first group wins over a later one
# a journal matching two groups goes to the first listed: "Insect Science and Veterinary Entomology" -> animal welfare (veterinar)
stopifnot(identical(g("Veterinary Entomology"), "animal_welfare"))

rec <- data.frame(year = c(2020, 2020, 2021, 2021, 2021, 2022), source_name = c("Animal Welfare", "Insects", "Insects", "Biophysical Journal", "Insects", "Nature"),
                  core_any = c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE), taxon_insects = c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE),
                  is_arthropod = c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE), stringsAsFactors = FALSE)
for (tx in names(cfg$taxa)) if (is.null(rec[[paste0("taxon_", tx)]])) rec[[paste0("taxon_", tx)]] <- FALSE
cfg$project$years <- c(2020, 2022)
tb <- journal_tables(rec, cfg)
n_of <- function(t, k, y) tb$by_year$n[tb$by_year$taxon == t & tb$by_year$group == k & tb$by_year$year == y]
stopifnot(n_of("ALL_INVERTEBRATES", "entomology", 2020) == 1, n_of("ALL_INVERTEBRATES", "entomology", 2021) == 1)   # the non-core row is not counted
stopifnot(n_of("ALL_INVERTEBRATES", "other", 2021) == 1, n_of("ALL_INVERTEBRATES", "multidisciplinary", 2022) == 1)
stopifnot(n_of("insects", "entomology", 2021) == 1, n_of("insects", "other", 2021) == 0, n_of("ALL_ARTHROPODS", "animal_welfare", 2020) == 1)
tp <- tb$top[tb$top$taxon == "ALL_INVERTEBRATES", ]
stopifnot(tp$journal[1] == "Insects", sum(tp$counts[[1]]) == 2, !"Insects" %in% tp$journal[-1])
# the file written for the site
tmp <- tempfile(fileext = ".js"); write_journals_data(tb, cfg, tmp)
j <- jsonlite::fromJSON(sub(";\\s*$", "", sub("^.*window.IWRS_JOURNALS = ", "", paste(readLines(tmp), collapse = "\n"))), simplifyVector = FALSE)
stopifnot(identical(unlist(j$years), 2020:2022), "other" %in% vapply(j$groups, function(x) x$key, ""), length(j$top$ALL_INVERTEBRATES) >= 3)
stopifnot(identical(unlist(j$top$ALL_INVERTEBRATES[[1]]$counts), c(0L, 2L, 0L)) || identical(unlist(j$top$ALL_INVERTEBRATES[[1]]$counts), c(1L, 1L, 0L)))
cat("test_journals.R: all checks passed\n")
