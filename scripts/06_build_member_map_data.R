# Step 6: counts of members per country for the map on the site.
#   source("scripts/06_build_member_map_data.R")
# Reads the membership list named in config/config.yml (members.file, kept in data/private/,
# which git ignores) and writes site/members.js with counts per country only: no names,
# institutions, cities or free text. Countries with fewer than members.min_cell members are
# marked as such and carry no number; so are cells of the filters, and a filter term stated by
# fewer members than that is not published at all. Unrecognised country spellings are listed so they can be
# added to data/reference/country_names.csv (columns name_norm, iso3, country).
source("R/queries.R"); source("R/records.R"); source("R/members.R")
cfg <- read_config()

df <- read_member_table(cfg$members$file, cfg)
countries <- country_of(df, cfg)
lookup <- read_country_lookup()
agg <- members_by_country(countries, lookup, cfg$members$min_cell)

# Filters (discipline, taxonomic expertise, interests, species)
iso3 <- lookup$iso3[match(norm_country(countries), lookup$name_norm)]
aliases <- read_term_aliases(cfg$members$aliases)
facets <- list()
for (key in names(cfg$members$facets)) {
  f <- cfg$members$facets[[key]]
  fc <- facet_counts(member_terms(df, unlist(f$headers), aliases), iso3, cfg$members$min_cell, cfg$members$max_terms)
  facets[[key]] <- list(label = f$label, terms = fc$terms)
  message(sprintf("\n[%s] %d distinct terms; %d stated by at least %d members are published.",
                  f$label, fc$distinct, fc$published, cfg$members$min_cell))
  print(head(fc$tot, 25))
}
write_members_data(agg, facets = facets)

message(sprintf("\n%d rows: %d located in %d countries, %d without a country, %d not recognised.",
                agg$total, agg$located, nrow(agg$table), agg$blank, sum(agg$unmatched)))
if (length(agg$unmatched)) { message("Not recognised (spelling and number of rows):"); print(agg$unmatched) }
message(sprintf("%d countries have fewer than %d members and are shown without a number.",
                sum(agg$table$small), agg$min_cell))
message("Wrote site/members.js. To merge spellings (for example 'welfare science' and 'animal welfare'), list them in ",
        cfg$members$aliases, " (columns term,canonical) and run this script again.")
