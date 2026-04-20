#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(stringr)
  library(tidyr)
  library(readr)
})

# -----------------------------
# Config
# -----------------------------
raw_data_path <- "data_raw/funbel/Data_updated.xlsx"
raw_sheet <- "Data genera"
lookup_path <- "spatial/tblIFBLkwartier.csv"
output_dir <- "app_data"

year_min_default <- 1800L
year_max_default <- as.integer(format(Sys.Date(), "%Y"))

required_record_columns <- c(
  "Source.Name", "Code", "Genus", "Soortnaam", "Species", "Nednaam",
  "validatie", "Plaats", "Terrein", "Kwartier", "Datum", "Waarnemer",
  "Determinator", "Herbarium", "Substraat", "Wetnaam", "kommentaar",
  "Eco1", "Eco1Groep", "ifbluurhok", "Year", "Old_name"
)

required_lookup_any <- c("IFBL", "IFBLuur", "ifbluurhok")

# -----------------------------
# Helpers
# -----------------------------
normalize_ifbl <- function(x) {
  x |>
    as.character() |>
    str_trim() |>
    str_replace_all("\\.", "-") |>
    str_to_lower()
}

extract_year <- function(date_raw, year_raw) {
  year_num <- suppressWarnings(as.integer(year_raw))
  date_char <- as.character(date_raw)
  parsed <- suppressWarnings(as.Date(date_char))
  parsed_year <- suppressWarnings(as.integer(format(parsed, "%Y")))
  year_from_string <- suppressWarnings(as.integer(str_extract(date_char, "\\b(17|18|19|20)\\d{2}\\b")))
  dplyr::coalesce(year_num, parsed_year, year_from_string)
}

is_unresolved_taxon <- function(species) {
  sp <- species |> as.character() |> str_squish()
  sp == "" |
    is.na(sp) |
    str_detect(sp, regex("(^|\\s)sp\\.?($|\\s)", ignore_case = TRUE)) |
    str_detect(sp, regex("(^|\\s)spp\\.?($|\\s)", ignore_case = TRUE))
}

first_present <- function(df, candidates) {
  present <- intersect(candidates, names(df))
  if (length(present) == 0) return(NULL)
  present[[1]]
}

