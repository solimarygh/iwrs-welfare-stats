# Offline tests for R/core.R.   Rscript tests/test_core.R
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R"); source("R/core.R")
cfg <- read_config()
core <- function(title, abstract = NA) {
  r <- tag_core(data.frame(title = title, abstract = abstract, stringsAsFactors = FALSE), cfg)
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
stopifnot(yes("A study", abstract = "We assess the welfare of lobsters in holding tanks."))
stopifnot(!isTRUE(core(NA, NA)$core_any), !isTRUE(core("", "")$core_any))

# core_any is the OR of the blocks
r <- tag_core(data.frame(title = c("Insect welfare", "Pain in shrimp", "Human welfare"), abstract = NA, stringsAsFactors = FALSE), cfg)
stopifnot(identical(r$core_any, c(TRUE, TRUE, FALSE)))

# the core only finds what the broad search retrieved
stopifnot(length(core_uncovered_words(cfg)) == 0)
bad <- cfg; bad$core$states$welfare <- c("welfare", "fairness")
stopifnot(identical(core_uncovered_words(bad), "fairness"))

# tag_records adds the core columns
tr <- tag_records(data.frame(title = "Insect welfare", abstract = NA, stringsAsFactors = FALSE), cfg)
stopifnot(all(c("core_welfare", "core_any", "taxon_insects", "is_arthropod") %in% names(tr)), tr$core_welfare)
cat("test_core.R: all checks passed\n")
