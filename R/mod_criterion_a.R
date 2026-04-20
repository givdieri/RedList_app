mod_criterion_a_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Criterion A (legacy-compatible v1)"),
    shiny::tableOutput(ns("a_table")),
    shiny::verbatimTextOutput(ns("a_summary")),
    shiny::textAreaInput(ns("a_note"), "Criterion A note", value = "", width = "100%")
  )
}

mod_criterion_a_server <- function(id, records_analysis, selected_species, settings_reactive) {
  shiny::moduleServer(id, function(input, output, session) {
    result <- shiny::reactive({
      shiny::req(selected_species())
      compute_criterion_a(records_analysis, selected_species(), settings_reactive())
    })

    output$a_table <- shiny::renderTable(result()$occupancy)

    output$a_summary <- shiny::renderText({
      r <- result()
      paste0(
        "Provisional A category: ", r$category, "\n",
        "Decline (%): ", ifelse(is.na(r$decline_pct), "NA", round(r$decline_pct, 1)), "\n",
        "Reason: ", r$reason
      )
    })

    shiny::reactive(list(note = input$a_note, result = result()))
  })
}
