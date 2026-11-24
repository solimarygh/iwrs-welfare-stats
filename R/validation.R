# Reads the labelled validation sample and estimates, per stratum, how many of the papers are on topic.
# Relevance codes (docs/labeling_guide.md): 2 core, 1 indirect, 0 not relevant, ? cannot decide.

read_labels <- function(path) {
  if (!file.exists(path)) stop("Labelled file not found: ", path, call. = FALSE)
  x <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
  need <- c("openalex_id", "relevance", "reason_if_0")
  if (length(miss <- setdiff(need, names(x)))) stop("Missing column(s): ", paste(miss, collapse = ", "), call. = FALSE)
  x$relevance <- trimws(x$relevance)
  x$status <- ifelse(is.na(x$relevance) | x$relevance == "", "unlabeled", ifelse(x$relevance %in% c("0", "1", "2", "?"), "ok", "invalid"))
  x[, c("openalex_id", "relevance", "reason_if_0", "status")]
}

# Weighted share of labelled papers with indicator `y`; weights = stratum size / rows labelled in it.
wshare <- function(y, w) sum(w * y) / sum(w)

# Per stratum block: weighted shares, bootstrap intervals (resampling inside each taxon stratum),
# and the estimated number of on-topic papers in the whole stratum.
estimate_precision <- function(lab, ids, B = 1000, seed = 2026) {
  d <- merge(lab[lab$status == "ok", ], ids, by = "openalex_id")
  d$N <- as.numeric(d$stratum_N); d$w <- as.numeric(d$weight)
  set.seed(seed)
  one <- function(blk) {
    x <- d[d$stratum_block == blk, ]
    unsure <- sum(x$relevance == "?"); x <- x[x$relevance != "?", ]
    if (!nrow(x)) return(NULL)
    strict <- as.numeric(x$relevance == "2"); loose <- as.numeric(x$relevance %in% c("1", "2"))
    cell <- paste(x$primary_taxon); idx <- split(seq_len(nrow(x)), cell)
    # "?" rows are left out, so each taxon stratum is weighted by its size over the rows still labelled
    x$w <- x$N / as.numeric(table(cell)[cell])
    boot <- replicate(B, { s <- unlist(lapply(idx, function(i) i[sample.int(length(i), replace = TRUE)]))
                           c(wshare(strict[s], x$w[s]), wshare(loose[s], x$w[s])) })
    Nb <- sum(tapply(x$N, cell, function(v) v[1]))
    ps <- wshare(strict, x$w); pl <- wshare(loose, x$w)
    data.frame(block = blk, labelled = nrow(x), unsure = unsure, N = Nb,
               core_share = ps, core_lo = quantile(boot[1, ], .025), core_hi = quantile(boot[1, ], .975),
               on_topic_share = pl, on_topic_lo = quantile(boot[2, ], .025), on_topic_hi = quantile(boot[2, ], .975),
               est_core = ps * Nb, est_on_topic = pl * Nb, row.names = NULL)
  }
  do.call(rbind, lapply(unique(d$stratum_block), one))
}

# Pools the core blocks, and estimates how much on-topic work the core leaves out (broad_only).
summarise_validation <- function(est, core_blocks) {
  core <- est[est$block %in% core_blocks, ]; bo <- est[est$block == "broad_only", ]
  list(core_papers = sum(core$N), core_on_topic = sum(core$est_on_topic), core_strict = sum(core$est_core),
       precision_on_topic = sum(core$est_on_topic) / sum(core$N), precision_strict = sum(core$est_core) / sum(core$N),
       broad_only_papers = if (nrow(bo)) bo$N else NA, broad_only_on_topic = if (nrow(bo)) bo$est_on_topic else NA,
       recall_in_retrieved = if (nrow(bo)) sum(core$est_on_topic) / (sum(core$est_on_topic) + bo$est_on_topic) else NA)
}

reason_table <- function(lab, ids) {
  d <- merge(lab[lab$status == "ok" & lab$relevance == "0", ], ids, by = "openalex_id")
  if (!nrow(d)) return(NULL)
  d$reason_if_0[is.na(d$reason_if_0) | d$reason_if_0 == ""] <- "(not stated)"
  as.data.frame.matrix(table(d$stratum_block, d$reason_if_0))
}
