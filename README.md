# iwrs-welfare-stats

Reproducible R pipeline to track the growth of research on insect and invertebrate
sentience and welfare (publications, journals, conferences, theses). Built for the
Insect Welfare Research Society (IWRS) annual report.

## Statistics covered

| # | Statistic | Source | Automation |
|---|-----------|--------|------------|
| 1 | Peer-reviewed publications per year, 2016-present, split into sentience / affect-emotion / consciousness / welfare (+ nociception-pain) | OpenAlex | full |
| 2 | Ratio of conceptual / theoretical / methodological / perspective papers to empirical papers | OpenAlex abstracts + classifier | semi (validated sample) |
| 3 | Distribution across journal groups (animal welfare, entomology, high-impact multidisciplinary) | OpenAlex | full |
| 4-6 | Conference talks, symposia, and other academic events | Conference programmes + curated sheet | manual / semi |
| 7 | PhD and Master's theses | OpenAlex + thesis repositories + curated sheet | semi |

Arthropods are tagged in every output (`is_arthropod`), and the union of arthropod
groups is reported as `ALL_ARTHROPODS` next to `ALL_INVERTEBRATES`.

## How it works

- `config/config.yml` holds everything that defines what is counted: years, taxon
  groups, state terms, journal lists. The yearly update normally means changing
  `project.years` and re-running.
- `R/queries.R` builds the OpenAlex search expressions from the config (pure
  functions, tested offline in `tests/`).
- `scripts/` hold the numbered steps; each writes to `data/processed/` and a
  dated snapshot to `data/snapshots/`.

OpenAlex indexes late and reclassifies retroactively, so counts for the same year
change over time. Every run therefore stores the query strings and the run date
next to the counts.

## Search design

Taxon terms (insect*, arthropod*, crustacean*, cephalopod*, invertebrate*, honey bee,
Drosophila, ...) are combined with state terms (sentien*, affective state, emotion*,
conscious*, welfare, nociception, pain), searched in title and abstract with the
exact (non-stemmed) OpenAlex field, the only one that accepts wildcards; plurals are
therefore listed explicitly. "affect" alone
is not used, because as a verb it is noise. Terms with frequent non-biological
meanings (cricket*, ant, tick, ...) are excluded by default and can be switched on for
a sensitivity analysis (`search.include_noisy`).

"Peer-reviewed" is approximated by OpenAlex document type `article` or `review` in
a journal-type source. The current calendar year is partial and is flagged as such.

## Requirements

R >= 4.3 with `yaml`, `httr2`, `jsonlite` and, for the members map, `readxl`.
`renv` lock file to be added once the pipeline is validated against the live API.

## Pipeline steps

| Script | What it does | Output |
|--------|--------------|--------|
| `scripts/00_check_api.R` | Probes the query pieces against the live API (diagnostic) | console |
| `scripts/01_publication_counts.R` | Counts per year, taxon group x state block (+ denominators) | `data/processed/counts_by_year.csv` |
| `scripts/02_fetch_records.R` | Downloads every matching record with its abstract (one query per taxon group, de-duplicated) and tags taxon groups, state blocks and the strict core definition (topic field comes with it; for records downloaded before, run 02c) | `data/processed/records_meta.csv`, `core_counts_by_year.csv`, `tagging_fidelity.csv`; abstracts in `data/raw/` (not tracked) |
| `scripts/02b_recover_abstracts.R` | OpenAlex searches abstracts it does not return (~11% of records); recovers them by DOI from Crossref and Europe PMC, re-tags, rewrites the tables | `data/raw/` (not tracked), `data/processed/records_meta.csv`, `tagging_fidelity.csv` |
| `scripts/02c_fetch_topics.R` | Adds the OpenAlex field of each record and re-tags: the core now needs the animal word in the title or twice in title + abstract, and a field outside `core.filters.exclude_fields` | `data/raw/` (not tracked), `data/processed/records_meta.csv` |
| `scripts/03_make_validation_sample.R` | Stratified sample for manual relevance labelling | `data/raw/validation_sample.csv` (not tracked), `data/validation/sample_ids.csv` |
| `scripts/06_build_member_map_data.R` | Counts members per country from the membership list kept in `data/private/` (never committed) and writes `site/members.js` | `site/members.js` |
| `scripts/04_read_labels.R` | Reads your labels of the validation sample; estimates, per block, the share of papers that are on topic (with intervals), what the core leaves out, and why papers were not relevant | `data/validation/labels.csv` (ids and labels only), `data/processed/validation_summary.csv` |
| `scripts/04b_evaluate_core_rules.R` | Shows what the two core filters do to the labelled sample (papers kept, share on topic, on-topic papers lost) and the labelled papers by field | console only |
| `scripts/07_journal_distribution.R` | Groups the core papers by journal (groups editable in the config) per year and taxon group | `data/processed/journals_by_year.csv`, `journals_top.csv`, `site/journals.js` |
| `scripts/08_build_events_data.R` | Checks the template that IWRS fills in (talks, symposia, workshops, panels, events, theses), lists problems by row, and counts per year | `data/processed/events_by_year.csv`, `site/events.js` |
| `scripts/05_build_site_data.R` | Exports the counts to `site/data.js`, the file the static site reads | `site/data.js` |

