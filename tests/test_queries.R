# Offline tests for R/queries.R. Run from the repository root:
#   Rscript tests/test_queries.R
source("R/queries.R")
cfg <- read_config()

stopifnot(quote_term("insect*") == "insect*")
stopifnot(quote_term("honey bee") == '"honey bee"')
stopifnot(quote_term("well-being") == '"well-being"')
stopifnot(or_group(c("a", "b c")) == '(a OR "b c")')
stopifnot(build_search("x", c("y", "z w")) == '(x) AND (y OR "z w")')

# Noisy terms are excluded by default and included on request
stopifnot(!"cricket" %in% taxon_terms(cfg, "insects"))
stopifnot("cricket" %in% taxon_terms(cfg, "insects", include_noisy = TRUE))

# Arthropods are tagged; non-arthropods are not
arth <- arthropod_groups(cfg)
stopifnot(setequal(arth, c("insects", "crustaceans", "other_arthropods", "arthropods_general")))
stopifnot(!"cephalopods" %in% arth)

# Union covers every group
all_terms <- union_terms(cfg, names(cfg$taxa))
stopifnot("octopus*" %in% all_terms, "Drosophila" %in% all_terms, "invertebrate*" %in% all_terms)

# Guard against the wildcard traps documented in the config
stopifnot(!"pain*" %in% state_terms(cfg, "nociception_pain"))
stopifnot(!"affect" %in% all_state_terms(cfg), !"affect*" %in% all_state_terms(cfg))

# No commas inside terms (a comma would split the OpenAlex filter)
stopifnot(!any(grepl(",", c(all_terms, all_state_terms(cfg)))))

# Plurals the exact (non-stemmed) field needs
stopifnot(all(c("bee", "bees") %in% taxon_terms(cfg, "insects")))

# Filter string
f <- build_filter(cfg, build_search("x", "y"))
stopifnot(grepl("from_publication_date:2016-01-01", f), grepl("type:article\\|review", f),
          grepl("title_and_abstract.search.exact:\\(x\\) AND \\(y\\)$", f))

cat("test_queries.R: all checks passed\n")
