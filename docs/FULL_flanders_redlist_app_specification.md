# Extended Shiny Red List App for Flanders Fungi

## 1. Purpose

This application is intended as a decision-support platform for fungal Red List assessment in Flanders. It will use the **combined dataset** derived from Funbel and waarnemingen.be as the primary analytical backend. The app should not function merely as a calculator. Instead, it should provide a transparent workflow that integrates occurrence data, taxonomic harmonization, survey-effort diagnostics, criterion-specific evidence, spatial outputs, and expert annotation.

The application should help assessors:

- inspect all records underlying an assessment
- quantify historical and recent occupancy patterns
- evaluate data quality and survey completeness
- generate provisional evidence for Criteria A and B
- document expert interpretation and final Red List category decisions
- export consistent assessment products for review and publication

A separate **preprocessing script** should be used to clean and harmonize the raw data once before multi-user app deployment.

---

## 2. Conceptual workflow

The system should be split into two major components.

### 2.1 Preprocessing pipeline

This is a standalone R workflow run by the project owner before the app is used by other people.

Its tasks are to:

- import raw datasets
- harmonize field names
- standardize taxonomy
- assign dates and years
- assign spatial units such as IFBL quarter-grids, 1 km cells, ecodistricts, and ecoregions
- flag and log excluded records
- join species metadata and fungal trait information
- write clean and analysis-ready files for the app

This preprocessing should be run only when input data or lookup tables are updated.

### 2.2 Shiny application

This is the interactive frontend for assessors.

Its tasks are to:

- load the preprocessed dataset and supporting layers
- allow filtering by species and metadata
- visualize records and survey effort
- calculate criterion support metrics reactively
- display provisional Red List suggestions
- allow expert override and note-taking
- export assessment outputs

---

## 3. Core analytical goals

The app should support the following analytical questions for each species.

### 3.1 Data and taxonomic reliability

- Is the name accepted and harmonized?
- Are there known synonym or aggregate issues?
- What proportion of records are validated?
- What is the temporal and spatial coverage of the records?
- Are there enough recent and historical records for inference?

### 3.2 Historical change

- How many distinct IFBL quarter-grids were occupied in the historical and recent period?
- How did relative occupancy change after correcting for unequal survey effort?
- How sensitive is the inferred trend to the selected period definitions?

### 3.3 Current distribution and rarity

- What is the current Area of Occupancy?
- What is the current Extent of Occurrence?
- How fragmented is the occupied range?
- How many locations may plausibly be present?
- Is there evidence for continuing decline?

### 3.4 Final assessment support

- Which criteria are supported by the evidence?
- What provisional category is suggested?
- What uncertainty flags apply?
- What final category does the expert choose and why?

---

## 4. Recommended app structure

## Tab 1. Overview

Purpose: provide a dataset-level dashboard.

Contents:

- total number of records
- total number of species
- temporal distribution of records
- records by source
- number of validated versus excluded records
- map of all recent occupied grids in Flanders
- map of survey coverage by ecodistrict
- warning panel for missing metadata or processing issues

This tab should help users understand the completeness and quality of the backend dataset.

## Tab 2. Species explorer

Purpose: serve as the main entry point for species-level assessment.

Contents:

- species search box
- accepted Latin name
- Dutch name
- genus, family, order
- source composition summary
- validation summary
- taxonomic notes
- quick indicator cards such as:
  - total records
  - historical grids
  - recent grids
  - recent AOO
  - EOO
  - provisional category snapshot

This tab should behave as the control center for each taxon.

## Tab 3. Records

Purpose: inspect the underlying occurrences.

Contents:

- searchable data table
- filters for source, validation status, time period, ecodistrict, ecoregion, coordinate precision, and substrate or guild where available
- downloadable filtered record table
- record-level flags such as:
  - non-validated
  - taxonomically uncertain
  - inferred or centroid-based location
  - date parsing issue
  - excluded from calculations

This tab should maximize transparency and facilitate expert review.

## Tab 4. Maps

Purpose: inspect spatial distribution.

Contents:

- interactive leaflet map
- recent versus historical symbols
- IFBL grid overlay
- ecodistrict overlay
- ecoregion overlay
- source-coloured or validation-coloured points
- option to view occupied quarter-grids rather than raw points
- repeated-survey grids
- convex hull or EOO polygon
- connected-fragment display for fragmentation support

This tab should support spatial interpretation for Criteria A and B.

## Tab 5. Effort diagnostics

Purpose: quantify survey effort and assessability.

