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
stopifnot(!"cricket*" %in% taxon_terms(cfg, "insects"))
stopifnot("cricket*" %in% taxon_terms(cfg, "insects", include_noisy = TRUE))

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

# --- core definition ---------------------------------------------------------------
cfg <- read_config()
ph <- core_phrases(cfg, "welfare")
stopifnot(length(ph) == length(cfg$core$taxon_nouns) * length(cfg$core$states$welfare))
stopifnot('"insects welfare"~6' %in% ph, all(grepl('^"[a-z]+ [a-z]+"~6$', ph)))
stopifnot(!anyDuplicated(ph), !any(grepl(",", ph)))
stopifnot(all(!grepl("~", core_phrases(cfg, "welfare", proximity = 0))))             # adjacency variant
stopifnot(inherits(try(core_phrases(cfg, "dragons"), silent = TRUE), "try-error"))
all_core <- build_core_search(cfg)
stopifnot(startsWith(all_core, "("), endsWith(all_core, ")"), grepl('"crabs sentient"~6', all_core, fixed = TRUE))
# every noun and every state word is a single token, as the phrase syntax needs
stopifnot(!any(grepl("[[:space:]]", unlist(cfg$core$taxon_nouns))), !any(grepl("[[:space:]]", unlist(cfg$core$states))))
cat("core checks passed\n")
