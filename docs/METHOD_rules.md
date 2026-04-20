# METHOD RULES

## Non-negotiable methodological rules

### Flanders fungal Red List helper application (v1)

This document defines the core methodological rules that must not be changed during implementation unless explicitly revised by expert decision.

These rules override implementation convenience.

The objective is methodological consistency, transparency, and reproducibility.

---

# 1. General philosophy

The application is a:

## decision-support system

not an automatic Red List classifier.

The system must:

* calculate evidence
* expose assumptions
* preserve transparency
* support expert interpretation

The system must not:

* silently assign final categories
* hide assumptions
* replace expert judgement

Final Red List categories remain expert-reviewed.

---

# 2. Primary backend

## Mandatory backend source

The primary backend is:

## combined FUNBEL + waarnemingen.be dataset

represented operationally by:

```text id="vmdzzm"
data_raw/Data_updated.xlsx
```

with Flemish restriction applied through IFBL spatial reference tables.

This replaces older separated workflows.

The implementation must not revert to:

* FUNBEL-only workflow
* waarnemingen.be-only workflow

unless explicitly requested for comparison purposes.

---

# 3. Preprocessing separation

## Mandatory rule

Preprocessing must be separate from the app.

Raw data cleaning:

* happens once
* is run manually by the project owner
* produces fixed app inputs

The Shiny app must:

* never clean raw files
* never modify source observations
* only use processed inputs

This is required for reproducibility.

---

# 4. Criterion A priority

## First implementation priority

The first implementation must reproduce:

## legacy Criterion A workflow

as closely as possible.

Criterion A is the primary validation anchor.

If Criterion A does not reproduce legacy behavior, the implementation is not considered valid.

Criterion B may be improved and rebuilt more transparently.

Criterion A must remain conservative and legacy-compatible.

---

# 5. Criterion A default rules

## Historical vs current periods

Default split:

```r id="yo75pf"
historical <= 2000
current >= 2001
```

but this must be user-settable.

---

## Spatial unit

Default analytical unit:

## IFBL uurhok = 2 × 2 km

This must remain the default.

Future optional support for finer grids is allowed, but not as the default.

---

## DD default rule

Default:

## occupied IFBL grids < 5 in both periods

assigned as:

## DD

This threshold must be user-settable.

Defaults must not be hard-coded.

---

## RE default rule

Default:

Species present historically and absent in the current period:

## RE

unless expert review overrides.

---

# 6. Thresholds must be configurable

## Mandatory rule

Thresholds must never be permanently hard-coded.

Defaults are allowed.

Users must be able to modify:

* historical/current split year
* DD threshold
* Criterion A decline thresholds
* fragmentation thresholds
* decline model thresholds
* minimum survey effort thresholds
* Criterion B supporting thresholds

The application must expose settings clearly.

---

# 7. Criterion B philosophy

## Criterion B must be rebuilt transparently

Do not blindly reproduce the old Criterion B script.

The old implementation contained opaque assumptions.

The new implementation must prioritize:

* current-period continuing decline
* fragmentation
* transparent supporting evidence

rather than black-box outputs.

---

# 8. EOO rule

## EOO is supplementary

Extent of Occurrence (EOO):

* may be calculated
* may be visualized
* may support expert interpretation

but:

## EOO is not the main Flemish Criterion B emphasis

because Flanders is spatially small and EOO is often biologically less informative for fungal assessments.

Criterion B should focus primarily on:

* continuing decline
* fragmentation
* occupancy structure

---

# 9. Validation handling

## v1 rule

Retain all records.

Do not automatically exclude records by validation state.

The raw field:

```text id="rftx0r"
validatie
```

must be:

* preserved exactly as-is
* visible in the application
* available for filtering and review

No grouped validation classes should be created in v1.

Future versions may allow stricter filtering.

---

# 10. Taxonomy handling

## v1 rule

Use the existing:

```text id="f5pt8l"
Species
```

field as the working taxonomic field.

Do not add a second automatic taxonomic harmonization layer.

Preserve:

* Species
* Old_name

Optional internal field:

```text id="iij8go"
species_working
```

may initially equal `Species`.

This allows later expansion without hidden taxonomic rewriting.

---

# 11. Metadata retention

## Mandatory rule

Raw metadata must be preserved.

Do not over-simplify records.

Important retained fields include:

* Plaats
* Terrein
* Waarnemer
* Determinator
* Herbarium
* Substraat
* Wetnaam
* kommentaar
* Nednaam
* Old_name
* validatie
* Eco1
* Eco1Groep

Users must be able to inspect raw underlying records for each species.

This is essential for expert review.

---

# 12. Expert note fields

## Mandatory rule

Each criterion and category decision must include:

## editable expert notes

Examples:

* Criterion A notes
* Criterion B notes
* DD justification
* Final category justification

These notes must be exportable.

The app must support documentation of expert reasoning.

---

# 13. Final category assignment

## Mandatory rule

Final category is expert-reviewed.

The system may suggest:

* Criterion A category
* Criterion B category
* combined candidate category

but must not silently finalize the Red List class.

Expert override must always be possible.

Final category must be editable.

---

# 14. Legacy code use

## Mandatory rule

Legacy code is:

## reference material only

stored in:

```text id="9u7d5g"
legacy_code/
```

It must be used to:

* understand methodology
* reproduce historical behavior

It must not be copied blindly into production code.

Production code must be:

* modular
* readable
* documented
* maintainable

---

# 15. Transparency over convenience

## Final implementation principle

Never optimize for convenience at the expense of transparency.

Especially for:

* Criterion A
* DD
* fragmentation
* decline
* final category assignment

every rule must be explainable.

If a method cannot be explained clearly, it should not be implemented.