Contents:

- number of records per year
- number of occupied grids per year
- number of sources per year
- source composition over time
- map of surveyed grids by period
- overlap between historical and recent survey coverage
- map of well-surveyed ecodistricts
- user-adjustable threshold for well-surveyed units
- assessability flag for trend calculation

This tab is essential because the historical trend calculations depend strongly on unequal effort.

## Tab 6. Criterion A

Purpose: provide historical trend evidence.

Contents:

- default period comparison, initially 1800 to 2000 versus 2001 to current end year
- occupied IFBL grids by period
- total surveyed IFBL grids by period
- relative occupancy by period
- percentage change between periods
- classification suggestion under the current script-compatible logic
- sensitivity analysis under alternative cut years
- optional decadal occupancy plot
- optional model-based trend display if implemented later
- explanation of whether the species is treated as DD, RE, assessable, or too common for the current heuristic workflow

This tab should reproduce the old workflow faithfully at first, then extend it.

## Tab 7. Criterion B

Purpose: provide current rarity and distribution evidence.

Subsections:

### B1. EOO

- EOO calculation from recent records
- EOO polygon display
- number of spatial points contributing
- warning if too few points are present

### B2. AOO

- AOO based on the chosen formal cell size
- optional parallel display of occupied IFBL quarter-grids for Flemish comparability
- map of occupied cells

### Fragmentation

- connected-component or cluster display
- number of fragments
- area per fragment
- proportion in largest fragment
- automated heuristic support flag
- expert override field

### Continuing decline

- recent yearly occupancy trend
- normalized yearly occupancy by effort
- slope and fit metrics if a simple method is retained
- optional smoother or model fit in future versions

### Locations

- expert-entered number of locations
- optional suggested value based on clustered records and threat geography
- explanation that locations are threat-defined and not purely grid-defined

### Provisional category

- criterion support summary
- suggested B1 or B2 category
- uncertainty notes

This tab should be a major improvement over the old script because Criterion B was previously approximate and partially hidden in the code.

## Tab 8. Expert decision sheet

Purpose: document final judgments.

Contents:

- provisional A category
- provisional B category
- final selected category
- selected criteria and subcriteria code
- free-text rationale
- uncertainty score or confidence field
- taxonomic note field
- habitat decline note field
- reviewer name
- assessment date
- export or save action

This tab is necessary because Red Listing requires documented expert interpretation, not only automated output.

## Tab 9. Admin and settings

Purpose: expose configurable rules.

Contents:

- historical and recent period definitions
- threshold for well-surveyed ecodistricts
- minimum grids required for Criterion A calculation
- AOO cell size used for formal assessment
- whether script-compatible logic or updated logic is used
- lookup table versions in use
- output directory controls

---

## 5. Separate preprocessing script

A separate script should be created and run once before deploying the app for other users.

Suggested name:

`01_preprocess_flanders_redlist_data.R`

Its outputs should be written to an `/app_data/` directory as serialized `.rds` and `.csv` files.

### 5.1 Main tasks of the preprocessing script

#### A. Import raw datasets

- Funbel source file
- waarnemingen.be export files
- species metadata files
- taxonomic harmonization files
- spatial lookup tables

#### B. Standardize field names

Create a single common schema, for example:

- `record_id`
- `source_dataset`
- `source_record_id`
- `species_original`
- `species_accepted`
- `species_status`
- `dutch_name`
- `date_original`
- `date_parsed`
- `year`
- `month`
- `validation_status`
- `ifbl_quarter`
- `ifbl_1km`
- `x_l72`
- `y_l72`
- `lon_wgs84`
- `lat_wgs84`
- `ecodistrict`
- `ecoregion`
- `province`
- `family`
- `order`
- `guild`
- `substrate`
- `host`
- `record_flag`
- `include_in_analysis`
- `exclusion_reason`

#### C. Taxonomic harmonization

- replace hard-coded substitutions with a synonym table
- preserve the original submitted name
- generate accepted names
- implement clear rules for `sp.`, `s.s.`, and `s.l.`
- log excluded or merged names

#### D. Validation filtering

- create a unified validation field
- retain excluded records in an audit file rather than dropping them silently
- mark records as used or excluded

#### E. Date parsing and QC

- parse dates robustly
- derive year and month
- flag impossible or missing years
- optionally keep date precision class

#### F. Spatial harmonization

- assign IFBL quarter-grid for all records
- if point coordinates are available, also assign 1 km or other grid systems as needed
- join ecodistrict and ecoregion
- flag records outside Flanders or outside valid IFBL units

