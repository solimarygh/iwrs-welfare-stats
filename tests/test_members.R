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

# ============ filters: free-text expertise columns ============================================
source("R/members.R")
stopifnot(identical(split_terms(c("Entomology, Welfare science", "philosophy and ethics; N/A", NA, "", "None"))[[1]], c("entomology", "welfare science")))
st <- split_terms(c("Entomology, Welfare science", "philosophy and ethics; N/A", NA, "", "None"))
stopifnot(identical(st[[2]], c("philosophy", "ethics")), length(st[[3]]) == 0, length(st[[4]]) == 0, length(st[[5]]) == 0)
stopifnot(length(split_terms("N/A")[[1]]) == 0, identical(split_terms("ethology, n/a")[[1]], "ethology"))
stopifnot(identical(split_terms("  Honey Bees / 'Bumble bees'. ")[[1]], c("honey bees", "bumble bees")))

# duplicated headers are merged per person; aliases unite spellings; an empty canonical drops a term
df <- data.frame(ID = 1:8, Country = c("Brazil", "Brazil", "Brazil", "Chile", "Chile", "Chile", "Chile", "Atlantis"),
                 `General Discipline` = c("Entomology", "entomology", "Entomologist", "Ethology", "Welfare science", NA, "Philosophy", "Entomology"),
                 `Species-Specific Expertise` = c("Apis mellifera", "apis mellifera", NA, "Octopus vulgaris", NA, NA, NA, NA),
                 `General Discipline` = c(NA, NA, "Animal welfare", NA, "Animal welfare", "animal welfare", "x", NA),
                 check.names = FALSE, stringsAsFactors = FALSE)
al <- data.frame(term = c("entomologist", "welfare science", "x"), canonical = c("entomology", "animal welfare", ""), stringsAsFactors = FALSE)
pt <- member_terms(df, "General Discipline", al)
stopifnot(identical(sort(pt[[3]]), c("animal welfare", "entomology")), identical(pt[[5]], "animal welfare"), identical(pt[[7]], "philosophy"))
stopifnot(identical(pt[[5]], "animal welfare"))      # "welfare science" and "Animal welfare" in one person count once
stopifnot(length(facet_columns(df, "General Discipline")) == 2)
stopifnot(inherits(try(member_terms(df, "Nonexistent", al), silent = TRUE), "try-error"))

iso <- ids(df$Country)
fc <- facet_counts(pt, iso, min_cell = 3)
tm <- vapply(fc$terms, function(x) x$term, "")
stopifnot(setequal(tm, c("entomology", "animal welfare")))               # others have fewer than 3 members: not published
e <- fc$terms[[match("entomology", tm)]]
stopifnot(e$total == 4, e$countries$n[e$countries$iso3 == "BRA"] == 3, e$countries$small[e$countries$iso3 == "BRA"] == FALSE)
stopifnot(is.na(e$countries$n[e$countries$iso3 == "ATL" | is.na(e$countries$iso3)]) || !any(is.na(e$countries$iso3)))
w <- fc$terms[[match("animal welfare", tm)]]
stopifnot(w$total == 3, all(w$countries$small), all(is.na(w$countries$n)))     # 3 members in total, 1 in Brazil and 2 in Chile: no country reaches 3, so no number
sp <- facet_counts(member_terms(df, "Species-Specific", al), iso, min_cell = 3)
stopifnot(length(sp$terms) == 0)                                              # a species stated by 2 members is never published

# what is written for the site never carries a small number nor a rare term
a2 <- members_by_country(df$Country, lk, 3)
tmp2 <- tempfile(fileext = ".js")
write_members_data(a2, tmp2, facets = list(discipline = list(label = "General discipline", terms = fc$terms)))
j2 <- jsonlite::fromJSON(sub(";\\s*$", "", sub("^.*window.IWRS_MEMBERS = ", "", paste(readLines(tmp2), collapse = "\n"))), simplifyVector = FALSE)
stopifnot(identical(names(j2$facets), "discipline"), length(j2$facets$discipline$terms) == 2)
all_n <- unlist(lapply(j2$facets$discipline$terms, function(t) lapply(t$countries, function(cn) cn$n)))
stopifnot(all(unlist(all_n) >= 3), all(vapply(j2$facets$discipline$terms, function(t) t$total >= 3, logical(1))))
cat("test_members.R (filters): all checks passed\n")

# ============ the real headers of the IWRS membership form (headers only, no data) ==========================
hd <- c("Institutional Affiliation", "Membership Type",
        "General Discipline (e.g., entomology, philosophy, economics, welfare science, comparative cognition)",
        "Research Interest Keywords (e.g., farmed insect welfare, ethology, animal ethics)",
        "Taxonomic Expertise (Order level)", "Species-Specific Expertise", "Are you interested in being contacted by others about:",
        "General Discipline (e.g., entomology, philosophy, economics, welfare science, comparative cognition)",
        "Research Interest Keywords (e.g., farmed insect welfare, ethology, animal ethics)",
        "Taxonomic Expertise (Order level)", "Species-Specific Expertise", "Do you wish to be contacted about:",
        "May we share your privately-stored email with third parties that wish to contact you about the above?",
        "Country", "Rank (e.g., Associate Professor)", "Department")
real <- as.data.frame(matrix("x", nrow = 1, ncol = length(hd), dimnames = list(NULL, hd)), check.names = FALSE, stringsAsFactors = FALSE)
real$Country <- "Brazil"
stopifnot(identical(country_of(real, cfg), "Brazil"))                           # one column mentions a country
for (key in names(cfg$members$facets)) {
  cols <- facet_columns(real, unlist(cfg$members$facets[[key]]$headers))
  stopifnot(length(cols) == 2)                                                  # each filter merges its two duplicated columns
}
# nothing outside the country and the four filters is ever read
used <- unlist(lapply(cfg$members$facets, function(f) facet_columns(real, unlist(f$headers))))
stopifnot(!any(grepl("contact|email|Institution|Rank|Department|Membership", names(real)[used], ignore.case = TRUE)))
cat("test_members.R (real headers): all checks passed\n")