**Two definitions.** The *broad* search counts every paper that mentions an animal name and a
state word anywhere in its title or abstract. A first read of random titles showed that
most of those are not about the animals' welfare. The *core* keeps a paper only when an
animal word and a state word occur within a few words of each other ("insect welfare",
"welfare of farmed insects"); it is applied locally to the downloaded records
(`R/core.R`), so the list of animal names in `config/config.yml` can be long and the
window (`core.proximity`) can change without new queries. The validation sample measures
the precision of the core and, through its `broad_only` stratum, how much on-topic work
the core leaves out.

Since 2026-11-24 the core has two more conditions, added after the first validation (see
`docs/decisions.md`): the animal word must be in the title or occur twice in title + abstract
(`core.filters.subject_min_mentions`), and the paper's OpenAlex field must not be one of
`core.filters.exclude_fields`. The word-pattern flags stay in the records as `pattern_<block>`.

The search is deliberately broad (high recall). Keyword matches are not the same as
relevance: "welfare" also finds human economic welfare, "pain" finds venom pharmacology,
"emotion*" finds arachnophobia. Step 3 draws a sample to measure that precision;
labelling rules are in `docs/labeling_guide.md`.

## The site

`site/` is a static site (plain HTML, CSS and JavaScript, no build step and no
dependencies): headline figures, a trend chart, a chart by theme, ranked taxon groups,
a table view under every chart, light and dark themes, and filters that are saved in
the link. To preview it, run `scripts/05_build_site_data.R` and open `site/index.html`
in a browser (double-click works). To publish it, upload the `site/` folder to any
static host (GitHub Pages, Netlify, an institutional server).

Every number on the page comes from `site/data.js`, which is generated from
`data/processed/counts_by_year.csv`; nothing is typed by hand. The page says it is
preliminary until a validation sample drawn with the filters on has been labelled.

### Look and logo

`site/assets/logo-white.png` is the Insect Welfare Research Society logo (white, on a
transparent background), supplied by Solimary García Hernández from the society's
website. It belongs to IWRS: confirm with them that it may appear on this page before
publishing. The colours are not taken from IWRS: the green band, accent and tint are
placeholders chosen for contrast (white on the band is 5.6:1 in light mode), set by
`--brand`, `--accent` and `--tint` at the top of `site/assets/style.css`. The typeface
is the system font; set `--font` in the same file to use the IWRS one. The colours of
the data series are a separate, validated palette and should not follow the brand.

### Events and theses (filled in by IWRS)

Talks, symposia, workshops, panels, other academic events and theses have no database.
`data/templates/IWRS_events_and_theses_template.xlsx` is an English template with dropdown
lists (rebuild it with `python tools/build_events_template.py`). IWRS fills it in, saves it as
`data/curated/IWRS_events_and_theses.xlsx` and runs `scripts/08_build_events_data.R`, which
checks every row, reports the problems with their spreadsheet row, and writes the counts to
`site/events.js`. The template has no field for personal names and the script refuses
e-mail addresses. Only items on welfare or sentience are counted; rows marked "Related" stay in
the list.

### Publishing the site

The workflow `.github/workflows/pages.yml` publishes the `site/` folder to GitHub Pages
whenever it changes. One-time setup on GitHub: make the repository public, then
Settings > Pages > Source: GitHub Actions.

### Members map

The membership list is personal data. Keep it in `data/private/` (git ignores it, along with
every `.xlsx`) and never commit it: `scripts/06_build_member_map_data.R` reads it on your own
computer and writes only counts per country to `site/members.js`, with countries of fewer
than `members.min_cell` members shown as "fewer than 3". The script finds the country column
by its header (or set `members.country_column`) and lists country spellings it does not
recognise; add them to `data/reference/country_names.csv`.

The map also has filters by general discipline, taxonomic expertise, research interest and
species expertise (`members.facets` in the config). Those columns are free text, so values
are split on commas, semicolons and "and" and can be merged through a private CSV
(`data/private/member_term_aliases.csv`, columns `term,canonical`; an empty `canonical` drops
a term). Only terms stated by at least `min_cell` members are published, and a country cell
below that carries no number. The contact, email, institution, department, rank and
timestamp columns are never read; membership type (career stage) is a filter. Even so, a filtered map narrows a group, so keep
`min_cell` at 5 or more (the published map uses 5) and review `site/members.js` before publishing. The country outlines
(`site/assets/world.js`) come from Natural Earth through `tools/build_world_assets.mjs`.

## Contact email for OpenAlex

OpenAlex gives faster, more reliable access to requests that identify a contact
address. The pipeline reads it from the environment variable `OPENALEX_MAILTO`, so
no personal address is committed. In R:

```r
usethis::edit_r_environ()   # opens ~/.Renviron; add the line below, save, restart R
# OPENALEX_MAILTO=you@example.org
```

## API key for OpenAlex

Downloading records (step 2) pages through ~17,000 results, and OpenAlex asks for a
free API key to page past the first page. Get one at https://openalex.org/settings/api
and add it next to the email in `~/.Renviron`:

```
OPENALEX_API_KEY=your-key
```

Restart R afterwards. The key is read from the environment and never committed; do not
paste request URLs in public, since they carry it.

## Status

Under development. See the commit history for what has been validated.
