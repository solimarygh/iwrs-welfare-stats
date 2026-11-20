# Offline test of R/site.R.   Rscript tests/test_site_data.R
source("R/site.R")
mk <- function(tx, arth) expand.grid(taxon_group = tx, state_block = c("welfare", "ANY", "NONE"),
                                     year = 2024:2026, stringsAsFactors = FALSE)
cnt <- rbind(cbind(mk("insects"), is_arthropod = TRUE), cbind(mk("cephalopods"), is_arthropod = FALSE),
             cbind(mk("ALL_INVERTEBRATES"), is_arthropod = FALSE))
cnt$n <- seq_len(nrow(cnt)); cnt$partial_year <- cnt$year == 2026; cnt$n_all_works <- cnt$year * 10
d <- build_site_data(cnt, "2026-10-01")
stopifnot(d$meta$first_year == 2024, d$meta$last_year == 2026, d$meta$partial_year == 2026)
stopifnot(identical(d$taxa$key, c("ALL_INVERTEBRATES", "insects", "cephalopods")))   # fixed display order
stopifnot(identical(d$taxa$arthropod, c(FALSE, TRUE, FALSE)), nrow(d$rows) == nrow(cnt))
stopifnot(identical(d$all_works$n, c(20240L, 20250L, 20260L)) || all(d$all_works$n == c(20240, 20250, 20260)))

# no partial year -> field is null; unknown group is refused
cnt2 <- cnt; cnt2$partial_year <- FALSE
stopifnot(is.null(build_site_data(cnt2, "x")$meta$partial_year))
bad <- cnt; bad$taxon_group[1] <- "dragons"
stopifnot(inherits(try(build_site_data(bad, "x"), silent = TRUE), "try-error"))

# the written file is valid JS that wraps valid JSON
tmp <- tempfile(fileext = ".js"); write_site_data(d, tmp)
txt <- paste(readLines(tmp), collapse = "\n")
stopifnot(grepl("window.IWRS_DATA = ", txt, fixed = TRUE))
j <- jsonlite::fromJSON(sub(";\\s*$", "", sub("^.*window.IWRS_DATA = ", "", txt)))
stopifnot(identical(j$meta$run_date, "2026-10-01"), nrow(j$rows) == nrow(cnt), is.logical(j$taxa$arthropod))
cat("test_site_data.R: all checks passed\n")
