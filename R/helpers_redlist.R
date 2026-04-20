compute_period_occupancy <- function(records_analysis, species, split_year = 2000L) {
  x <- records_analysis[records_analysis$Species == species, , drop = FALSE]
  if (nrow(x) == 0) {
    return(data.frame(period = c("historical", "current"), occupied = 0L, surveyed = NA_integer_))
  }

  x$period <- ifelse(x$Year <= split_year, "historical", "current")
  occupied <- aggregate(ifbluurhok ~ period, unique(x[c("period", "ifbluurhok")]), length)
  names(occupied)[2] <- "occupied"

  out <- merge(data.frame(period = c("historical", "current")), occupied, by = "period", all.x = TRUE)
  out$occupied[is.na(out$occupied)] <- 0L
  out$surveyed <- NA_integer_
  out
}

compute_criterion_a <- function(records_analysis, species, settings) {
  occ <- compute_period_occupancy(records_analysis, species, split_year = settings$split_year)
  hist <- occ$occupied[occ$period == "historical"]
  curr <- occ$occupied[occ$period == "current"]

  decline_pct <- if (hist > 0) (curr - hist) / hist * 100 else NA_real_
  max_occ <- max(occ$occupied, na.rm = TRUE)

  category <- "LC"
  reason <- "No major decline threshold crossed."

  if (hist > 0 && curr == 0) {
    category <- "RE"
    reason <- "Occupied historically and absent in current period."
  } else if (hist < settings$dd_grid_threshold && curr < settings$dd_grid_threshold) {
    category <- "DD"
    reason <- "Occupied IFBL grids below DD threshold in both periods."
  } else if (!is.na(decline_pct) && decline_pct <= settings$cr_decline) {
    category <- "CR"
    reason <- "Decline below CR threshold."
  } else if (!is.na(decline_pct) && decline_pct <= settings$en_decline) {
    category <- "EN"
    reason <- "Decline below EN threshold."
  } else if (!is.na(decline_pct) && decline_pct <= settings$vu_decline) {
    category <- "VU"
    reason <- "Decline below VU threshold."
  } else if (max_occ > 0 && hist >= settings$common_fraction * max_occ && curr >= settings$common_fraction * max_occ) {
    category <- "noTrend"
    reason <- "Common in both periods based on legacy noTrend rule."
  }

  list(occupancy = occ, decline_pct = decline_pct, category = category, reason = reason)
}
