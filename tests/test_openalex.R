# Offline test of oa_counts_by_year() with a mock HTTP function.
#   Rscript tests/test_openalex.R
source("R/queries.R"); source("R/openalex.R")
cfg <- read_config(); cfg$project$years <- c(2020, 2023)

# The placeholder address must be rejected; the env var must win over the config
Sys.setenv(OPENALEX_MAILTO = "")
stopifnot(inherits(try(oa_mailto(cfg), silent = TRUE), "try-error"))
Sys.setenv(OPENALEX_MAILTO = "test@example.org")
stopifnot(oa_mailto(cfg) == "test@example.org")

mock <- function(url, query, mailto) {
  stopifnot(grepl("/works$", url), query$group_by == "publication_year")
  list(group_by = list(list(key = "2021", count = 5), list(key = "2023", count = 9),
                       list(key = "1999", count = 77)))   # out-of-window year is ignored
}
d <- oa_counts_by_year(cfg, "x", fetch = mock)
stopifnot(identical(d$year, 2020:2023), identical(d$n, c(0L, 5L, 0L, 9L)))

empty <- function(...) list(group_by = list())
stopifnot(all(oa_counts_by_year(cfg, "x", fetch = empty)$n == 0L))
cat("test_openalex.R: all checks passed\n")
