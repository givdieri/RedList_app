load_app_data <- function(app_data_dir = "app_data") {
  req_paths <- c(
    records_clean = file.path(app_data_dir, "records_clean.rds"),
    records_analysis = file.path(app_data_dir, "records_analysis.rds"),
    species_master = file.path(app_data_dir, "species_master.rds"),
    settings_defaults = file.path(app_data_dir, "settings_defaults.csv")
  )

  missing <- req_paths[!file.exists(req_paths)]
  if (length(missing) > 0) {
    stop(
      "Missing app_data files: ",
      paste(names(missing), collapse = ", "),
      ". Run scripts/01_preprocess_flanders_redlist_data.R first."
    )
  }

  list(
    records_clean = readRDS(req_paths[["records_clean"]]),
    records_analysis = readRDS(req_paths[["records_analysis"]]),
    species_master = readRDS(req_paths[["species_master"]]),
    settings_defaults = read.csv(req_paths[["settings_defaults"]], stringsAsFactors = FALSE)
  )
}

settings_to_list <- function(settings_df) {
  vals <- stats::setNames(as.list(settings_df$setting_value), settings_df$setting_key)
  list(
    split_year = as.integer(vals$split_year %||% 2000),
    dd_grid_threshold = as.integer(vals$dd_grid_threshold %||% 5),
    cr_decline = as.numeric(vals$criterion_a_cr_decline %||% -80),
    en_decline = as.numeric(vals$criterion_a_en_decline %||% -50),
    vu_decline = as.numeric(vals$criterion_a_vu_decline %||% -30),
    common_fraction = as.numeric(vals$criterion_a_no_trend_common_fraction %||% 0.75)
  )
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x
