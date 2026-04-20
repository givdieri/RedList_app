# code the new Flanders Red List app here
library(shiny)

ui <- fluidPage(
  titlePanel("Flanders fungal Red List app"),
  p("App scaffold in progress.")
)

server <- function(input, output, session) {}

shinyApp(ui, server)
