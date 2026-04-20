#!/usr/bin/env Rscript

required_pkgs <- c("httr", "jsonlite", "dplyr", "purrr", "readr", "stringr", "stringdist", "tibble")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  message("Installing missing R packages: ", paste(missing_pkgs, collapse = ", "))
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(stringdist)
  library(tibble)
})

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------
species_list <- c(
  "Amanita muscaria",
  "Amanita rubescens",
  "Amanita citrina",
  "Amanita citrina var. alba",
  "Boletus edulis",
  "Mycetinis alliaceus",
  "Pluteus cervinus",
  "Mycetinus scorodonius",
  "Pluteus ephebeus",
  "Pluteus nanus",
  "Psathyrella conopilus",
  "Psathyrella piluliformis"
)

output_dir <- "data_raw/gbif"
records_limit_per_taxon <- 1000L
offset_step <- 300L
state_province_fallback <- c("Vlaanderen", "Flanders", "Flemish Region")

# -----------------------------------------------------------------------------
# GBIF helpers
# -----------------------------------------------------------------------------
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

api_get <- function(url, query = list(), retries = 3L) {
  for (i in seq_len(retries)) {
    resp <- GET(url, query = query)
    if (!http_error(resp)) {
      return(fromJSON(content(resp, "text", encoding = "UTF-8"), flatten = TRUE))
    }
    Sys.sleep(i)
  }
  stop("GBIF API request failed after retries: ", url)
}

match_taxon <- function(name) {
  exact <- api_get("https://api.gbif.org/v1/species/match", query = list(name = name))

  exact_ok <- !is.null(exact$usageKey) && !is.null(exact$kingdom) && exact$kingdom == "Fungi"
  confidence <- as.numeric(exact$confidence %||% 0)

  if (exact_ok && confidence >= 90) {
    return(tibble(
      input_name = name,
      match_method = "exact",
      matched_name = exact$scientificName %||% name,
      usageKey = as.integer(exact$usageKey),
      speciesKey = as.integer(exact$speciesKey %||% NA),
      confidence = confidence,
      status = exact$status %||% NA_character_,
      note = NA_character_
    ))
  }

  # fuzzy fallback via species/suggest + string distance
  sug <- api_get("https://api.gbif.org/v1/species/suggest", query = list(q = name, limit = 50))
  if (length(sug) == 0 || nrow(sug) == 0) {
    return(tibble(
      input_name = name,
      match_method = "none",
      matched_name = NA_character_,
      usageKey = NA_integer_,
      speciesKey = NA_integer_,
      confidence = NA_real_,
      status = NA_character_,
      note = "No match from species/match or species/suggest"
    ))
  }

  sug_tbl <- as_tibble(sug) %>%
    mutate(
      kingdom = coalesce(.data$kingdom, NA_character_),
      scientificName = coalesce(.data$scientificName, .data$canonicalName, NA_character_),
      distance = stringdist::stringdist(str_to_lower(name), str_to_lower(scientificName), method = "jw"),
      score = (1 - distance) * 100
    ) %>%
    filter(kingdom == "Fungi") %>%
    arrange(desc(score))

  if (nrow(sug_tbl) == 0) {
    return(tibble(
      input_name = name,
      match_method = "none",
      matched_name = NA_character_,
      usageKey = NA_integer_,
      speciesKey = NA_integer_,
      confidence = NA_real_,
      status = NA_character_,
      note = "Suggest results exist but none in kingdom Fungi"
    ))
  }

  best <- sug_tbl[1, ]
  tibble(
    input_name = name,
    match_method = "fuzzy_suggest_jw",
    matched_name = best$scientificName %||% name,
    usageKey = as.integer(best$key %||% NA),
    speciesKey = as.integer(best$speciesKey %||% best$key %||% NA),
    confidence = as.numeric(best$score %||% NA),
    status = best$status %||% NA_character_,
    note = ifelse((best$score %||% 0) < 85, "Low fuzzy score (<85)", NA_character_)
  )
}

