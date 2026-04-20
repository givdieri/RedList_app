mod_maps_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Maps"),
    shiny::p("Map module scaffold. Will visualize historical/current occupancy in subsequent iterations.")
  )
}

mod_maps_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {})
}