#### G. Duplicate handling

- generate duplicate keys
- optionally remove exact duplicates or collapse same species × grid × year duplicates for criterion calculations
- retain raw record counts separately from condensed counts

#### H. Trait and metadata enrichment

- join Dutch names
- join family and order
- join fungal guilds and habitat information where available
- join publication or GBIF support metadata if desired

#### I. Write clean outputs

At minimum, write:

- `records_clean.rds`
- `records_analysis.rds`
- `species_master.rds`
- `excluded_records.csv`
- `taxon_audit.csv`
- `survey_units.rds`
- `settings_defaults.yml` or `.csv`

---

## 6. Documents and files needed to generate the app

The following files should be assembled before implementation.

### 6.1 Mandatory biological data inputs

#### 1. Combined occurrence dataset

Preferred form:
- one pre-merged table of Funbel + waarnemingen.be records

Alternative form:
- raw Funbel dataset
- raw waarnemingen.be exports
- merge script to create the combined dataset

Required fields should include as many of the following as possible:
- scientific name
- original scientific name
- Dutch name
- date
- year if already present
- validation status
- source dataset
- coordinate fields if available
- IFBL quarter-grid or other spatial code
- observer or recorder metadata if permitted
- notes

#### 2. Taxonomic harmonization table

A table with at least:
- original name
- accepted name
- taxonomic status
- notes
- whether the name should be excluded, merged, or retained

This should replace hard-coded substitutions.

#### 3. Species metadata table

At minimum:
- accepted species name
- Dutch name
- family
- order
- optional publication metadata
- optional expert notes

#### 4. Fungal trait table

Recommended fields:
- genus
- guild
- trophic mode
- substrate
- host association
- habitat affinity
- detectability flag
- taxonomic difficulty flag

This will allow the app to become biologically more informative.

### 6.2 Mandatory spatial inputs

#### 5. IFBL quarter-grid lookup table for Flanders

Needed to:
- restrict analyses to Flemish units
- summarize occupancy
- map records and survey effort

Required fields may include:
- IFBL quarter-grid code
- coordinates or centroid
- valid-in-Flanders flag

#### 6. IFBL quarter-grid shapefile or geopackage

Needed for:
- static maps
- leaflet overlays
- AOO or occupancy visualization

#### 7. Flanders boundary layer

Needed for:
- clipping
- plotting
- overview maps

#### 8. Ecodistrict boundary layer

Needed for:
- well-surveyed ecodistrict calculations
- ecodistrict summaries
- spatial stratification

#### 9. Ecoregion boundary layer

Recommended for broader ecological summaries.

#### 10. Hydrography or major rivers layer

Optional. Useful only if you still want the current cartographic style.

### 6.3 Recommended support files

#### 11. Settings file

A small configuration file storing default choices such as:
- period 1 start and end year
- period 2 start and end year
- minimum grids for Criterion A eligibility
- threshold for well-surveyed ecodistricts
- default AOO cell size
- output directories

#### 12. Exclusion rules table

A table documenting which records should be automatically excluded and why, for example:
- invalid date
- outside Flanders
- non-validated observation
- unresolved taxon
- duplicate

#### 13. Expert notes template

A blank file or database table to store assessment notes, reviewer names, final categories, and rationale.

#### 14. Historical habitat or threat support data

Optional but highly desirable if criterion support should include:
- habitat decline
- host decline
- nitrogen deposition pressure
- forest age or structure decline
- wetland loss or other pressure layers

This would strengthen criterion interpretation beyond pure occurrence patterns.

---

## 7. Proposed directory structure

A clean project structure is strongly recommended.

```text
flanders_redlist_app/
├── app.R
├── R/
│   ├── mod_overview.R
│   ├── mod_species.R
│   ├── mod_records.R
│   ├── mod_maps.R
│   ├── mod_effort.R
│   ├── mod_criterion_a.R
│   ├── mod_criterion_b.R
│   ├── mod_decision.R
│   ├── helpers_data.R
│   ├── helpers_spatial.R
│   ├── helpers_plots.R
│   └── helpers_redlist.R
├── scripts/
│   ├── 01_preprocess_flanders_redlist_data.R
│   ├── 02_build_app_inputs.R
│   └── 03_batch_export_reports.R
├── app_data/
│   ├── records_clean.rds
│   ├── records_analysis.rds
│   ├── species_master.rds
│   ├── excluded_records.csv
│   ├── taxon_audit.csv
│   └── settings_defaults.yml
├── data_raw/
│   ├── funbel/
│   ├── waarnemingen/
│   ├── taxonomy/
│   ├── traits/
│   └── metadata/
├── spatial/
│   ├── flanders_boundary/
│   ├── ifbl_quarter_grid/
│   ├── ecodistricts/
│   ├── ecoregions/
│   └── hydrography/
├── exports/
│   ├── tables/
│   ├── plots/
│   └── reports/
└── docs/
    ├── app_specification.md
    ├── data_dictionary.md
    └── method_notes.md
```

