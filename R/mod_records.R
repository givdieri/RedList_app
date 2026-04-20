mod_records_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Raw records (selected species)"),
    DT::DTOutput(ns("records_table"))
  )
}

mod_records_server <- function(id, records_clean, selected_species) {
  shiny::moduleServer(id, function(input, output, session) {
    output$records_table <- DT::renderDT({
      shiny::req(selected_species())
      df <- records_clean[records_clean$species_accepted == selected_species(), ]
      DT::datatable(df, filter = "top", options = list(pageLength = 15, scrollX = TRUE))
    })
  })
}