fetch_occurrences <- function(usage_key, limit_total = 1000L, step = 300L) {
  if (is.na(usage_key)) return(tibble())

  out <- list()
  start <- 0L
  total <- 0L

  repeat {
    res <- api_get(
      "https://api.gbif.org/v1/occurrence/search",
      query = list(
        taxonKey = usage_key,
        country = "BE",
        kingdomKey = 5,
        hasCoordinate = TRUE,
        limit = step,
        offset = start
      )
    )

    batch <- as_tibble(res$results %||% list())
    if (nrow(batch) == 0) break

    out[[length(out) + 1L]] <- batch
    total <- total + nrow(batch)
    start <- start + step

    if (total >= limit_total || total >= (res$count %||% total)) break
  }

  bind_rows(out)
}

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

taxon_match_log <- map_dfr(species_list, match_taxon)

occurrence_raw <- pmap_dfr(
  list(taxon_match_log$input_name, taxon_match_log$usageKey, taxon_match_log$matched_name),
  function(input_name, usage_key, matched_name) {
    dat <- fetch_occurrences(usage_key, limit_total = records_limit_per_taxon, step = offset_step)
    if (nrow(dat) == 0) return(tibble())
    dat %>% mutate(input_name = input_name, matched_name = matched_name, usageKey = usage_key)
  }
)

# fallback post-filter for Flanders from available administrative fields
occurrence_filtered <- occurrence_raw %>%
  mutate(
    stateProvince = coalesce(stateProvince, ""),
    municipality = coalesce(municipality, ""),
    is_flanders = stateProvince %in% state_province_fallback |
      str_detect(str_to_lower(municipality), "antwerp|oost-vlaanderen|west-vlaanderen|limburg|vlaams-brabant")
  )

exclusion_log <- occurrence_filtered %>%
  mutate(exclusion_reason = ifelse(!is_flanders, "outside_flanders_fallback_filter", NA_character_)) %>%
  filter(!is.na(exclusion_reason)) %>%
  select(input_name, matched_name, key, scientificName, stateProvince, municipality, exclusion_reason)

occurrence_kept <- occurrence_filtered %>%
  filter(is_flanders) %>%
  select(
    gbifID = key,
    occurrenceID,
    input_name,
    matched_name,
    scientificName,
    acceptedScientificName,
    usageKey,
    taxonKey,
    speciesKey,
    decimalLatitude,
    decimalLongitude,
    coordinateUncertaintyInMeters,
    eventDate,
    year,
    countryCode,
    stateProvince,
    municipality,
    locality,
    basisOfRecord,
    occurrenceStatus,
    issues,
    datasetName,
    institutionCode,
    collectionCode,
    recordedBy,
    identifiedBy
  )

write_csv(taxon_match_log, file.path(output_dir, "taxon_match_log.csv"))
write_csv(occurrence_raw, file.path(output_dir, "occurrences_raw.csv"))
write_csv(occurrence_kept, file.path(output_dir, "occurrences_flanders_filtered.csv"))
write_csv(exclusion_log, file.path(output_dir, "exclusion_log.csv"))

metadata <- list(
  generated_at_utc = as.character(Sys.time()),
  source = "GBIF API",
  species_count = length(species_list),
  matched_taxa = nrow(filter(taxon_match_log, !is.na(usageKey))),
  records_raw = nrow(occurrence_raw),
  records_kept_flanders = nrow(occurrence_kept),
  filters = list(country = "BE", kingdomKey = 5, hasCoordinate = TRUE, flanders_post_filter = state_province_fallback)
)
write_json(metadata, file.path(output_dir, "download_metadata.json"), pretty = TRUE, auto_unbox = TRUE)

message("GBIF download complete.")
message("Matched taxa: ", nrow(filter(taxon_match_log, !is.na(usageKey))), "/", length(species_list))
message("Records raw: ", nrow(occurrence_raw))
message("Records kept after Flanders fallback filter: ", nrow(occurrence_kept))
