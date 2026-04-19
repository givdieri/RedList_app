Criterion A behaviour
Default periods

Historical:

1800–2000

Current:

2001–2023

These must remain the default legacy-compatible settings.

Occupancy calculation

Species occupancy is calculated as occupied IFBL units after deduplication within:

species × IFBL × period

Relative occupancy is then standardized by total surveyed grids in that period.

Legacy thresholds
Decline categories
CR: decline <= -80%
EN: decline <= -50%
VU: decline <= -30%
DD

Default: occupied IFBL grids < 5 in both periods

RE

Historical > 0 and current = 0

noTrend

Very common species flagged when occupancy is high in both periods.

Legacy default: 75% of maximum occupancy in both periods.

All thresholds must become user-settable.

Criterion B behaviour
AOO

Calculated from IFBL occupancy units.

Fragmentation

Legacy heuristic:

10 km buffers
disconnected polygons
fragmentation inferred when >2 polygons and all polygons are small
Continuing decline

Legacy heuristic:

yearly occupied grids standardized by annual survey effort
linear regression slope
decline inferred when slope < 0 and model fit sufficiently strong

EOO is weakly represented and should remain supplementary.

