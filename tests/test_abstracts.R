# Offline tests for R/abstracts.R and R/outputs.R.   Rscript tests/test_abstracts.R
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R")
source("R/abstracts.R"); source("R/outputs.R")
cfg <- read_config()
Sys.setenv(OPENALEX_MAILTO = "t@example.org"); on.exit(Sys.unsetenv("OPENALEX_MAILTO"))

# --- markup stripping --------------------------------------------------------
x <- "<jats:p><jats:title>Abstract</jats:title>Insects &amp; crabs may feel pain &#8211; maybe.</jats:p>"
# compared by code point so the test does not depend on the session locale
stopifnot(identical(utf8ToInt(strip_markup(x)),
                    c(utf8ToInt("Insects & crabs may feel pain "), 8211L, utf8ToInt(" maybe."))))
stopifnot(is.na(strip_markup(NA)), is.na(strip_markup(NULL)), is.na(strip_markup("<p> </p>")))
stopifnot(strip_markup("Abstract: We study bees.") == "We study bees.")

# --- DOI encoding ------------------------------------------------------------
stopifnot(encode_doi("10.1000/a#b?c") == "10.1000/a%23b%3Fc", encode_doi("10.1000/x") == "10.1000/x")

# --- recovery with a mock: Crossref -> Europe PMC -> nothing -----------------
long <- paste(rep("Insects and crabs may feel pain.", 5), collapse = " ")
calls <- character()
mock <- function(url, query, mailto) {
  calls <<- c(calls, url)
  if (grepl("crossref", url)) {
    if (grepl("10.1/crossref$", url)) return(list(message = list(abstract = paste0("<jats:p>", long, "</jats:p>"))))
    if (grepl("10.1/short$", url)) return(list(message = list(abstract = "Too short.")))
    return(NULL)
  }
  if (grepl("10.1/pmc", query$query)) return(list(resultList = list(result = list(list(abstractText = long)))))
  list(resultList = list(result = list()))
}
rec <- data.frame(openalex_id = paste0("W", 1:6),
  doi = c("https://doi.org/10.1/crossref", "https://doi.org/10.1/pmc", "https://doi.org/10.1/none",
          "https://doi.org/10.1/short", NA, "https://doi.org/10.1/has"),
  title = "t", abstract = c(NA, NA, NA, NA, NA, "kept abstract"), stringsAsFactors = FALSE)
out <- recover_abstracts(rec, cfg, fetch = mock, cache_path = NULL, progress_every = 1000)
stopifnot(identical(out$abstract_source, c("crossref", "europepmc", NA, NA, NA, "openalex")))
stopifnot(out$abstract[1] == long, is.na(out$abstract[3]), is.na(out$abstract[4]), out$abstract[6] == "kept abstract")
stopifnot(!any(grepl("10.1/has", calls)))                      # records with an abstract are never queried

# --- cache: a second run makes no calls ------------------------------------
tmp <- tempfile(fileext = ".rds"); calls <- character()
recover_abstracts(rec, cfg, fetch = mock, cache_path = tmp, progress_every = 1000)
n1 <- length(calls)
recover_abstracts(rec, cfg, fetch = mock, cache_path = tmp, progress_every = 1000)
stopifnot(n1 > 0, length(calls) == n1)

# --- fidelity and untagged-by-abstract ---------------------------------------
tagged <- tag_records(data.frame(title = c("Pain in crabs", "Heart failure"),
                                 abstract = c("Nociception in the crab", NA), stringsAsFactors = FALSE), cfg)
counts <- data.frame(taxon_group = "crustaceans", state_block = "nociception_pain", n = c(1, 1), year = 2020:2021)
f <- tagging_fidelity(tagged, counts, cfg)
stopifnot(f$api[f$taxon_group == "crustaceans" & f$state_block == "nociception_pain"] == 2,
          f$local[f$taxon_group == "crustaceans" & f$state_block == "nociception_pain"] == 1)
u <- untagged_by_abstract(tagged)
stopifnot(u["TRUE", "TRUE"] == 0, u["FALSE", "TRUE"] == 100)

cat("test_abstracts.R: all checks passed\n")
