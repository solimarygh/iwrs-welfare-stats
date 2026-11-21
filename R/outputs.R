# Summary tables written after the record download / abstract recovery.

# For each taxon group x state block: records tagged locally vs the API count
# from step 1 (all years). 1.000 = identical.
tagging_fidelity <- function(rec, counts, cfg) {
  do.call(rbind, lapply(names(cfg$taxa), function(g) do.call(rbind, lapply(names(cfg$states), function(b) {
    api <- sum(counts$n[counts$taxon_group == g & counts$state_block == b])
    loc <- sum(rec[[paste0("taxon_", g)]] & rec[[paste0("state_", b)]])
    data.frame(taxon_group = g, state_block = b, api = api, local = loc,
               ratio = ifelse(api > 0, round(loc / api, 3), NA))
  }))))
}

# Percentage of records that no local tag explains, split by whether an abstract exists.
untagged_by_abstract <- function(rec) {
  tx <- grep("^taxon_", names(rec), value = TRUE); st <- grep("^state_", names(rec), value = TRUE)
  untagged <- !Reduce(`|`, rec[tx]) | !Reduce(`|`, rec[st])
  round(100 * prop.table(table(has_abstract = !is.na(rec$abstract), untagged = untagged), 1), 1)
}

# Core (strict) counts per year: taxon group x block, plus "ANY" (any block) and "BROAD"
# (every record the broad search retrieved), taken from the tagged records.
core_counts_by_year <- function(rec, cfg, this_year = as.integer(format(Sys.Date(), "%Y"))) {
  years <- seq(cfg$project$years[1], cfg$project$years[2])
  blocks <- c(names(cfg$core$states), "ANY", "BROAD")
  bflag <- function(b) switch(b, ANY = rec$core_any, BROAD = rep(TRUE, nrow(rec)), rec[[paste0("core_", b)]])
  groups <- c(names(cfg$taxa), "ALL_ARTHROPODS", "ALL_INVERTEBRATES")
  gflag <- function(g) switch(g, ALL_ARTHROPODS = rec$is_arthropod, ALL_INVERTEBRATES = rep(TRUE, nrow(rec)),
                              rec[[paste0("taxon_", g)]])
  arth <- c(vapply(cfg$taxa, function(x) isTRUE(x$arthropod), logical(1)), ALL_ARTHROPODS = TRUE, ALL_INVERTEBRATES = FALSE)
  do.call(rbind, lapply(groups, function(g) do.call(rbind, lapply(blocks, function(b) {
    sel <- gflag(g) & bflag(b)
    data.frame(taxon_group = g, is_arthropod = unname(arth[g]), state_block = b, year = years,
               n = tabulate(match(rec$year[sel], years), nbins = length(years)),
               partial_year = years == this_year, stringsAsFactors = FALSE)
  }))))
}

write_records_outputs <- function(rec, cfg, counts_path = "data/processed/counts_by_year.csv") {
  dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
  meta <- rec[, setdiff(names(rec), c("title", "abstract"))]
  meta$has_abstract <- !is.na(rec$abstract)
  meta$run_date <- format(Sys.Date())
  utils::write.csv(meta, "data/processed/records_meta.csv", row.names = FALSE)
  fid <- tagging_fidelity(rec, utils::read.csv(counts_path), cfg)
  utils::write.csv(fid, "data/processed/tagging_fidelity.csv", row.names = FALSE)
  cc <- core_counts_by_year(rec, cfg)
  utils::write.csv(cc, "data/processed/core_counts_by_year.csv", row.names = FALSE)
  tot <- cc[cc$taxon_group == "ALL_INVERTEBRATES", ]
  message("Core vs broad (all invertebrates, all years):")
  print(tapply(tot$n, tot$state_block, sum))
  message("Records with an abstract: ", round(100 * mean(!is.na(rec$abstract)), 1), "%")
  message("Local tags / API counts (1.000 = identical):")
  print(summary(fid$ratio))
  message("Records no local tag explains (%), by whether an abstract exists:")
  print(untagged_by_abstract(rec))
  invisible(fid)
}