---

## 8. Recommended analytical logic to preserve from the old script

The following legacy logic should initially be retained for compatibility.

### 8.1 Criterion A legacy-compatible mode

- historical period occupancy in IFBL quarter-grids
- recent period occupancy in IFBL quarter-grids
- standardization by the number of surveyed quarter-grids in each period
- relative occupancy comparison
- resulting percentage trend
- threshold-based classification into CR, EN, VU, NT, LC
- DD and RE handling for species with too few or no recent records

This should allow direct comparison between old and new outputs.

### 8.2 Well-surveyed ecodistrict logic

The app should calculate:
- historical and recent species richness per IFBL quarter-grid
- repeatedly surveyed grids
- ecodistrict coverage based on repeatedly surveyed grids

However, the threshold must be exposed clearly and documented, because the old script comments and code were inconsistent.

---

## 9. Recommended analytical improvements beyond the old script

### 9.1 Criterion A improvements

- allow adjustable period boundaries
- add sensitivity plots
- display decadal occupancy trajectories
- optionally add a model-based trend later
- separate raw occupancy change from effort-corrected change
- make the `noTrend` rule explicit and configurable

### 9.2 Criterion B improvements

- implement EOO formally
- distinguish between IFBL occupancy and formal AOO
- provide a transparent fragmentation panel
- treat locations as an expert-reviewed quantity
- replace hidden or arbitrary decline heuristics with documented diagnostics

### 9.3 Uncertainty and quality scoring

For each species, the app should generate a small uncertainty panel based on:
- number of recent records
- number of historical records
- proportion validated
- taxonomic uncertainty
- source imbalance
- spatial clustering
- missing or inferred coordinates

### 9.4 Assessment reproducibility

Every final decision should store:
- app settings used
- input data version
- lookup table versions
- assessment date
- reviewer identity

---

## 10. Priority implementation order

## Phase 1. Backend and preprocessing

- build unified combined dataset
- create taxonomic harmonization lookup
- assign IFBL and ecodistrict fields
- generate clean and excluded record tables
- build species metadata table

## Phase 2. Minimal Shiny shell

- species selector
- record table
- basic maps
- dataset overview

## Phase 3. Survey effort diagnostics

- annual records plots
- surveyed grid maps
- repeated-survey logic
- ecodistrict coverage maps

## Phase 4. Criterion A module

- reproduce legacy workflow
- add parameter controls and sensitivity outputs

## Phase 5. Criterion B module

- AOO and EOO
- fragmentation support
- continuing decline diagnostics
- locations panel

## Phase 6. Decision sheet and exports

- final category form
- rationale field
- report exports
- batch summary exports

## Phase 7. Biological enrichment

- habitat and guild layer
- external pressure layers if available
- advanced uncertainty scoring

---

## 11. Minimal set of first deliverables

The first working version of the system should include:

1. a preprocessing script that generates a clean combined dataset
2. a species explorer tab
3. a records tab with filters and downloads
4. an occurrence map tab
5. an effort diagnostics tab
6. a criterion A tab reproducing the current script logic
7. a criterion B tab with at least AOO and EOO support
8. a decision tab with final category and note export

This first version will already be substantially more robust and transparent than the current script-based workflow.

---

## 12. Key design principle

The app should never hide methodological assumptions in code. Every important threshold, period definition, and inclusion rule should be visible either in the interface, the settings file, or the exported report.

That principle will make the Flanders fungal Red List workflow more reproducible, easier to review, and safer to update over time.



## Codex Handoff Addendum: Threshold Philosophy

### Critical design principle: thresholds must be user-settable

A central requirement of the system is that default thresholds are only starting values and must not be treated as universally correct across fungal taxa.

Because ecological traits, detectability, rarity structure, and survey bias differ strongly among taxonomic and ecological groups, the application must allow users to modify most analytical thresholds directly from the interface.

This applies especially to:

