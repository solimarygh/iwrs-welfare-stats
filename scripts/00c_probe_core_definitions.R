# Compares candidate definitions of a "core" (strict) set of papers about invertebrate
# welfare / sentience against the broad search, so the choice can be made on evidence:
# for each candidate it prints how many papers it returns (all years) and 10 random titles.
#   source("scripts/00c_probe_core_definitions.R")
# Needs OPENALEX_MAILTO and network access (no API key: one small call per candidate).
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/diagnostics.R")
cfg <- read_config()

tax <- union_terms(cfg, names(cfg$taxa))
nouns <- c("insect", "insects", "invertebrate", "invertebrates", "arthropod", "arthropods",
           "crustacean", "crustaceans", "decapod", "decapods", "cephalopod", "cephalopods")
fill <- function(pat) vapply(nouns, function(n) sub("{n}", n, pat, fixed = TRUE), character(1))
phrases <- unlist(lapply(c("{n} welfare", "welfare of {n}", "{n} sentience", "sentience in {n}"), fill))
prox <- paste0('"', fill("{n} welfare"), '"~6', collapse = " OR ")

f <- function(search) build_filter(cfg, search)
cands <- list(
  "1 BROAD (current): any taxon x any state term"      = f(build_search(tax, all_state_terms(cfg))),
  "2 only the welfare block"                           = f(build_search(tax, state_terms(cfg, "welfare"))),
  "3 only the sentience block"                         = f(build_search(tax, state_terms(cfg, "sentience"))),
  "4 state term must be in the TITLE"                  = paste0(f(or_group(tax)), ",title.search.exact:", or_group(all_state_terms(cfg))),
  "5 explicit phrases (insect welfare, ...)"           = f(or_group(phrases)),
  "6 proximity: \"insects welfare\"~6 and the like"    = f(paste0("(", prox, ")"))
)
for (nm in names(cands)) {
  r <- probe_definition(nm, cands[[nm]], cfg)
  cat("\n==", nm, "\n")
  if (!is.null(r$error)) { cat("   NOT ACCEPTED BY THE API:", r$error, "\n"); next }
  cat("   papers returned (all years):", format(r$count, big.mark = ","), "\n")
  cat(paste0("   - ", r$titles), sep = "\n")
}
