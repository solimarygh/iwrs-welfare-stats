# Offline tests for R/records.R, R/tagging.R and R/sampling.R.
#   Rscript tests/test_records.R
source("R/queries.R"); source("R/openalex.R"); source("R/records.R")
source("R/tagging.R"); source("R/sampling.R")
cfg <- read_config()

# --- abstract reconstruction ------------------------------------------------
idx <- list(Insects = list(0L), may = list(1L), feel = list(2L, 5L), pain = list(3L), `.` = list(4L))
stopifnot(reconstruct_abstract(idx) == "Insects may feel pain . feel")
stopifnot(is.na(reconstruct_abstract(NULL)), is.na(reconstruct_abstract(list())))

# --- parsing, including missing fields -------------------------------------
w <- list(id = "https://openalex.org/W1", doi = NULL, title = "T", publication_year = 2020L,
          type = "article", cited_by_count = 3L, language = "en",
          primary_location = list(source = list(id = "S1", display_name = "Animal Welfare", issn_l = "0962-7286")),
          abstract_inverted_index = list(Hello = list(0L), world = list(1L)))
p <- parse_work(w)
stopifnot(p$source_name == "Animal Welfare", is.na(p$doi), p$abstract == "Hello world", p$year == 2020L)
p2 <- parse_work(list(id = "W2", primary_location = NULL))
stopifnot(is.na(p2$source_name), is.na(p2$abstract), is.na(p2$title))

# --- pagination with a mock --------------------------------------------------
Sys.setenv(OPENALEX_MAILTO = "test@example.org")
on.exit(Sys.unsetenv("OPENALEX_MAILTO"))
calls <- 0
mock <- function(url, query, mailto) {
  calls <<- calls + 1
  stopifnot(query$`per-page` == 200, query$select == oa_select_fields)
  if (query$cursor == "*") list(meta = list(count = 3, next_cursor = "c2"), results = list(list(id = "A"), list(id = "B")))
  else if (query$cursor == "c2") list(meta = list(count = 3, next_cursor = "c3"), results = list(list(id = "C")))
  else list(meta = list(count = 3, next_cursor = NULL), results = list())
}
r <- fetch_records(cfg, "f", fetch = mock, progress = FALSE)
stopifnot(nrow(r) == 3, attr(r, "api_count") == 3, identical(r$openalex_id, c("A", "B", "C")), calls == 3)

# --- term -> regex ---------------------------------------------------------
m <- function(term, text) tag_terms(text, term)
stopifnot(m("insect*", "Many insects feel"), m("insect*", "insecticide use"), !m("insect*", "an inspector"))
stopifnot(m("bee", "A Bee, a wasp"), !m("bee", "been there"), !m("bee", "beef"))
stopifnot(m("honey bee", "the honey\n  bee hive"), !m("honey bee", "honeybee"))
stopifnot(m("well-being", "animal well-being"), !m("pain", "painted walls"), m("pain", "chronic pain."))
stopifnot(m("sentien*", "Sentience in crabs"), !m("sentien*", "presentient"), m("conscious*", "consciousness"))
stopifnot(!m("pain", NA), m("emotion*", "Émotions et emotion"))   # NA text is safe

# --- tagging records ---------------------------------------------------------
rec <- data.frame(title = c("Pain in crabs", "Spider fear in humans", "Bee welfare"),
                  abstract = c("Nociception in the crab", "emotion and spiders", NA), stringsAsFactors = FALSE)
t <- tag_records(rec, cfg)
stopifnot(t$taxon_crustaceans[1], t$state_nociception_pain[1], t$is_arthropod[1])
stopifnot(t$taxon_other_arthropods[2], t$state_affect_emotion[2])
stopifnot(t$taxon_insects[3], t$state_welfare[3], !t$taxon_cephalopods[3])

# --- sampling ----------------------------------------------------------------
al <- round_robin_allocate(c(a = 1L, b = 10L, c = 10L), 6)
# pass 1 gives a,b,c one slot each; pass 2 gives b,c one more; pass 3 gives b the last
stopifnot(identical(unname(al), c(1L, 3L, 2L)))
stopifnot(sum(round_robin_allocate(c(a = 2L, b = 3L), 100)) == 5)    # capped at total

set.seed(1); n <- 900
sim <- data.frame(openalex_id = paste0("W", seq_len(n)), title = "t", abstract = "a",
                  year = 2020L, source_name = "j", stringsAsFactors = FALSE)
for (g in names(cfg$taxa))   sim[[paste0("taxon_", g)]] <- runif(n) < 0.12
for (b in names(cfg$states)) sim[[paste0("state_", b)]] <- runif(n) < 0.25
s1 <- make_validation_sample(sim, cfg); s2 <- make_validation_sample(sim, cfg)
stopifnot(identical(s1$openalex_id, s2$openalex_id))                  # reproducible
stopifnot(!anyDuplicated(s1$openalex_id))
per_block <- tapply(s1$stratum_block, s1$stratum_block, length)
stopifnot(all(per_block[names(per_block) != "untagged"] <= cfg$sampling$n_per_state_block))
st <- unique(s1[, c("stratum_block", "primary_taxon", "stratum_N", "stratum_n")])
stopifnot(all(st$stratum_n <= st$stratum_N), all(abs(s1$weight * s1$stratum_n - s1$stratum_N) < 1e-9))
# stratum sizes recorded in the sample equal the population counts, recomputed independently
mat <- function(pref, nm) setNames(sim[paste0(pref, names(nm))], names(nm))
prim_st <- first_true(as.matrix(mat("state_", cfg$states)), cfg$sampling$state_priority)
prim_tx <- first_true(as.matrix(mat("taxon_", cfg$taxa)), cfg$sampling$taxon_priority)
for (b in cfg$sampling$state_priority) {
  pop <- sum(prim_st == b & !is.na(prim_tx), na.rm = TRUE)
  got <- sum(st$stratum_N[st$stratum_block == b])
  stopifnot(pop == got)
}
stopifnot(sum(st$stratum_N[st$stratum_block == "untagged"]) == sum(is.na(prim_st) | is.na(prim_tx)))

cat("test_records.R: all checks passed\n")
