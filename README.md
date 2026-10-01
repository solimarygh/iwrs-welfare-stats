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
conscious*, welfare, nociception, pain), searched in title and abstract. "affect" alone
is not used, because as a verb it is noise. Terms with frequent non-biological
meanings (cricket*, ant, tick, ...) are excluded by default and can be switched on for
a sensitivity analysis (`search.include_noisy`).

"Peer-reviewed" is approximated by OpenAlex document type `article` or `review` in
a journal-type source. The current calendar year is partial and is flagged as such.

## Requirements

R >= 4.3 with `yaml`, `httr2`, `dplyr`, `tidyr`, `readr`, `jsonlite`, `ggplot2`.
`renv` lock file to be added once the pipeline is validated against the live API.

## Contact email for OpenAlex

OpenAlex gives faster, more reliable access to requests that identify a contact
address. The pipeline reads it from the environment variable `OPENALEX_MAILTO`, so
no personal address is committed. In R:

```r
usethis::edit_r_environ()   # opens ~/.Renviron; add the line below, save, restart R
# OPENALEX_MAILTO=you@example.org
```

## Status

Under development. See the commit history for what has been validated.