- Criterion A minimum occupancy thresholds
- DD cutoffs
- RE thresholds
- noTrend thresholds
- common species thresholds
- fragmentation thresholds
- minimum occupied-grid thresholds
- survey completeness thresholds for ecodistricts
- historical/current split year
- AOO spatial unit choice
- Criterion B decline thresholds
- optional expert override thresholds

The app must therefore function as a Red List decision-support system rather than a fixed-threshold calculator.

Legacy-compatible defaults should be preloaded so the first implementation reproduces the historical script as closely as possible, but users must be able to change them and rerun calculations transparently.

### Default DD rule (legacy-compatible)

- DD if occupied IFBL grids < 5 in both historical and current periods
- RE if historical occupied grids > 0 and current occupied grids = 0

Importantly, the DD cutoff value (default = 5) must itself be user-settable, exactly like the other thresholds.



# Codex Handoff Bundle

## 1. Original Flanders Workflow Summary

### Historical structure

The original workflow consists of three analytical streams:

1. Funbel-only workflow
2. waarnemingen.be (Natuurpunt) workflow
3. Combined Funbel + waarnemingen.be workflow

The combined workflow is the intended primary analytical backend and should be treated as the reference system for the new application.

### General workflow steps

1. Import raw occurrence data
2. Taxonomic harmonization and synonym correction
3. Remove unresolved taxa (for example sp., malformed names, unresolved s.s./s.l. conflicts)
4. Parse dates and derive observation year
5. Assign IFBL grid units (quarter-grid and IFBL units)
6. Restrict to Flemish quadrants only
7. Join ecodistrict and ecoregion information
8. Produce survey effort diagnostics
9. Calculate Criterion A
10. Calculate Criterion B
11. Merge criteria into final provisional Red List category
12. Add taxonomy metadata (genus, family, order)
13. Export tables and maps

---

## 2. Original Script Behaviour Notes

### Criterion A

Criterion A is based primarily on occupancy change between two periods.

Default periods:
- historical: 1800–2000
- current: 2001–2023

Species are counted as occupied per IFBL unit after deduplication within species × grid × period.

Trend is calculated using relative occupancy:

relative occupancy = occupied grids / total surveyed grids in that period

historical trend is derived from the proportional change between periods.

Legacy category thresholds:
- CR: decline <= -80%
- EN: decline <= -50%
- VU: decline <= -30%
- NT/LC: smaller decline depending on evidence

### DD and RE

Legacy-compatible default:
- DD if occupied IFBL grids < 5 in both historical and current periods
- RE if historical > 0 and current = 0

This threshold must be user-settable.

### noTrend species

Very widespread species are flagged as noTrend when occupancy is very high in both periods.

Legacy default:
75% of maximum occupancy in both periods.

This must also be user-settable.

### Criterion B

Original script uses:
- AOO
n- fragmentation heuristic
- current-period decline proxy

EOO is weakly represented and should not be the primary focus for Flanders.

### Fragmentation heuristic

Legacy heuristic:
- 10 km buffers around occupied sites
- disconnected polygons counted
- fragmentation inferred when >2 polygons and all polygons small

This should be retained initially but made transparent and adjustable.

### Current decline heuristic

Legacy approach:
- yearly occupied grid counts standardized by annual survey effort
- linear regression slope
- decline inferred when slope < 0 and R² threshold sufficiently high

This should be improved but legacy reproduction must remain possible.

---

## 3. Original Czech Shiny Workflow Summary

### Purpose

The Czech app serves as a useful interface model rather than a methodological template.

It provides:
- species selection
- map outputs
- AOO/EOO summaries
- record inspection
- criterion visualization
- downloadable outputs

### Useful interface patterns to retain

- species-centric navigation
- interactive maps
- criterion summaries on one screen
- expert review panels
- downloadable outputs
- raw record inspection

### Parts not to copy directly

- Czech-specific Red List logic
- country-specific thresholds
- taxonomic assumptions
- hidden assumptions inside helper functions

The new Flanders app should inherit interface structure, not analytical rules.

---

## 4. Keep / Replace / Add

### Keep

- combined Funbel + waarnemingen.be backend
- IFBL-based occupancy logic
- legacy Criterion A compatibility
- survey effort diagnostics
- species-level raw record inspection
- expert judgement layer

### Replace

- duplicated script sections
- hard-coded thresholds
- opaque Criterion B heuristics
- scattered exports
- manual taxonomic edits inside analysis code
- poor reproducibility

### Add

