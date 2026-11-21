# Probes the CORE definition (animal word near a state word) block by block against
# OpenAlex: total papers (all years) and 10 random titles for each block. Judge precision
# by reading the titles. A block that is too long for one request is reported as not
# accepted; the blocks cannot be joined in one query (about 17,000 characters in all).
#   source("scripts/00d_probe_core_blocks.R")
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/diagnostics.R")
cfg <- read_config()

run <- function(label, search) {
  r <- probe_definition(label, build_filter(cfg, search), cfg)
  cat("\n==", label, sprintf("  [query of %s characters]\n", format(nchar(search), big.mark = ",")))
  if (!is.null(r$error)) { cat("   NOT ACCEPTED BY THE API:", substr(r$error, 1, 400), "\n"); return(invisible(r)) }
  cat("   papers returned (all years):", format(r$count, big.mark = ","), "\n")
  cat(paste0("   - ", r$titles), sep = "\n")
  invisible(r)
}
for (b in names(cfg$core$states)) run(paste("core:", b), build_core_search(cfg, b))
run("core: welfare, adjacent words only (no proximity)", build_core_search(cfg, "welfare", proximity = 0))
