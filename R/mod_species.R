mod_species_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::selectizeInput(ns("species"), "Species", choices = NULL, width = "100%"),
    shiny::tableOutput(ns("species_summary"))
  )
}

mod_species_server <- function(id, species_master) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::updateSelectizeInput(session, "species", choices = species_master$species_accepted, server = TRUE)

    selected_species <- shiny::reactive(input$species)

    output$species_summary <- shiny::renderTable({
      shiny::req(selected_species())
      species_master[species_master$species_accepted == selected_species(), c("species_accepted", "genus", "dutch_name", "n_records_total", "n_records_included")]
    })

    selected_species
  })
}
