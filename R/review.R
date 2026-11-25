# Manual review of ALL the core papers of one year, by one or more reviewers.
# Relevance codes as in docs/labeling_guide.md: 2 core, 1 indirect, 0 not relevant, ? cannot decide.

# The sheet each reviewer fills in: the core papers of `year` in a shuffled order, without the block or
# theme that matched, so the label is not influenced by it. Contains abstracts: keep it in data/raw/
# and share it only with the reviewers.
make_review_sheet <- function(rec, year, seed = 2026) {
  x <- rec[rec$core_any & rec$year == year, , drop = FALSE]
  if (!nrow(x)) stop("No core papers in ", year, call. = FALSE)
  set.seed(seed); x <- x[sample.int(nrow(x)), , drop = FALSE]
  data.frame(row = seq_len(nrow(x)), openalex_id = x$openalex_id, doi = x$doi, journal = x$source_name,
             title = x$title, abstract = x$abstract,
             abstract_source = if (is.null(x$abstract_source)) NA_character_ else x$abstract_source,
             relevance = "", reason_if_0 = "", notes = "", stringsAsFactors = FALSE)
}

# Reads data/raw/review_<year>_<reviewer>.csv (one file per reviewer; review_<year>.csv is the blank sheet and
# review_<year>_resolved.csv holds the decisions on disagreements, so neither is a reviewer).
# Returns list(wide = one row per paper and one column per reviewer, notes = long table with the notes).
read_review_files <- function(dir, year) {
  pat <- sprintf("^review_%s_(.+)\\.csv$", year)
  files <- sort(list.files(dir, pat, full.names = TRUE))
  files <- files[!grepl("_(resolved|to_resolve)\\.csv$", files)]
  if (!length(files)) stop("No reviewer file found: save each reviewer's sheet as ", dir, "/review_", year, "_<name>.csv", call. = FALSE)
  rv <- sub(pat, "\\1", basename(files))
  long <- do.call(rbind, Map(function(f, r) {
    x <- read_labels(f)                                   # R/validation.R: checks the codes
    raw <- utils::read.csv(f, stringsAsFactors = FALSE, encoding = "UTF-8", colClasses = "character")
    x$notes <- if ("notes" %in% names(raw)) raw$notes else ""
    x$reviewer <- r; x
  }, files, rv))
  bad <- long[long$status == "invalid", ]
  if (nrow(bad)) stop("Values that are not 2, 1, 0 or ? in: ", paste(unique(bad$reviewer), collapse = ", "), call. = FALSE)
  ids <- unique(long$openalex_id)
  wide <- data.frame(openalex_id = ids, stringsAsFactors = FALSE)
  for (r in rv) {
    x <- long[long$reviewer == r & long$status == "ok", ]
    wide[[r]] <- x$relevance[match(ids, x$openalex_id)]
  }
  list(wide = wide, long = long, reviewers = rv)
}

# For each pair of reviewers: papers both labelled with 0, 1 or 2, agreement on "on topic" (1 or 2 against 0),
# and Cohen's kappa for that yes/no.
review_agreement <- function(wide) {
  rv <- setdiff(names(wide), "openalex_id")
  if (length(rv) < 2) return(NULL)
  pairs <- utils::combn(rv, 2, simplify = FALSE)
  do.call(rbind, lapply(pairs, function(p) {
    a <- wide[[p[1]]]; b <- wide[[p[2]]]; ok <- a %in% c("0", "1", "2") & b %in% c("0", "1", "2")
    ya <- a[ok] != "0"; yb <- b[ok] != "0"; n <- sum(ok)
    po <- mean(ya == yb); pe <- mean(ya) * mean(yb) + (1 - mean(ya)) * (1 - mean(yb))
    data.frame(reviewer_a = p[1], reviewer_b = p[2], n = n, agree_on_topic = po,
               kappa = if (isTRUE(all.equal(pe, 1))) NA_real_ else (po - pe) / (1 - pe), stringsAsFactors = FALSE)
  }))
}

# Final label of each paper. All reviewers on topic -> the lowest code they gave (2 and 1 give 1); all with 0 -> 0;
# anything else (a disagreement, a "?" or a missing label) waits for `resolved` (data.frame openalex_id, relevance).
review_final <- function(wide, resolved = NULL) {
  rv <- setdiff(names(wide), "openalex_id")
  m <- as.matrix(wide[rv])
  final <- character(nrow(wide)); status <- character(nrow(wide))
  for (i in seq_len(nrow(wide))) {
    v <- m[i, ]
    if (!anyNA(v) && all(v %in% c("1", "2"))) { final[i] <- min(v); status[i] <- if (length(rv) > 1) "agreed" else "single" }
    else if (!anyNA(v) && all(v == "0")) { final[i] <- "0"; status[i] <- if (length(rv) > 1) "agreed" else "single" }
    else { final[i] <- NA; status[i] <- "to_resolve" }
  }
  if (!is.null(resolved) && nrow(resolved)) {
    if (!all(resolved$relevance %in% c("0", "1", "2"))) stop("The resolved labels must be 0, 1 or 2.", call. = FALSE)
    k <- match(resolved$openalex_id, wide$openalex_id)
    if (anyNA(k)) stop("Resolved papers that are not in the review: ", paste(resolved$openalex_id[is.na(k)], collapse = ", "), call. = FALSE)
    final[k] <- resolved$relevance; status[k] <- "resolved"
  }
  data.frame(openalex_id = wide$openalex_id, final = final, status = status, stringsAsFactors = FALSE)
}
