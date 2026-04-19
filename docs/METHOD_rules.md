# Method Rules

## Core backend rule

The primary analytical backend is the combined Funbel + waarnemingen.be dataset.

Funbel-only and waarnemingen.be-only analyses may be retained for validation or inspection, but the main application logic must use the combined backend.

## Separation of preprocessing and app runtime

Raw data cleaning, taxonomic harmonization, spatial assignment, and exclusion logging must happen in a separate preprocessing script.

The Shiny app must read only cleaned, preprocessed inputs.

## Criterion A

The first implementation must reproduce the legacy Criterion A workflow as closely as possible.

Legacy-compatible default settings:
- historical period: 1800–2000
- current period: 2001 onward
- split year default: 2000

Criterion A must remain user-configurable:
- split year
- DD cutoff
- noTrend threshold
- minimum occupancy threshold
- other classification settings

## Criterion B

Criterion B must be rebuilt more transparently than in the old script.

Main emphasis for Flanders:
- continuing decline during the current period
- fragmentation
- occupancy structure

EOO may be calculated as a supplementary output, but it is not the main Criterion B emphasis for Flemish fungi.

## Validation rule

Version 1 calculations use validated records only.

Non-validated records may still be retained in the backend as excluded or flagged records for later review.

## AOO rule

Default analytical occupancy unit:
- IFBL 2 × 2 km

Optional user setting:
- 1 × 1 km kwartierhok

## DD and RE defaults

Legacy-compatible default:
- DD if occupied IFBL grids < 5 in both historical and current periods
- RE if historical occupied grids > 0 and current occupied grids = 0

The DD threshold must be user-settable.

## Expert review

The app must not make final Red List decisions automatically.

Required expert-review functionality:
- provisional criterion outputs
- fillable note field per criterion/category
- final expert-reviewed category assignment
- species-level raw record inspection
- exportable decision sheet
