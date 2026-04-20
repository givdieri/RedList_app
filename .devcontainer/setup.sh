#!/bin/bash
set -e

apt-get update

apt-get install -y \
  r-base \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libgdal-dev \
  libgeos-dev \
  libproj-dev \
  libudunits2-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  gdal-bin \
  proj-bin \
  libsqlite3-dev \
  make \
  g++ \
  gcc \
  git

Rscript -e "install.packages(c(
  'shiny',
  'tidyverse',
  'readxl',
  'readr',
  'sf',
  'lwgeom',
  'terra',
  'yaml',
  'DT',
  'plotly',
  'leaflet',
  'openxlsx',
  'lubridate'
), repos='https://cloud.r-project.org')"
