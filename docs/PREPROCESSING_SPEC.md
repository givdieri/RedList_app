# PREPROCESSING SPECIFICATION

## Flanders fungal Red List helper application (v1)

This document defines the standalone preprocessing workflow that is executed once by the project owner before the Shiny application is used by expert reviewers.

The objective is to convert raw fungal occurrence data into stable, cleaned application inputs so that app users work only with reproducible standardized datasets and never with raw source files.

The primary backend dataset is the combined Flemish dataset based on:

* FUNBEL
* waarnemingen.be / Natuurpunt

with the combined dataset as the principal analytical source.

---

# 1. General design principles

## Preprocessing is separate from the app

The preprocessing pipeline must:

* run outside the Shiny application
* be executed manually by the project owner
* produce fixed app-ready input files
* preserve reproducibility
* preserve raw metadata
* log exclusions transparently

The Shiny app must:

* never clean raw data
* never perform taxonomic harmonization
* never modify source observations
* only use preprocessed outputs

---

# 2. Input files required

## Core biological data

### Required

### `Data_updated.xlsx`

Primary combined occurrence source.

This is the main backend dataset derived from FUNBEL and waarnemingen.be and should already represent the combined working dataset for the application.

Important existing fields include:

* Species
* Genus
* Old_name
* Nednaam
* Datum
* Year
* validatie
* ifbluurhok
* Eco1
* Eco1Groep
* Plaats
* Terrein
* Waarnemer
* Determinator
* Herbarium
* Substraat
* Wetnaam
* kommentaar
* Code
* Source.Name

This file is treated as the principal biological input.

---

## Spatial reference files

### Required

### `tblIFBLkwartier.csv`

Flemish IFBL reference table containing valid Flemish IFBL grid cells.

Important fields:

* IFBLuur
* ifbluurhok
* Xcoord
* Ycoord

This is used to retain only Flemish records.

### Important note

Despite legacy wording in old scripts, the operational analytical unit is:

## Uurhok = 2 × 2 km

This must remain the default analysis unit for v1.

---

# 3. Fields explicitly retained

The following fields must be preserved in preprocessing.

## Mandatory biological fields

* Species
* Genus
* Old_name
* Nednaam
* Datum
* Year
* validatie
* ifbluurhok

## Important metadata retained

* Plaats
* Terrein
* Waarnemer
* Determinator
* Herbarium
* Substraat
* Wetnaam
* kommentaar
* Code
* Source.Name

## Ecological metadata retained

* Eco1
* Eco1Groep

This is important for later ecological subgroup analyses and expert review.

---

# 4. Fields explicitly NOT required

These legacy files are not required for v1:

* xlsx1.xlsx
* xlsx2.xlsx
* xlsx3.xlsx
* xlsx4.xlsx
* Natuurpunt_taxa.xlsx
* Lat_Ned.xlsx
* species_info_publication_GBIF.xlsx
* FungalTraits.xlsx

These may be reintroduced later if needed.

They should not block the first implementation.

---

# 5. Validation handling

## Rule for v1

Retain all records.

The `validatie` field must be:

* preserved exactly as-is
* shown to users as the raw original field

No grouped validation classes should be created in preprocessing.

No automatic exclusion by validation state should occur in v1.

Example observed values:

* v
* o
* m
* p
* NA
* etc.

These must remain untouched.

Future versions may allow filtering by validation status.

---

# 6. Taxonomy handling

## Rule for v1

Use existing `Species` field as the working taxonomic field.

Do not implement an additional automatic taxonomic harmonization block.

Assume species names are already sufficiently harmonized for first implementation.

The old script performed many manual corrections, but this should not be reproduced automatically in preprocessing v1.

Instead:

* preserve raw `Species`
* preserve `Old_name`

and optionally create:

## `species_working`

which is initially identical to `Species`

This creates future flexibility without forcing unnecessary taxonomic rewriting.

---

# 7. Core preprocessing steps

---

## Step 1 — Load raw input

Read:

* `Data_updated.xlsx`
* `tblIFBLkwartier.csv`

---

## Step 2 — Basic structural checks

Verify presence of:

* Species
* Year
* ifbluurhok

Stop if missing.

Check:

* duplicate rows
* missing IFBL codes
* missing years
* impossible years

---

## Step 3 — Year filter

Retain only records with:

```r
Year >= 1800 & Year <= current_year
```

Default:

```r
current_year = 2025
```

This should be configurable.

Excluded rows must be logged.

---

## Step 4 — Remove obvious unresolved taxa

Remove:

* empty species names
* `sp.`
* malformed unresolved labels

Examples:

```r
sp.
sp
cf.
aff.
```

This should be transparent and logged.

---

## Step 5 — Flemish spatial filter

Retain only records with valid Flemish IFBL grid cells using:

```r
inner_join(Data_updated, provVL, by = "ifbluurhok")
```

where:

```r
provVL = tblIFBLkwartier.csv
```

This reproduces the old analytical logic.

This is the most important spatial filter.

---

## Step 6 — Preserve metadata

Retain all important metadata fields exactly as provided.

Do not simplify.

Do not aggregate yet.

This is essential for expert review later.

---

## Step 7 — Add internal fields

Create:

### `species_working`

Initially identical to:

```r
Species
```

### `include_in_analysis`

Default:

```r
TRUE
```

### `exclusion_reason`

Default:

```r
NA
```

These improve transparency and later reproducibility.

---

# 8. Output files

---

## Output A

# `app_inputs/records_clean.csv`

Full cleaned record-level table.

Contains all retained metadata.

Used for:

* species review
* raw record inspection
* expert validation
* downloadable tables

---

## Output B

# `app_inputs/grid_records_clean.csv`

Minimal analytical grid table.

Contains:

* species_working
* ifbluurhok
* year
* IFBLuur
* Xcoord
* Ycoord
* Eco1Groep

Used for:

* Criterion A
* Criterion B
* occupancy analyses
* trend calculations

---

## Output C

# `app_inputs/preprocessing_log.csv`

Transparent exclusion log.

Contains:

* record_id
* exclusion reason
* original values

Used for auditability.

---

# 9. What preprocessing does NOT do

Preprocessing must not:

* assign Red List categories
* calculate Criterion A
* calculate Criterion B
* estimate EOO
* estimate fragmentation
* estimate decline
* make expert decisions

Those belong inside the analytical application.

---

# 10. Future optional extensions

Later versions may add:

* validation filters
* stronger taxonomic harmonization
* fungal traits integration
* publication metadata
* Dutch/Latin synonym services
* expert override database
* versioned assessment snapshots

These are not required for v1.

---

# Final principle

## Preprocessing should be conservative

The goal is not to “improve” the biology automatically.

The goal is:

## stable reproducible expert assessment

with transparent rules and minimal hidden assumptions.
