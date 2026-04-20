library(shiny)
library(DT)

source("R/helpers_data.R")
source("R/helpers_spatial.R")
source("R/helpers_redlist.R")
source("R/mod_settings.R")
source("R/mod_species.R")
source("R/mod_records.R")
source("R/mod_effort.R")
source("R/mod_criterion_a.R")
source("R/mod_criterion_b.R")
source("R/mod_maps.R")
source("R/mod_decision.R")

app_data <- load_app_data("app_data")
defaults <- settings_to_list(app_data$settings_defaults)

ui <- fluidPage(
  titlePanel("Flanders fungal Red List app (modular v1 scaffold)"),
  fluidRow(
    column(width = 3, mod_settings_ui("settings")),
    column(width = 9, mod_species_ui("species"))
  ),
  tabsetPanel(
    tabPanel("Records", mod_records_ui("records")),
    tabPanel("Effort", mod_effort_ui("effort")),
    tabPanel("Criterion A", mod_criterion_a_ui("criterion_a")),
    tabPanel("Criterion B", mod_criterion_b_ui("criterion_b")),
    tabPanel("Maps", mod_maps_ui("maps")),
    tabPanel("Decision", mod_decision_ui("decision"))
  )
)

server <- function(input, output, session) {
  settings <- mod_settings_server("settings", defaults)
  selected_species <- mod_species_server("species", app_data$species_master)

  mod_records_server("records", app_data$records_clean, selected_species)
  mod_effort_server("effort", app_data$records_analysis, selected_species)
  mod_criterion_a_server("criterion_a", app_data$records_analysis, selected_species, settings)
  mod_criterion_b_server("criterion_b")
  mod_maps_server("maps")
  mod_decision_server("decision")
}

shinyApp(ui, server)
