# Step 6: counts of members per country for the map on the site.
#   source("scripts/06_build_member_map_data.R")
# Reads the membership list named in config/config.yml (members.file, kept in data/private/,
# which git ignores) and writes site/members.js with counts per country only: no names,
# institutions, cities or free text. Countries with fewer than members.min_cell members are
# marked as such and carry no number. Unrecognised country spellings are listed so they can be
# added to data/reference/country_names.csv (columns name_norm, iso3, country).
source("R/queries.R"); source("R/records.R"); source("R/members.R")
cfg <- read_config()

countries <- read_member_countries(cfg$members$file, cfg)
agg <- members_by_country(countries, read_country_lookup(), cfg$members$min_cell)
write_members_data(agg)

message(sprintf("%d rows: %d located in %d countries, %d without a country, %d not recognised.",
                agg$total, agg$located, nrow(agg$table), agg$blank, sum(agg$unmatched)))
if (length(agg$unmatched)) { message("Not recognised (spelling and number of rows):"); print(agg$unmatched) }
message(sprintf("%d countries have fewer than %d members and are shown without a number.",
                sum(agg$table$small), agg$min_cell))
message("Wrote site/members.js")
