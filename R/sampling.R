# Stratified validation sample (see `sampling` in config/config.yml).

# Give `n` slots to strata of the given sizes, one per pass, smallest strata
# first, never exceeding a stratum's size.
round_robin_allocate <- function(sizes, n) {
  alloc <- setNames(integer(length(sizes)), names(sizes))
  n <- min(n, sum(sizes))
  while (sum(alloc) < n) {
    open <- names(sizes)[alloc < sizes]
    open <- open[order(sizes[open])]
    for (k in open) {
      if (sum(alloc) >= n) break
      alloc[k] <- alloc[k] + 1L
    }
  }
  alloc
}

# First TRUE column in `priority` order for each row (NA if none).
first_true <- function(m, priority) {
  out <- rep(NA_character_, nrow(m))
  for (p in rev(priority)) out[m[, p]] <- p
  out
}

make_validation_sample <- function(rec, cfg) {
  sp <- cfg$sampling
  stopifnot(setequal(sp$state_priority, names(cfg$states)),
            setequal(sp$taxon_priority, names(cfg$taxa)))
  m_st <- as.matrix(rec[paste0("state_", names(cfg$states))]); colnames(m_st) <- names(cfg$states)
  m_tx <- as.matrix(rec[paste0("taxon_", names(cfg$taxa))]);   colnames(m_tx) <- names(cfg$taxa)
  rec$primary_state <- first_true(m_st, sp$state_priority)
  rec$primary_taxon <- first_true(m_tx, sp$taxon_priority)
  # Tags taken from a title alone are unreliable: records still without an abstract
  # form their own stratum, labelled from the title and DOI.
  no_abs <- is.na(rec$abstract)
  untagged <- !no_abs & (is.na(rec$primary_state) | is.na(rec$primary_taxon))
  rec$stratum_block <- ifelse(no_abs, "no_abstract", ifelse(untagged, "untagged", rec$primary_state))
  rec$primary_taxon[no_abs] <- NA

  set.seed(sp$seed)
  out <- list()
  for (b in c(sp$state_priority, "untagged", "no_abstract")) {
    rb <- rec[rec$stratum_block == b, , drop = FALSE]
    if (nrow(rb) == 0) next
    n_b <- switch(b, untagged = sp$n_untagged, no_abstract = sp$n_no_abstract, sp$n_per_state_block)
    tx <- ifelse(is.na(rb$primary_taxon), "none", rb$primary_taxon)
    sizes <- table(tx); sizes <- setNames(as.integer(sizes), names(sizes))
    alloc <- round_robin_allocate(sizes, n_b)
    for (g in names(sizes)[alloc > 0]) {
      idx <- which(tx == g)
      s <- rb[idx[sample.int(length(idx), alloc[[g]])], , drop = FALSE]
      s$primary_taxon <- g
      s$stratum_N <- sizes[[g]]; s$stratum_n <- alloc[[g]]
      s$weight <- sizes[[g]] / alloc[[g]]
      out[[length(out) + 1]] <- s
    }
  }
  res <- do.call(rbind, out)
  res[sample.int(nrow(res)), , drop = FALSE]    # shuffle: the labeller should not see blocks in order
}
