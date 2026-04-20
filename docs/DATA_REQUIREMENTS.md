# DATA_REQUIREMENTS.md

# Data requirements — Flanders fungal Red List app (v1)

This document defines the required raw inputs for preprocessing and the expected generated inputs for the Shiny application.

The project follows a strict two-step architecture:

1. preprocessing (run once by project owner)
2. Shiny app use (many users, only on cleaned app inputs)

Users of the app should never work directly from raw source files.

---

# PRIMARY BACKEND DECISION

The operational v1 backend is the current combined working dataset represented by:

`Data_updated.xlsx`

with Flemish restriction applied through IFBL lookup tables.

This reproduces the legacy workflow most faithfully.

The original Funbel + waarnemingen.be split remains documented for provenance, but the app should work from the already combined working dataset.

---

# REQUIRED RAW INPUT FILES

These files are required for preprocessing.

---

## 1. Main occurrence dataset

### File

`data_raw/Data_updated.xlsx`

### Purpose

Primary fungal occurrence table used for all analyses.

This is the working combined dataset used in the legacy workflow.

### Required fields

Minimum required columns:

* Species
* Genus
* Soortnaam
* Datum
* Year (if absent, derive from Datum)
* Kwartier
* ifbluurhok
* Nednaam
* validatie
* Eco1
* Eco1Groep
* Substraat
* Plaats
* Terrein
* Waarnemer
* Determinator
* Old_name (if absent, can be rebuilt)

### Important notes

* retain all records
* do NOT exclude based on `validatie` in preprocessing
* preserve raw `validatie` field exactly as present
* preserve ecological metadata (`Eco1`, `Eco1Groep`)
* preserve metadata fields for expert review
* species names are assumed mostly harmonized already

---

## 2. Flemish IFBL reference table

### File

`data_raw/tblIFBLkwartier.csv`

### Purpose

Defines which IFBL cells belong to Flanders and provides coordinates.

Used to reproduce legacy:

`condensAllVL <- inner_join(Data_updated, provVL, by = "ifbluurhok")`

### Required fields

* IFBLuur
* ifbluurhok
* Xcoord
* Ycoord

### Example structure

```r
str(provVL)

'data.frame': 15728 obs. of 5 variables:
$ X          : int
$ IFBLuur    : chr
$ ifbluurhok : chr
$ Xcoord     : int
$ Ycoord     : int
```

### Important note

This file defines Flemish inclusion.

No separate province filter should be used.

---

## 3. Ecodistrict lookup table

### File

`data_raw/tblIFBLkwartierhokEcodistrict.csv`

### Purpose

Used for:

* ecodistrict completeness diagnostics
* fragmentation analyses
* Criterion B support

### Required fields

* IFBLuurhok
* REGIO
* DISTRICT

These are renamed during preprocessing to:

* ifbluurhok
* Ecoregio
* Ecodistrict

---

# REQUIRED SPATIAL FILES

These are needed for maps and Criterion B support.

Stored under:

`spatial/`

---

## 4. IFBL grid shapefile

### File

`spatial/ifbl01x01.*`

### Purpose

Grid geometry for mapping occupancy and fragmentation.

Used for:

* species maps
* fragmentation
* AOO support
* spatial diagnostics

### Note

Legacy code refers to this as 1x1 geometry, but operationally the workflow uses:

## uurhok = 2 × 2 km

This is the main default analytical unit.

---

## 5. Ecodistrict shapefile

### File

`spatial/ecodistrict2002.*`

### Purpose

Used for:

* ecodistrict completeness maps
* fragmentation context
* Criterion B interpretation

---

## 6. Ecoregion shapefile

### File

`spatial/ecoregio2002.*`

### Purpose

Optional broader-scale visualization.

Not critical for v1 calculations.

---

## 7. Vlaanderen boundary object

### Legacy object

`Vlaanderen.Rdata`

### Purpose

Legacy plotting overlay.

Optional in v1 if replaced by sf boundaries.

---

## 8. Main rivers object

### Legacy object

`Hoofdrivieren.Rdata`

### Purpose

Legacy plotting overlay.

Optional in v1.

Purely visual.

---

# FILES NOT REQUIRED FOR V1

These were used historically but are NOT required for first implementation.

Do not block development waiting for them.

---

## Not required

* xlsx1.xlsx
* xlsx2.xlsx
* xlsx3.xlsx
* xlsx4.xlsx
* Natuurpunt_taxa.xlsx
* Lat_Ned.xlsx
* species_info_publication_GBIF.xlsx
* FungalTraits.xlsx

These can be added later as enrichment layers only.

They are not required for:

* preprocessing
* Criterion A reproduction
* initial Criterion B implementation
* expert review workflow

---

# GENERATED PREPROCESSED FILES

Created by:

`scripts/01_preprocess_flanders_redlist_data.R`

Written to:

`app_data/`

---

## Required outputs

### Main cleaned dataset

`app_data/records_clean.csv`

Contains:

* cleaned records
* Flemish-only subset
* retained metadata
* preserved validatie
* eco fields
* IFBL coordinates

---

### Species summary table

`app_data/species_summary.csv`

Contains per-species summaries for:

* occupancy
* first/last year
* total records
* current records
* historical records
* DD candidate flags
* RE candidate flags

---

### Criterion A input table

`app_data/criterion_a_input.csv`

Legacy-compatible basis for:

* historical occupancy
* current occupancy
* relative decline
* noTrend detection
* DD/RE handling

---

### Criterion B input table

`app_data/criterion_b_input.csv`

Transparent basis for:

* current occupancy
* fragmentation
* continuing decline
* optional EOO support

---

### Survey effort diagnostics

`app_data/survey_effort.csv`

Contains:

* yearly effort
* IFBL coverage
* ecodistrict completeness
* shared quadrants

---

### Default settings

`app_data/settings_defaults.yml`

Contains all default thresholds.

These must remain editable inside the app.

No analytical thresholds should be hard-coded.

---

# DEFAULT SPATIAL UNIT DECISION

## Default = uurhok (2 × 2 km)

This reproduces the legacy workflow.

---

## Optional advanced setting

Quarter-grid (1 × 1 km equivalent)

may be offered later as a user-selectable option.

But:

## v1 default remains 2 × 2 km

for legacy compatibility.

---

# IMPORTANT METHODOLOGICAL RULES

---

## DD default rule

Default:

DD if occupied IFBL grids < 5

in BOTH:

* historical period
* current period

BUT:

this threshold must be fully user-settable.

Never hard-code it.

---

## Historical/current split

Default:

* historical = ≤ 2000
* current = > 2000

BUT:

the cutoff year must be user-settable.

Default only.

---

## Validation handling

For v1:

* retain all records
* preserve raw `validatie`
* show field in raw records tab

No automatic filtering by validation class.

---

## Final category

The final Red List category is:

## expert-reviewed

not fully automated.

The app supports decisions.

It does not replace expert judgement.

---
