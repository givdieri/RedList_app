mod_criterion_b_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Criterion B (transparent rebuild, initial scaffold)"),
    shiny::p("v1 scaffold: focuses on current-period occupancy and space for decline/fragmentation diagnostics."),
    shiny::textAreaInput(ns("b_note"), "Criterion B note", value = "", width = "100%")
  )
}

mod_criterion_b_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::reactive(list(note = input$b_note))
  })
}
