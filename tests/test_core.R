# Offline tests for R/core.R.   Rscript tests/test_core.R
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R"); source("R/core.R")
cfg <- read_config()
core <- function(title, abstract = NA, field = NA_character_) {
  r <- tag_core(data.frame(title = title, abstract = abstract, topic_field = field, stringsAsFactors = FALSE), cfg)
  r[, grep("^core_", names(r))]
}
yes <- function(title, block = "welfare", ...) isTRUE(core(title, ...)[[paste0("core_", block)]])

stopifnot(yes("Insect welfare in industrial farms"))
stopifnot(yes("The welfare of farmed insects"))                       # words in any order, 3 apart
stopifnot(yes("Honey bee welfare under pesticide exposure"))          # phrase as one token
stopifnot(yes("Well-being of honeybees"), yes("Wellbeing of crabs"))   # hyphen and variant spellings
stopifnot(yes("Pain in decapod crustaceans", "nociception_pain"), yes("Sentient octopuses", "sentience"))
stopifnot(yes("Do crabs feel emotions?", "affect_emotion"), yes("Consciousness in bees", "consciousness"))
stopifnot(yes("Black soldier fly larvae: a welfare assessment"), yes("Fruit flies and welfare"))

# not core: no animal word, animal word far away, wrong block
stopifnot(!yes("Human welfare effects of rural policy"))
stopifnot(!yes("Insects of Brazil: ecology, taxonomy, distribution, climate, history, and welfare"))   # > 6 words apart
stopifnot(!yes("Crabs sentient", "welfare"), yes("Crabs sentient", "sentience"))

# wildcard traps: insecticide is not an insect word; sport cricket is noisy and excluded
stopifnot(!yes("Economic welfare of farmers who use insecticide sprays"))
stopifnot(!yes("Insectivorous plants and their welfare value"))
stopifnot(!yes("Cricket welfare in the league"), yes("Crickets welfare in mass rearing"))

# abstract counts; NA title or abstract are safe
stopifnot(yes("A study", abstract = "We assess the welfare of lobsters in holding tanks. Lobsters were held for a week."))
stopifnot(!isTRUE(core(NA, NA)$core_any), !isTRUE(core("", "")$core_any))

# core_any is the OR of the blocks
r <- tag_core(data.frame(title = c("Insect welfare", "Pain in shrimp", "Human welfare"), abstract = NA, topic_field = NA_character_, stringsAsFactors = FALSE), cfg)
stopifnot(identical(r$core_any, c(TRUE, TRUE, FALSE)))

# the core only finds what the broad search retrieved
stopifnot(length(core_uncovered_words(cfg)) == 0)
bad <- cfg; bad$core$states$welfare <- c("welfare", "fairness")
stopifnot(identical(core_uncovered_words(bad), "fairness"))

# tag_records adds the core columns
tr <- tag_records(data.frame(title = "Insect welfare", abstract = NA, topic_field = NA_character_, stringsAsFactors = FALSE), cfg)
stopifnot(all(c("core_welfare", "core_any", "taxon_insects", "is_arthropod") %in% names(tr)), tr$core_welfare)

# --- filters ------------------------------------------------------------------
# subject: a single mention in the abstract is not enough, the title or two mentions are
one <- "We review the welfare of consumers. The crab is mentioned once."
stopifnot(!yes("A study of people", abstract = one))
stopifnot(yes("A study of people", abstract = "Welfare of crabs matters. Crabs are sold live."))
stopifnot(yes("Crab welfare", abstract = "Nothing else."))                 # animal word in the title
r <- core("A study of people", abstract = one)
stopifnot(r$core_welfare == FALSE, tag_core(data.frame(title = "A study of people", abstract = one, topic_field = NA_character_,
          stringsAsFactors = FALSE), cfg)$pattern_welfare)                 # the pattern still matches
# field: excluded fields lose the core, others (and papers with no topic) keep it
stopifnot(!yes("Octopus welfare", field = "Computer Science"), yes("Octopus welfare", field = "Agricultural and Biological Sciences"))
stopifnot(yes("Octopus welfare", field = NA_character_), yes("Octopus welfare", field = "Social Sciences"))
stopifnot(!yes("Octopus welfare", field = "Medicine"), !yes("Leech pain", field = "Pharmacology, Toxicology and Pharmaceutics"))
# without topic_field the field filter cannot run: say so
err <- tryCatch(tag_core(data.frame(title = "Octopus welfare", abstract = NA, stringsAsFactors = FALSE), cfg), error = function(e) conditionMessage(e))
stopifnot(grepl("02c_fetch_topics", err))
# no filters configured: the pattern alone
nf <- cfg; nf$core$filters <- NULL
stopifnot(tag_core(data.frame(title = "A study of people", abstract = one, stringsAsFactors = FALSE), nf)$core_welfare)

# --- exempt blocks and human context -------------------------------------------
one_mention <- "A note on consciousness. Insects are mentioned once."
stopifnot(yes("A note", block = "consciousness", abstract = one_mention))     # consciousness skips the subject filter
stopifnot(yes("Debate on sentience", block = "sentience", abstract = "Insects may be sentient."))
stopifnot(!yes("A note", block = "welfare", abstract = "Welfare of insects is mentioned once."))   # welfare keeps it
hum <- "Patients and students felt emotions about spiders. Participants rated spiders."
stopifnot(!yes("Spider emotions", block = "affect_emotion", abstract = hum))
stopifnot(yes("Spider emotions", block = "affect_emotion", abstract = "Do spiders feel emotions? We tested spiders; one participant was filmed."))  # one human word is not enough
stopifnot(yes("Spider pain", block = "nociception_pain", abstract = hum))       # the rule only covers its blocks
r <- tag_core(data.frame(title = "Spider emotions", abstract = hum, topic_field = NA_character_, stringsAsFactors = FALSE), cfg)
stopifnot(r$pattern_affect_emotion, !r$keep_affect_emotion, r$human_mentions >= 3)
cat("test_core.R: all checks passed\n")
