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

- Primary backend: `data_raw/funbel/Data_updated.txt` (v1 reduced schema) + Flemish IFBL lookup (`spatial/tblIFBLkwartier.csv`).
- Preprocessing is separate from the app.
- App loads only cleaned `app_data/*` outputs.
- `validatie` is preserved exactly as-is and not hard-filtered in v1.
- Species working taxon is the existing `Species` field (with `species_working` mirror).
- Default Criterion A assumptions are configurable through settings inputs.

## Run preprocessing

If `R` / `Rscript` are not available, bootstrap the runtime first:

```bash
bash scripts/00_setup_r_runtime.sh
```

```r
Rscript scripts/01_preprocess_flanders_redlist_data.R
```

The preprocessing script also auto-installs missing R packages from CRAN when possible, and returns a clear error with Ubuntu `r-cran-*` fallback guidance if CRAN is blocked.

## Optional GBIF fetch workflow (new)

To build raw occurrence inputs from GBIF API (test taxa, Belgium + Flanders fallback filter):

```r
Rscript scripts/00_fetch_gbif_occurrences.R
```

Outputs are written to `data_raw/gbif/`:

- `taxon_match_log.csv`
- `occurrences_raw.csv`
- `occurrences_flanders_filtered.csv`
- `exclusion_log.csv`
- `download_metadata.json`

Expected outputs in `app_data/`:

- `records_clean.rds`
- `records_analysis.rds`
- `species_master.rds`
- `lookup_flanders_ifbl.rds`
- `lookup_ecodistrict.rds`
- `excluded_records.csv`
- `taxon_audit.csv`
- `settings_defaults.csv`

Note: these outputs are generated locally and intentionally not committed (to avoid binary-file PR issues and keep the repository lightweight).

## Run app

```r
Rscript -e "shiny::runApp('.')"
```

## Notes on source/document naming in this repo

Some requested reference filenames in the task prompt differ from currently present files. This implementation uses the closest available repository equivalents:

- `docs/FULL_flanders_redlist_app_specification.md`
- `docs/WORKLOW_PROVENANCE.md`
- `legacy_code/original_redlist_script.R`

These were treated as authoritative local references for v1 scaffolding.
