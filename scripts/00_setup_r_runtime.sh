#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  r-base \
  r-base-dev \
  r-cran-dplyr \
  r-cran-readr \
  r-cran-readxl \
  r-cran-stringr \
  r-cran-tidyr \
  r-cran-shiny \
  r-cran-dt

R --version
Rscript --version
