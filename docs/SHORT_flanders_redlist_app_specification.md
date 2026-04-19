Purpose

This application is a modular Shiny decision-support system for fungal Red List assessment in Flanders.

It is designed to support expert-driven Red List evaluations using the combined Funbel + waarnemingen.be dataset as the primary analytical backend.

The application is not intended to function as a rigid automatic classifier. Instead, it must provide transparent analytical support, reproducible calculations, adjustable thresholds, and clear expert review tools.

Final Red List assignment remains an expert-reviewed decision.

Core principles
Reproducibility of legacy Criterion A results
Transparent and improved Criterion B assessment
User-settable thresholds and settings
Separation of preprocessing and app runtime
Species-level raw record inspection
Explicit exclusion logging
Expert note fields and decision sheets
Exportable outputs for documentation and publication
Main modules
Settings

Global thresholds and analytical parameters.

Examples:

historical/current split year
DD threshold
noTrend threshold
fragmentation threshold
AOO unit
ecodistrict completeness threshold
Species Explorer

Species selection and taxonomic overview.

Raw Records

Searchable table of all records for the selected species.

Survey Effort

Diagnostics for survey completeness and grid coverage.

Criterion A

Legacy-compatible occupancy trend workflow with adjustable settings.

Criterion B

AOO + fragmentation + current-period decline, with optional supplementary EOO.

Maps

Interactive distribution and fragmentation maps.

Expert Decision Sheet

Final category assignment with notes and rationale.

Exports

Downloadable tables, maps, and final assessment sheets.

Output philosophy

The app must generate:

provisional criterion outputs
uncertainty flags
expert review notes
reproducible export files

It must not silently make irreversible final decisions.
