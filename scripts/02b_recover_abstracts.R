# Step 2b: OpenAlex searches abstracts it does not return (about 11% of the records
# come without one). This step looks them up by DOI in Crossref and Europe PMC,
# re-tags every record and rewrites the summary tables. Run after step 2:
#   source("scripts/02b_recover_abstracts.R")
# ~2,000 DOIs, one or two calls each: expect 10-30 minutes. Interruptions are safe:
# answers are cached in data/raw/abstract_cache.rds and the run resumes.
source("R/queries.R"); source("R/openalex.R"); source("R/records.R"); source("R/tagging.R")
source("R/abstracts.R"); source("R/outputs.R")
cfg <- read_config()

files <- sort(list.files("data/raw", "^records_.*\\.rds$", full.names = TRUE))
if (length(files) == 0) stop("Run scripts/02_fetch_records.R first.")
path <- files[length(files)]
rec <- readRDS(path)
message("Using ", path, " (", nrow(rec), " records, ", sum(is.na(rec$abstract)), " without abstract)")
message("Records without abstract and without DOI (cannot be recovered): ",
        sum(is.na(rec$abstract) & is.na(rec$doi)))

rec <- recover_abstracts(rec, cfg)
message("Abstract source:"); print(table(rec$abstract_source, useNA = "ifany"))

rec <- tag_records(rec, cfg)
saveRDS(rec, path)
write_records_outputs(rec, cfg)
