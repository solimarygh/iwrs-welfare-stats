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

## Open
- Final list of excluded fields, after reading `04b`.
- Rule C.
- Fresh validation sample.
- IWRS to fill in the events and theses template.
- Study-type ratio (conceptual vs empirical) is deferred.
