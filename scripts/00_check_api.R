# Diagnostic: tests the pieces of a query one at a time against the live
# OpenAlex API and prints status + OpenAlex's own error message.
#   source("scripts/00_check_api.R")
source("R/queries.R")
cfg <- read_config()
mailto <- Sys.getenv("OPENALEX_MAILTO", unset = "")

probe <- function(label, filter, group_by = "publication_year") {
  req <- httr2::request(paste0(cfg$openalex$base_url, "/works"))
  req <- httr2::req_url_query(req, filter = filter, group_by = group_by, mailto = mailto)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req)
  status <- httr2::resp_status(resp)
  body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  total <- NA
  if (status == 200 && !is.null(body$meta$count)) total <- body$meta$count
  msg <- if (status != 200 && !is.null(body)) paste(body$error, body$message) else ""
  cat(sprintf("%-34s HTTP %d  groups=%s  %s\n", label, status,
              ifelse(is.na(total), "-", total), msg))
  if (status != 200) cat("   URL: ", resp$url, "\n")
  invisible(body)
}

d1 <- "from_publication_date:2016-01-01,to_publication_date:2026-12-31"
probe("1 dates only", d1)
probe("2 + type", paste0(d1, ",type:article|review"))
probe("3 + source type", paste0(d1, ",type:article|review,primary_location.source.type:journal"))
ex <- paste0(d1, ",title_and_abstract.search.exact:")
probe("4 exact: insect", paste0(ex, "insect"))
probe("5 exact: insect*", paste0(ex, "insect*"))
probe("6 exact: boolean + wildcard", paste0(ex, "(insect* OR bee OR bees) AND (welfare)"))
probe("7 exact: quoted phrase", paste0(ex, '"honey bee"'))
probe("8 exact: wildcard + AND", paste0(ex, "(insect*) AND (sentien*)"))
probe("9 exact: Drosophila", paste0(ex, "Drosophila"))
probe("10 exact: drosophila (case)", paste0(ex, "drosophila"))
probe("11 REAL insects x sentience",
      build_filter(cfg, build_search(taxon_terms(cfg, "insects"), state_terms(cfg, "sentience"))))
