# Spatial helpers are intentionally lightweight in v1 shell.
# More complex mapping/EOO helpers can be added in Criterion B and map modules.

safe_read_if_exists <- function(path, reader) {
  if (!file.exists(path)) return(NULL)
  reader(path)
}
