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

write_records_outputs <- function(rec, cfg, counts_path = "data/processed/counts_by_year.csv") {
  dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
  meta <- rec[, setdiff(names(rec), c("title", "abstract"))]
  meta$has_abstract <- !is.na(rec$abstract)
  meta$run_date <- format(Sys.Date())
  utils::write.csv(meta, "data/processed/records_meta.csv", row.names = FALSE)
  fid <- tagging_fidelity(rec, utils::read.csv(counts_path), cfg)
  utils::write.csv(fid, "data/processed/tagging_fidelity.csv", row.names = FALSE)
  message("Records with an abstract: ", round(100 * mean(!is.na(rec$abstract)), 1), "%")
  message("Local tags / API counts (1.000 = identical):")
  print(summary(fid$ratio))
  message("Records no local tag explains (%), by whether an abstract exists:")
  print(untagged_by_abstract(rec))
  invisible(fid)
}
