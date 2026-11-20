# Offline test of explain_match() with a mock API.   Rscript tests/test_diagnostics.R
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/diagnostics.R")
cfg <- read_config()
Sys.setenv(OPENALEX_MAILTO = "t@example.org"); on.exit(Sys.unsetenv("OPENALEX_MAILTO"))

mock <- function(url, query, mailto) {
  f <- query$filter
  hit <- grepl("^openalex:W1,", f) && (grepl(":insect\\*$", f) || grepl(":welfare$", f) || grepl(':"honey bee"$', f))
  list(meta = list(count = if (hit) 1 else 0))
}
r <- suppressMessages(capture.output(res <- explain_match(c("https://openalex.org/W1", "W2"), cfg, fetch = mock)))
stopifnot(setequal(names(res), c("W1", "W2")))
stopifnot(setequal(res$W1$taxon, c("insect*", "honey bee")), identical(res$W1$state, "welfare"))
stopifnot(length(res$W2$taxon) == 0, length(res$W2$state) == 0)
cat("test_diagnostics.R: all checks passed\n")
