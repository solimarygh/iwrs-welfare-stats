# Step 1: publications per year by taxon group x state block.
# Writes data/processed/counts_by_year.csv and a dated snapshot of the
# query strings in data/snapshots/. Run from the repository root:
#   Rscript scripts/01_publication_counts.R
source("R/queries.R")
source("R/openalex.R")
cfg <- read_config()

this_year <- as.integer(format(Sys.Date(), "%Y"))
groups <- names(cfg$taxa)

# Taxon sets: each group, plus the unions
taxon_sets <- c(
  setNames(lapply(groups, taxon_terms, cfg = cfg), groups),
  list(ALL_ARTHROPODS = union_terms(cfg, arthropod_groups(cfg)),
       ALL_INVERTEBRATES = union_terms(cfg, groups))
)
arth_sets <- c(arthropod_groups(cfg), "ALL_ARTHROPODS")

# State sets: each block, the union (ANY) and "none" (denominator: all works on the taxon)
state_sets <- c(setNames(lapply(names(cfg$states), state_terms, cfg = cfg), names(cfg$states)),
                list(ANY = all_state_terms(cfg), NONE = NULL))

rows <- list(); queries <- list()
for (tx in names(taxon_sets)) {
  for (st in names(state_sets)) {
    search <- if (is.null(state_sets[[st]])) or_group(taxon_sets[[tx]])
              else build_search(taxon_sets[[tx]], state_sets[[st]])
    filter <- build_filter(cfg, search)
    message(sprintf("[%s x %s]", tx, st))
    d <- oa_counts_by_year(cfg, filter)
    rows[[length(rows) + 1]] <- cbind(taxon_group = tx, is_arthropod = tx %in% arth_sets,
                                      state_block = st, d)
    queries[[length(queries) + 1]] <- list(taxon_group = tx, state_block = st,
                                           search = search, n_chars = nchar(search))
  }
}
counts <- do.call(rbind, rows)
counts$partial_year <- counts$year == this_year

# Reference: every work in the window with the same type/source filter (no topic)
all_works <- oa_counts_by_year(cfg, build_filter(cfg))
names(all_works)[2] <- "n_all_works"
counts <- merge(counts, all_works, by = "year")

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
dir.create("data/snapshots", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(counts, "data/processed/counts_by_year.csv", row.names = FALSE)
jsonlite::write_json(
  list(run_date = format(Sys.Date()), years = cfg$project$years,
       include_noisy = isTRUE(cfg$search$include_noisy), queries = queries),
  sprintf("data/snapshots/queries_%s.json", format(Sys.Date())),
  auto_unbox = TRUE, pretty = TRUE)
message("Done: ", nrow(counts), " rows")
