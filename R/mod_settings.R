mod_settings_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Settings"),
    shiny::numericInput(ns("split_year"), "Historical/current split year", value = 2000, min = 1800, max = 2100),
    shiny::numericInput(ns("dd_threshold"), "DD occupied-grid threshold", value = 5, min = 1, max = 50),
    shiny::numericInput(ns("cr_decline"), "Criterion A CR decline (%)", value = -80, min = -100, max = 0),
    shiny::numericInput(ns("en_decline"), "Criterion A EN decline (%)", value = -50, min = -100, max = 0),
    shiny::numericInput(ns("vu_decline"), "Criterion A VU decline (%)", value = -30, min = -100, max = 0)
  )
}

mod_settings_server <- function(id, defaults) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observe({
      shiny::updateNumericInput(session, "split_year", value = defaults$split_year)
      shiny::updateNumericInput(session, "dd_threshold", value = defaults$dd_grid_threshold)
      shiny::updateNumericInput(session, "cr_decline", value = defaults$cr_decline)
      shiny::updateNumericInput(session, "en_decline", value = defaults$en_decline)
      shiny::updateNumericInput(session, "vu_decline", value = defaults$vu_decline)
    })

    shiny::reactive({
      list(
        split_year = as.integer(input$split_year),
        dd_grid_threshold = as.integer(input$dd_threshold),
        cr_decline = as.numeric(input$cr_decline),
        en_decline = as.numeric(input$en_decline),
        vu_decline = as.numeric(input$vu_decline),
        common_fraction = defaults$common_fraction
      )
    })
  })
}
