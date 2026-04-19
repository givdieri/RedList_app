# RedList_app

A modular Shiny application for fungal Red List assessment in Flanders.

## Purpose

This repository contains a decision-support system for fungal Red Listing in Flanders, using the combined Funbel + waarnemingen.be dataset as the primary analytical backend.

The app is intended to:
- inspect species-level raw records
- quantify survey effort and occupancy patterns
- reproduce the legacy Criterion A workflow as closely as possible
- provide a more transparent Criterion B workflow focused on fragmentation and continuing decline in the current period
- support expert-reviewed final category assignment
- export reproducible assessment outputs

The application is not intended to function as a rigid automatic classifier. Final category assignment remains an expert-reviewed decision.

## Repository structure

```text
RedList_app/
├── app.R
├── R/
├── app_data/
├── data_raw/
├── docs/
├── exports/
├── scripts/
└── spatial/