- standalone preprocessing pipeline
- modular Shiny architecture
- settable thresholds
- criterion note fields
- explicit exclusion logs
- expert decision sheet
- supplementary EOO
- stronger current decline diagnostics
- clearer fragmentation diagnostics
- reproducible exports

---

## 5. Non-Negotiables for Codex

Codex must NOT redesign Red List methodology.

Codex must:

- preserve legacy Criterion A reproducibility
- keep preprocessing separate from app logic
- use combined dataset as primary backend
- keep thresholds user-settable
- treat final category as expert-reviewed
- prioritize transparency over automation

Codex may improve:

- code quality
- modularity
- reproducibility
- UI structure
- maintainability
- documentation

Codex must not silently change thresholds, redefine criteria, or replace ecological judgement with automated assumptions.

---

## 6. Data Requirements and File Manifest

The following files are explicitly referenced in the original workflow and should be treated as the starting data manifest for the new system.

### 6.1 Raw biological data files

#### Funbel-related

- `Data_updated.xlsx`
  - purpose: primary Funbel occurrence source
  - sheet used in old workflow: `Data genera`
  - key fields inferred from script: `Genus`, `Soortnaam`, `Species`, `Datum`, `Uurhok`, `Kwartier`, `Nednaam`

- `condensAllVL.xlsx`
  - purpose: previously saved condensed Flemish subset used in the old workflow
  - note: likely replaceable by reproducible preprocessing and should not remain a required primary input in the new system unless needed for validation checks

#### waarnemingen.be / Natuurpunt-related

- `xlsx1.xlsx`
- `xlsx2.xlsx`
- `xlsx3.xlsx`
- `xlsx4.xlsx`
  - purpose: four waarnemingen.be export files combined into the old Natuurpunt workflow
  - key fields inferred from script include: `naam_lat`, `naam_nl`, `datum`, `status`, `lon`, `lat`

### 6.2 Taxonomy and metadata files

- `Natuurpunt_taxa.xlsx`
  - purpose: taxonomic harmonization for waarnemingen.be data
  - sheet used in old workflow: `herleide lijst`
  - key fields inferred: `naam_lat`, `updated_name`, possibly `naam_nl`

- `Lat_Ned.xlsx`
  - purpose: Latin-to-Dutch naming support and metadata enrichment for outputs

- `species_info_publication_GBIF.xlsx`
  - purpose: publication and GBIF-related species metadata enrichment

- `FungalTraits.xlsx`
  - purpose: fungal trait enrichment
  - key fields inferred: `GENUS`, `Family`, `Order`

### 6.3 Tabular spatial lookup files

- `tblIFBLkwartierhokEcodistrict.csv`
  - purpose: lookup linking Flemish IFBL quarter-grids to ecodistricts and ecoregions
  - key fields inferred: `IFBLuurhok`, `REGIO`, `DISTRICT`, `Xcoord`, `Ycoord`

- `tblIFBLkwartier.csv`
  - purpose: list of IFBL quarter-grids belonging to the Flemish Region
  - key fields inferred: `IFBL`

### 6.4 Spatial vector files and objects

- `ifbl01x01` shapefile
  - purpose: IFBL 1 × 1 km quarter-grid geometry
  - old workflow loads via `readOGR(..., "ifbl01x01")`

- `ifbl04x04.shp`
  - purpose: IFBL 2 × 2 km grid geometry used in the Natuurpunt mapping workflow

- `IFBL_kwartierhokken.kml`
  - purpose: KML for quarter-grid assignment from point coordinates

- `ecodistrict2002` shapefile
  - purpose: ecodistrict geometry
  - old workflow loads both via `readOGR(..., "ecodistrict2002")` and `st_read("/data/gent/469/vsc46998/ecodistrict2002.shp")`

- `ecoregio2002` shapefile
  - purpose: ecoregion geometry

- `Vlaanderen.Rdata`
  - purpose: Flanders boundary polygon used for plotting

- `Hoofdrivieren.Rdata`
  - purpose: major rivers layer used for plotting

### 6.5 Intermediate and legacy output files referenced in the old workflow

These should not necessarily remain required runtime inputs, but they are useful for checking backwards compatibility.

- `BT_wide.csv`
- `noTrendSpecs.csv`
- `RLCFlanders_CriterionA_SpeciesIndex.csv`
- `critA_SI.csv`
- `critA_SI.xlsx`
- `joined_data_Funbel_v8.xlsx`
- `Funbel_critB_withRL_without_EoO_v8.xlsx`
- `Funbel_Masterlist_without_EoO_v8.xlsx`
- `joined_data_v8.xlsx`
- `critB_withRL_without_EoO_v8.xlsx`
- `Masterlist_without_EoO_v8.xlsx`
- `Masterlist_Combined_v8.xlsx`

