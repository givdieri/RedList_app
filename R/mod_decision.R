mod_decision_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Expert decision sheet"),
    shiny::selectInput(ns("final_category"), "Final expert-reviewed category", choices = c("NE", "DD", "RE", "CR", "EN", "VU", "NT", "LC")),
    shiny::textAreaInput(ns("decision_note"), "Final decision note", value = "", width = "100%")
  )
}

mod_decision_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::reactive(list(final_category = input$final_category, note = input$decision_note))
  })
}
