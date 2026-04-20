# RedList_app

Modular Shiny decision-support app for fungal Red List assessment in Flanders.

## Current implementation status (v1 scaffold)

This commit implements the first build stages:

1. project structure normalization
2. standalone preprocessing script
3. app data loaders/helpers
4. minimal modular Shiny shell
5. species explorer and raw records table
6. survey effort diagnostic plot
7. legacy-compatible Criterion A scaffold
8. Criterion B/Maps/Decision scaffolds for extension

## Main principles implemented

- Primary backend: `data_raw/funbel/Data_updated.xlsx` + Flemish IFBL lookup (`spatial/tblIFBLkwartier.csv`).
- Preprocessing is separate from the app.
- App loads only cleaned `app_data/*` outputs.
- `validatie` is preserved exactly as-is and not hard-filtered in v1.
- Species working taxon is the existing `Species` field (with `species_working` mirror).
- Default Criterion A assumptions are configurable through settings inputs.

## Run preprocessing

```r
Rscript scripts/01_preprocess_flanders_redlist_data.R
```

Expected outputs in `app_data/`:

- `records_clean.rds`
- `records_analysis.rds`
- `species_master.rds`
- `excluded_records.csv`
- `taxon_audit.csv`
- `settings_defaults.csv`

## Run app

```r
Rscript -e "shiny::runApp('.')"
```

## Notes on source/document naming in this repo

Some requested reference filenames in the task prompt differ from currently present files. This implementation used the closest available repository equivalents:

- `docs/FULL_flanders_redlist_app_specification.md`
- `docs/WORKLOW_PROVENANCE.md`
- `legacy_code/original_redlist_script.R`

These were treated as authoritative local references for v1 scaffolding.