These are primarily legacy validation targets for the new implementation.

### 6.6 Recommended new preprocessed app inputs

The preprocessing script should write a minimal clean set of app-ready files, for example:

- `app_data/records_clean.rds`
- `app_data/records_analysis.rds`
- `app_data/species_master.rds`
- `app_data/excluded_records.csv`
- `app_data/taxon_audit.csv`
- `app_data/settings_defaults.csv`
- `app_data/criterion_a_legacy_validation.csv`
- `app_data/criterion_b_support_validation.csv`

### 6.7 Required-vs-optional classification

#### Mandatory for implementation

- `Data_updated.xlsx`
- `xlsx1.xlsx`
- `xlsx2.xlsx`
- `xlsx3.xlsx`
- `xlsx4.xlsx`
- `Natuurpunt_taxa.xlsx`
- `Lat_Ned.xlsx`
- `species_info_publication_GBIF.xlsx`
- `FungalTraits.xlsx`
- `tblIFBLkwartierhokEcodistrict.csv`
- `tblIFBLkwartier.csv`
- `ifbl01x01` shapefile
- `ifbl04x04.shp`
- `IFBL_kwartierhokken.kml`
- `ecodistrict2002` shapefile
- `ecoregio2002` shapefile
- `Vlaanderen.Rdata`

#### Optional but useful

- `Hoofdrivieren.Rdata`
- legacy output tables and figures for validation comparison
- any additional habitat, guild, or threat-support layers

---

## 7. Codex Implementation Brief

Build a modular Shiny application for fungal Red List assessment in Flanders using the combined Funbel + waarnemingen.be dataset as the primary backend.

The app must support:

- legacy-compatible Criterion A reproduction
- transparent Criterion B assessment focused on fragmentation and continuing decline
- optional supplementary EOO
- species-level record inspection
- expert note fields
- final expert-reviewed category assignment
- exportable decision sheets

The app must read only preprocessed inputs from a separate preprocessing script.

Do not place raw cleaning logic inside the app.

All important thresholds must be user-settable from the interface while preserving legacy defaults.

Use modular Shiny structure with separate modules for:

- settings
- species explorer
- Criterion A
- Criterion B
- maps
- expert decision sheet
- exports

Document assumptions clearly in code comments and README files.


# docs/flanders_redlist_app_specification.md

## Purpose

This application is a modular Shiny decision-support system for fungal Red List assessment in Flanders.

It is designed to support expert-driven Red List evaluations using the combined Funbel + waarnemingen.be dataset as the primary analytical backend.

The application is not intended to function as a rigid automatic classifier. Instead, it must provide transparent analytical support, reproducible calculations, adjustable thresholds, and clear expert review tools.

Final Red List assignment remains an expert-reviewed decision.

---

## Core principles

1. Reproducibility of legacy Criterion A results
2. Transparent and improved Criterion B assessment
3. User-settable thresholds and settings
4. Separation of preprocessing and app runtime
5. Species-level raw record inspection
6. Explicit exclusion logging
7. Expert note fields and decision sheets
8. Exportable outputs for documentation and publication

---

## Main modules

### Settings

Global thresholds and analytical parameters.

Examples:
- historical/current split year
- DD threshold
- noTrend threshold
- fragmentation threshold
- AOO unit
- ecodistrict completeness threshold

### Species Explorer

Species selection and taxonomic overview.

### Raw Records

Searchable table of all records for the selected species.

### Survey Effort

Diagnostics for survey completeness and grid coverage.

### Criterion A

Legacy-compatible occupancy trend workflow with adjustable settings.

### Criterion B

AOO + fragmentation + current-period decline, with optional supplementary EOO.

### Maps

Interactive distribution and fragmentation maps.

### Expert Decision Sheet

Final category assignment with notes and rationale.

### Exports

Downloadable tables, maps, and final assessment sheets.

---

## Output philosophy

The app must generate:
- provisional criterion outputs
- uncertainty flags
- expert review notes
- reproducible export files

It must not silently make irreversible final decisions.


# docs/ORIGINAL_FLANDERS_WORKFLOW.md

## Historical workflow overview

The original Flanders Red List workflow consists of three analytical branches:

