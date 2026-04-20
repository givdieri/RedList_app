mod_effort_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Survey effort diagnostics"),
    shiny::plotOutput(ns("effort_plot"), height = 300)
  )
}

mod_effort_server <- function(id, records_analysis, selected_species) {
  shiny::moduleServer(id, function(input, output, session) {
    output$effort_plot <- shiny::renderPlot({
      shiny::req(selected_species())
      df <- records_analysis[records_analysis$Species == selected_species(), ]
      shiny::validate(shiny::need(nrow(df) > 0, "No analysis records for selected species."))
      count_by_year <- aggregate(record_id ~ Year, df, length)
      names(count_by_year)[2] <- "n_records"
      graphics::plot(count_by_year$Year, count_by_year$n_records, type = "h", lwd = 2,
                     xlab = "Year", ylab = "Records", main = "Records per year")
    })
  })
}
