# Offline tests for R/members.R.   Rscript tests/test_members.R
source("R/queries.R"); source("R/records.R"); source("R/members.R")
cfg <- read_config(); lk <- read_country_lookup()

# normalisation (same result in any session locale)
stopifnot(norm_country("U.S.A.") == "u s a", norm_country("  Costa-Rica ") == "costa rica", is.na(norm_country(NA)))
u <- function(...) intToUtf8(c(...))      # non-ASCII text built from code points, so the test does not depend on the locale
stopifnot(norm_country(paste0("M", u(233), "xico")) == "mexico", norm_country(paste0("Espa", u(241), "a")) == "espana",
          norm_country(paste0("S", u(227), "o Tom", u(233))) == "sao tome")

# lookup: names in three languages and common aliases map to ISO3
ids <- function(x) lk$iso3[match(norm_country(x), lk$name_norm)]
stopifnot(identical(ids(c("Brazil", "Brasil", "BRAZIL", "BRA", "br")), rep("BRA", 5)))
stopifnot(identical(ids(c("USA", "United States", "United States of America", "EE.UU.", "Estados Unidos")), rep("USA", 5)))
stopifnot(identical(ids(c("UK", "England", "Reino Unido", "United Kingdom")), rep("GBR", 4)))
stopifnot(identical(ids(c("Spain", paste0("Espa", u(241), "a"), "Espanha")), rep("ESP", 3)), is.na(ids("Atlantis")))

# aggregation: counts, small cells, blanks and unrecognised spellings reported not guessed
x <- c(rep("Brazil", 5), "Brasil", rep("USA", 2), "Chile", NA, "", "Atlantis", "Atlantis", "  ")
a <- members_by_country(x, lk, min_cell = 3)
tb <- a$table
stopifnot(tb$iso3[1] == "BRA", tb$n[1] == 6, !tb$small[1])
stopifnot(all(tb$small[tb$iso3 %in% c("USA", "CHL")]), a$located == 9, a$blank == 3, a$total == 14)
stopifnot(identical(names(a$unmatched), "Atlantis"), unname(a$unmatched) == 2)

# the file written for the site carries no number for small countries
tmp <- tempfile(fileext = ".js"); write_members_data(a, tmp, as_of = "2026-11-21")
txt <- paste(readLines(tmp), collapse = "\n")
j <- jsonlite::fromJSON(sub(";\\s*$", "", sub("^.*window.IWRS_MEMBERS = ", "", txt)))
stopifnot(j$total == 14, j$min_cell == 3, j$as_of == "2026-11-21")
stopifnot(!is.na(j$countries$n[j$countries$iso3 == "BRA"]), is.na(j$countries$n[j$countries$iso3 == "CHL"]))
stopifnot(identical(sort(names(j$countries)), c("iso3", "n", "name", "small")))     # nothing else leaves the list

# reading: the country column is found by its header, or must be named
csv <- tempfile(fileext = ".csv")
writeLines(c("ID,Country of residence,Institution", "1,Brazil,X", "2,Chile,Y"), csv)
stopifnot(identical(read_member_countries(csv, cfg), c("Brazil", "Chile")))
writeLines(c("ID,Country,Country of birth", "1,Brazil,Peru"), csv)
stopifnot(inherits(try(read_member_countries(csv, cfg), silent = TRUE), "try-error"))      # ambiguous
cfg2 <- cfg; cfg2$members$country_column <- "Country"
stopifnot(identical(read_member_countries(csv, cfg2), "Brazil"))
writeLines(c("ID,Name", "1,Ana"), csv)
msg <- tryCatch(read_member_countries(csv, cfg), error = function(e) conditionMessage(e))
stopifnot(grepl('"ID", "Name"', msg, fixed = TRUE), !grepl("Ana", msg))                    # only headers are shown
stopifnot(inherits(try(read_member_countries("nope.xlsx", cfg), silent = TRUE), "try-error"))
cat("test_members.R: all checks passed\n")