1. Funbel only
2. waarnemingen.be / Natuurpunt only
3. Combined Funbel + waarnemingen.be

The combined workflow is the primary reference for the new implementation.

---

## Shared workflow steps

### Step 1 — Import occurrence data

Raw occurrence tables are loaded from Excel files.

### Step 2 — Taxonomic harmonization

Species names are corrected manually and through lookup tables.

### Step 3 — Remove unresolved taxa

Examples removed:
- sp.
- malformed names
- problematic s.s. / s.l. duplicates

### Step 4 — Parse observation dates

Dates are converted to observation year.

### Step 5 — Assign IFBL units

Quarter-grid and IFBL occupancy units are assigned.

### Step 6 — Restrict to Flanders

Only Flemish IFBL units are retained.

### Step 7 — Join ecodistrict and ecoregion data

Spatial ecological context is added.

### Step 8 — Survey effort diagnostics

Maps and summaries of survey completeness are generated.

### Step 9 — Criterion A

Historical occupancy trend assessment.

### Step 10 — Criterion B

AOO + fragmentation + continuing decline.

### Step 11 — Final category merge

Criterion A and B are combined into provisional final categories.

### Step 12 — Metadata enrichment

Family, Order, Dutch names, and publication information are added.

### Step 13 — Export

Excel outputs and static figures are written.


# docs/ORIGINAL_SCRIPT_BEHAVIOUR.md

## Criterion A behaviour

### Default periods

Historical:
- 1800–2000

Current:
- 2001–2023

These must remain the default legacy-compatible settings.

---

## Occupancy calculation

Species occupancy is calculated as occupied IFBL units after deduplication within:

species × IFBL × period

Relative occupancy is then standardized by total surveyed grids in that period.

---

## Legacy thresholds

### Decline categories

- CR: decline <= -80%
- EN: decline <= -50%
- VU: decline <= -30%

### DD

Default:
occupied IFBL grids < 5 in both periods

### RE

Historical > 0 and current = 0

### noTrend

Very common species flagged when occupancy is high in both periods.

Legacy default:
75% of maximum occupancy in both periods.

All thresholds must become user-settable.

---

## Criterion B behaviour

### AOO

Calculated from IFBL occupancy units.

### Fragmentation

Legacy heuristic:

- 10 km buffers
- disconnected polygons
- fragmentation inferred when >2 polygons and all polygons are small

### Continuing decline

Legacy heuristic:

- yearly occupied grids standardized by annual survey effort
- linear regression slope
- decline inferred when slope < 0 and model fit sufficiently strong

EOO is weakly represented and should remain supplementary.


# docs/ORIGINAL_CZECH_SHINY_WORKFLOW.md

## Purpose of reference app

The Czech Shiny app is used as an interface reference, not as a methodological template.

It demonstrates a strong species-based Red List workflow with useful interface patterns.

---

## Useful design patterns to inherit

### Species-first navigation

Users begin with a selected species and inspect all criteria from there.

### Interactive maps

Distribution maps and occupancy summaries are central.

### Raw record inspection

Users can inspect underlying records.

### Criterion panels

Criterion summaries are visible in a single workflow.

### Export functions

Reports and summaries can be downloaded.

### Expert review layer

The system supports expert interpretation rather than replacing it.

---

## Things not to inherit

- Czech-specific thresholds
- Czech-specific legal categories
- hidden helper-function assumptions
- country-specific taxonomic assumptions

The interface should be inherited, not the analytical rules.


# docs/KEEP_REPLACE_ADD.md

## KEEP

### Analytical structure

- combined Funbel + waarnemingen.be backend
- IFBL-based occupancy logic
- legacy-compatible Criterion A
- survey effort diagnostics
- species-level record inspection
- expert judgement layer

### Practical structure

- direct export of final tables
- spatial visualization of occupancy

---

## REPLACE

### Technical problems

- duplicated script blocks
- hard-coded thresholds
- scattered output writing
- manual edits inside analytical code
- poor reproducibility

### Methodological problems

- opaque Criterion B heuristics
- unclear exclusion logic
- weak documentation of assumptions

---

## ADD

### New infrastructure

- standalone preprocessing script
- modular Shiny architecture
- app-ready clean backend tables

### Better decision support

- user-settable thresholds
- explicit exclusion logs
- criterion note fields
- expert decision sheet
- raw species record viewer
- reproducible exports

### Improved ecology

- stronger current decline diagnostics
- clearer fragmentation diagnostics
- optional supplementary EOO
- easier future expansion to guild-based interpretation

