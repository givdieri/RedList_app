Primary backend = combined Funbel + waarnemingen.be dataset.

Preprocessing is separate and run once by the project owner.
App users work only from cleaned app inputs.

Criterion A:
- First implementation must reproduce the old workflow as closely as possible.
- Legacy-compatible defaults must be preserved.
- All important thresholds/settings must be user-settable.

Criterion B:
- Rebuild transparently.
- Main emphasis for Flanders = current-period continuing decline + fragmentation.
- EOO is supplementary, not the main emphasis.

Validation:
- Use validated records only in v1 calculations.

AOO unit:
- Default = IFBL 2x2 km.
- Optional setting = 1x1 km kwartierhok.

Period split:
- Default split year = 2000.
- Must be user-settable.

DD and RE:
- Default legacy-compatible DD = occupied IFBL grids < 5 in both historical and current periods.
- Default RE = historical occupied grids > 0 and current occupied grids = 0.
- DD cutoff must be user-settable.

Expert review:
- Final category is expert-reviewed, not automated.
- Provide fillable note fields per criterion/category.
- Users must be able to inspect the raw record table for a selected species.
