# Decisions and results log

Dated notes on what was decided and why, so the report can say how the numbers were made.

## 2026-11-21 Definitions
- Two steps: a broad OpenAlex search (animal name x state word, title or abstract), then a local
  strict *core* (animal word within 6 words of a state word of one of five blocks).
- Minimum cell for aggregated member data: 5.

## 2026-11-24 First validation (460 papers labelled by hand, stratified)
- Share of each block that is on topic (core or indirect): sentience 90%, welfare 29%,
  consciousness 33%, nociception_pain 29%, affect_emotion 16%. Whole core: 31% on topic
  (20% strictly core). The core catches about 74% of the on-topic papers that were retrieved.
- Most non-relevant papers are coded `other`: the animal word in another sense (crab mentality,
  algorithms named after animals, poetry), clinical case reports with a pain word, leech therapy,
  insects as disease vectors, welfare as human or economic welfare, `conscious` as an adjective.
  The rest is human emotion (affect_emotion) and venom pharmacology (nociception_pain).
- Decision: add two general filters, animal as subject and exclusion of fields far from biology
  (`core.filters` in the config). Medicine, Arts and Humanities, Social Sciences, Psychology and
  Pharmacology are not excluded until a fresh sample can test it, because the philosophy of
  sentience sits in some of them. A rule on human-context words for affect_emotion and
  nociception_pain (rule C) is held back until A and B have been reviewed.
- The filters were designed looking at the 460 labelled papers, so `04b` is optimistic. The
  figure to publish comes from a fresh sample (another `sampling.seed`) drawn with the filters on.

## 2026-11-25 Filters A and B on the labelled sample (script 04b)
- Both filters: share on topic in the core 31% -> 37%, 97% of the on-topic papers kept. The subject
  filter does most of it; the field filter adds about two points.
- By field (labelled papers on topic): Medicine 2 of 29, Pharmacology 0 of 11, Immunology and
  Microbiology 1 of 9, Biochemistry 0 of 5; Arts and Humanities 21 of 46, Social Sciences 22 of 43.
- Decision: also exclude Medicine, Pharmacology, Immunology and Microbiology, Biochemistry (3 of 54
  labelled papers on topic; about a third of the labelled papers that were not on topic are in these
  four fields). Chosen after reading the labels, so the fresh sample has to test it.

Result with the 18 excluded fields (04b, same labelled sample): share on topic in the core 31% -> 52%,
96% of the on-topic papers kept; core 2,361 -> 1,302 papers. By block: welfare 49%, nociception_pain 59%,
consciousness 44%, affect_emotion 25%, sentience 94%. Optimistic: the filters were designed on these labels.

## 2026-11-25 Subject filter exempt for sentience and consciousness; rule C for affect_emotion
- The 13 on-topic labelled papers lost in the core strata were mostly general papers on animal
  sentience that mention an invertebrate once ("Animal sentience", "The sentience shift in animal
  research", "Precis of The Edge of Sentience"), removed by the subject filter, plus a few in
  Medicine, Immunology, Engineering and Nursing removed by the field filter.
- Decision: the subject filter no longer applies to sentience (90% on topic without it) nor to
  consciousness (33% -> 35% with it). `core.filters.subject_exempt_blocks`.
- Rule C (`core.filters.human_context`): in affect_emotion a paper fails when title + abstract hold
  at least 2 words about people (patients, consumers, students, participants...). The word list was
  written before measuring it; first test is 04b ("all rules") on the labelled sample.

## 2026-11-25 All rules on the labelled sample (round 1)
- Share on topic in the core 31% -> 56%, 97% of the on-topic papers kept. By block: sentience 92%,
  nociception_pain 59%, welfare 49%, affect_emotion 48% (88% of its on-topic papers kept),
  consciousness 42%. Core after step 02c: 1,225 papers (2,361 match the word pattern).
- Next: a fresh sample (round 2, script 03b, seed 2027, without the papers of round 1) gives the
  figure to publish. Its estimate describes the papers not drawn in round 1.

## 2026-11-25 The papers of the latest year are read in full
- The page opens on the current year to date. Its list has about 150 papers, so all of them are read by hand
  (scripts 10 and 11): by the author and, if they agree, by volunteers of IWRS, which gives the agreement between
  reviewers and a list of disagreements to resolve. Earlier years stay estimates, measured with the fresh sample
  (round 2). The two do not replace each other: the review gives the verified count of the year, the sample gives
  the precision of the method for all years.
- Abstracts are not published on the page or in the downloads (publisher text); the DOI leads to them.

## 2026-11-25 A language model reads the core papers (scripts 12 and 13)
- Idea of the author: instead of labelling a sample to estimate precision and leaving the core as it is, have a model read
  title and abstract of every core paper (about 1,200, 97% with abstract) and label it 2, 1, 0 or ?; papers labelled 0 leave
  the core, 1 and 2 stay, and a person reads only the doubtful ones (? or low confidence).
- The labels of the model are trusted only as far as they agree with the author's: the fresh sample (round 2) is labelled by
  hand and script 12 compares. It reports agreement, kappa and, for the part the model decides alone, how many on-topic papers
  it would drop and how much noise it would keep. The sample is therefore still needed: it is the measure of the model.
- The model can only remove papers from the core. What the core misses (papers in the broad set that it leaves out) is still
  estimated from the sample.
- The page will have to say how the number was made (a model with the labelling guide, checked against N labels, agreement X).
- Scripts were tested offline against a mock; the first real call (LLM_LIMIT=5) is the test of the request.

## 2026-11-25 The reading is done in a conversation first
- No API key for now. Claude reads the papers in batches of 100 that the author attaches to the conversation (script 14),
  and writes the labels to the repository (`data/validation/claude_labels_core.csv`, ids and labels only); script 15 checks
  them and builds the same outputs as the API path (steps 12 and 13). The sample is read blind: its files carry none of the
  author's labels. When the pipeline works and IWRS sees the result, IWRS can pay for the API so that next year's rerun does
  not need a conversation.
- The labels are Claude's and the report must say so. The doubtful ones (? or low confidence) are read by people.

## Open
- Final list of excluded fields, after reading `04b`.
- Result of rule C on the labelled sample.
- Fresh validation sample.
- IWRS to fill in the events and theses template.
- Study-type ratio (conceptual vs empirical) is deferred.