# -----------------------------
# Read source files
# -----------------------------
if (!file.exists(raw_data_path)) {
  stop("Raw data file not found: ", raw_data_path)
}
if (!file.exists(lookup_path)) {
  stop("Flemish IFBL lookup not found: ", lookup_path)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

records_raw <- readxl::read_excel(raw_data_path, sheet = raw_sheet) |> as_tibble()
lookup_raw <- readr::read_delim(
  lookup_path,
  delim = ";",
  locale = locale(encoding = "UTF-8"),
  show_col_types = FALSE,
  trim_ws = TRUE
) |> as_tibble()

# -----------------------------
# Validate required columns
# -----------------------------
missing_cols <- setdiff(required_record_columns, names(records_raw))
if (length(missing_cols) > 0) {
  stop("Missing required columns in raw records: ", paste(missing_cols, collapse = ", "))
}

lookup_ifbl_col <- first_present(lookup_raw, required_lookup_any)
if (is.null(lookup_ifbl_col)) {
  stop("Lookup is missing IFBL field. Expected one of: ", paste(required_lookup_any, collapse = ", "))
}

# -----------------------------
# Prepare lookup
# -----------------------------
lookup_flanders <- lookup_raw |>
  mutate(ifbluurhok = normalize_ifbl(.data[[lookup_ifbl_col]])) |>
  filter(!is.na(ifbluurhok), ifbluurhok != "") |>
  distinct(ifbluurhok, .keep_all = TRUE)

# -----------------------------
# Clean records
# -----------------------------
records_clean <- records_raw |>
  mutate(
    record_id = row_number(),
    species_working = as.character(Species),
    ifbluurhok = normalize_ifbl(ifbluurhok),
    year = extract_year(Datum, Year),
    source_dataset = as.character(`Source.Name`),
    species_original = as.character(Species),
    species_accepted = as.character(species_working),
    genus = as.character(Genus),
    dutch_name = as.character(Nednaam),
    date_original = as.character(Datum),
    validation_status = as.character(validatie),
    place = as.character(Plaats),
    terrain = as.character(Terrein),
    substrate = as.character(Substraat),
    ecology_group = as.character(Eco1Groep),
    observer = as.character(Waarnemer),
    determiner = as.character(Determinator)
  )

excluded <- records_clean |>
  transmute(
    record_id,
    species = species_working,
    ifbluurhok,
    year,
    exclusion_reason = case_when(
      is_unresolved_taxon(species_working) ~ "unresolved_taxon",
      is.na(year) ~ "year_missing_or_unparseable",
      year < year_min_default | year > year_max_default ~ "year_out_of_range",
      is.na(ifbluurhok) | ifbluurhok == "" ~ "ifbl_missing",
      TRUE ~ NA_character_
    )
  ) |>
  filter(!is.na(exclusion_reason))

# keep core cleaned records (raw-validity preserved, no filtering by validatie)
records_clean <- records_clean |>
  mutate(
    exclusion_reason = case_when(
      record_id %in% excluded$record_id ~ excluded$exclusion_reason[match(record_id, excluded$record_id)],
      TRUE ~ NA_character_
    ),
    include_in_analysis = is.na(exclusion_reason)
  )

# -----------------------------
# Recreate Flemish joined analysis table (legacy condensAllVL behaviour)
# -----------------------------
records_analysis_base <- records_clean |>
  filter(include_in_analysis) |>
  inner_join(lookup_flanders, by = "ifbluurhok")

pick_or_na_chr <- function(df, col) if (col %in% names(df)) as.character(df[[col]]) else rep(NA_character_, nrow(df))
pick_or_na_num <- function(df, col) if (col %in% names(df)) suppressWarnings(as.numeric(df[[col]])) else rep(NA_real_, nrow(df))

records_analysis <- records_analysis_base |>
  transmute(
    record_id,
    Species = species_accepted,
    species_working = species_accepted,
    ifbluurhok,
    Year = as.integer(year),
    IFBLuur = dplyr::coalesce(pick_or_na_chr(records_analysis_base, "IFBLuur"), pick_or_na_chr(records_analysis_base, "IFBL"), ifbluurhok),
    Xcoord = pick_or_na_num(records_analysis_base, "Xcoord"),
    Ycoord = pick_or_na_num(records_analysis_base, "Ycoord"),
    validatie,
    Source.Name,
    Code,
    Genus,
    Soortnaam,
    Nednaam,
    Aard_determinatie = pick_or_na_chr(records_analysis_base, "Aard_determinatie"),
    Plaats,
    Terrein,
    Kwartier,
    buitenlandse_plaats = pick_or_na_chr(records_analysis_base, "buitenlandse_plaats"),
    Datum,
    Waarnemer,
    Determinator,
    Herbarium,
    exsicc = pick_or_na_chr(records_analysis_base, "exsicc"),
    Substraat,
    Wetnaam,
    kommentaar,
    Eco1,
    Eco1Groep,
    Old_name,
    species_original,
    source_dataset
  )

species_master <- records_clean |>
  filter(!is.na(species_accepted), species_accepted != "") |>
  group_by(species_accepted) |>
  summarise(
    genus = dplyr::first(na.omit(genus)),
    dutch_name = dplyr::first(na.omit(dutch_name)),
    old_name_example = dplyr::first(na.omit(Old_name)),
    n_records_total = n(),
    n_records_included = sum(include_in_analysis),
    .groups = "drop"
  ) |>
  arrange(species_accepted)

taxon_audit <- records_clean |>
  count(species_original, species_accepted, sort = TRUE, name = "n_records")

settings_defaults <- tibble::tribble(
  ~setting_key, ~setting_value, ~description,
  "split_year", "2000", "Historical <= split year; current > split year.",
  "dd_grid_threshold", "5", "DD default when occupied IFBL grids < threshold in both periods.",
  "criterion_a_cr_decline", "-80", "Criterion A CR decline threshold (%).",
  "criterion_a_en_decline", "-50", "Criterion A EN decline threshold (%).",
  "criterion_a_vu_decline", "-30", "Criterion A VU decline threshold (%).",
  "criterion_a_no_trend_common_fraction", "0.75", "Legacy noTrend commonness fraction.",
  "year_min", as.character(year_min_default), "Minimum accepted year in preprocessing.",
  "year_max", as.character(year_max_default), "Maximum accepted year in preprocessing."
)

# -----------------------------
# Write outputs
# -----------------------------
saveRDS(records_clean, file.path(output_dir, "records_clean.rds"))
saveRDS(records_analysis, file.path(output_dir, "records_analysis.rds"))
saveRDS(species_master, file.path(output_dir, "species_master.rds"))
readr::write_csv(excluded, file.path(output_dir, "excluded_records.csv"))
readr::write_csv(taxon_audit, file.path(output_dir, "taxon_audit.csv"))
readr::write_csv(settings_defaults, file.path(output_dir, "settings_defaults.csv"))

message("Preprocessing completed.")
message("records_clean: ", nrow(records_clean))
message("records_analysis: ", nrow(records_analysis))
message("species_master: ", nrow(species_master))
message("excluded_records: ", nrow(excluded))
