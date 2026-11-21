# Labeling guide for the validation sample

File: `data/raw/validation_sample.csv` (one record per row, shuffled). Open it as
**UTF-8** (in Excel: Data > From Text/CSV and choose UTF-8; Numbers and RStudio read
it correctly). Fill three columns and save as CSV (UTF-8).

## The question

> Is the paper about the **welfare, sentience, affective states, consciousness or
> nociception/pain of the invertebrate animals themselves**, that is, treating the
> animal as a subject whose experience could matter (or as evidence about whether it
> does)?

Read the title and the abstract. Judge the paper's **main subject**, not whether a
keyword appears. The file does not say why a record was selected, on purpose: judge each paper on its own.

Some rows have an empty `abstract`. Judge those
from the title and open the `doi` link if the title is not enough; use `?` when you cannot
tell. They are sampled separately so that their precision is reported on its own.

## `relevance`

| Code | Meaning | Examples |
|------|---------|----------|
| `2` | **Core.** Directly about welfare, sentience, affect/emotion, consciousness or pain of invertebrates, empirical or conceptual. | Welfare of farmed insects or crustaceans; evidence of pain-like states in crabs; theory of insect sentience; welfare-aware slaughter methods |
| `1` | **Indirect.** Studies mechanisms or behaviour that bear on the above, without welfare or sentience framing. | Genetics of nociception in *Drosophila*; cognitive bias in bees; anaesthesia effects on fly consciousness-like states |
| `0` | **Not relevant.** The keyword is there for another reason (give a reason code). | see below |
| `?` | You cannot decide from title and abstract. | |

## `reason_if_0` (only when `relevance` is 0)

| Code | Meaning |
|------|---------|
| `human_welfare` | Human or economic welfare / well-being (farmers, ecosystem services, welfare economics) |
| `venom_pharm` | Venom or toxin pharmacology; pain in humans or vertebrates |
| `human_emotion` | Human emotion or fear of the animal (e.g. arachnophobia) |
| `plant_damage` | "Suffering" or damage in plants or crops caused by insects |
| `vertebrate` | The welfare or pain studied is in vertebrates; invertebrates only mentioned |
| `other` | Anything else (explain in `notes`) |

Use `notes` for doubtful cases and for anything that suggests a new search rule
(for example a term that keeps bringing in the wrong papers).

## What happens next

The labels give the precision of each state block and taxon group (weighted, because
the sample is stratified; see `data/validation/sample_ids.csv`). With them we decide
whether to tighten the search strings or to screen all abstracts with a classifier
validated against your labels.
