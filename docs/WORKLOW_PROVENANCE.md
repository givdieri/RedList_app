# Workflow Provenance

This repository combines ideas from three historical sources.

## 1. Original Flemish Red List script
The main analytical logic, especially for Criterion A and the IFBL-based occupancy workflow, comes from the original Flanders fungal Red List script.

This includes:
- historical vs current period comparison
- IFBL occupancy logic
- DD / RE handling
- noTrend logic
- survey effort diagnostics
- occupancy-based Criterion B support

## 2. Czech Shiny Red List app
The app interface design is partly inspired by the Czech Red List Shiny workflow.

This includes:
- species-centric navigation
- raw record inspection
- map-based interpretation
- criterion display panels
- downloadable outputs

## 3. Broader Red List workflow inspiration
Parts of the original thinking were informed by previous Red List workflows used in other taxa, including butterfly Red List work in Flanders.

The new app should preserve the useful analytical structure of the old workflow while improving:
- reproducibility
- transparency
- modularity
- user-settable thresholds
- expert-review support

## Live Czech app reference

The current deployed Czech fungal Red List app is used as an interface and workflow reference:

https://redlist.shinyapps.io/workflow/

It is not a methodological template for Flemish criteria, but it is an important reference for:
- species-first navigation
- side-panel parameter inputs
- map / records / analysis / readme tab structure
- headline metric display
- downloadable outputs
