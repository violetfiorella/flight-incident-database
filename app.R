# app.R
# Author: Violet Fiorella
# Shiny dashboard for exploring flight incidents and adding new records.

if (!require(shiny)) install.packages("shiny")
if (!require(ggplot2)) install.packages("ggplot2")
if (!require(DT)) install.packages("DT")
library(shiny)
library(ggplot2)
library(DT)

source("db_connect.R")

chart_height <- "230px"

compact_theme <- theme_minimal(base_size = 11) +
  theme(plot.margin = margin(4, 8, 4, 4))

# Runs a query on a short-lived connection
runQuery <- function(sql) {
  con <- get_connection()
  on.exit(dbDisconnect(con))
  suppressWarnings(dbGetQuery(con, sql))
}

ui <- fluidPage(
  tags$head(tags$style(HTML("
    .kpi { padding: 8px 12px; margin-bottom: 8px; }
    .kpi strong { font-size: 12px; color: #555; }
    .kpi .shiny-text-output { font-size: 20px; font-weight: 600; }
    h5 { margin: 6px 0 2px; font-weight: 600; }
  "))),
  titlePanel("Flight Incident Analytics Dashboard"),
  tabsetPanel(
    
    tabPanel("Analytics",
             br(),
             fluidRow(
               column(3, div(class = "well kpi", strong("Total incidents"),
                             textOutput("statIncidents"))),
               column(3, div(class = "well kpi", strong("Airlines"),
                             textOutput("statAirlines"))),
               column(3, div(class = "well kpi", strong("Unique flights"),
                             textOutput("statFlights"))),
               column(3, div(class = "well kpi", strong("Date range"),
                             textOutput("statDates")))
             ),
             fluidRow(
               column(4, h5("Incidents per year"),
                      plotOutput("plotYear", height = chart_height)),
               column(4, h5("Incidents by type"),
                      plotOutput("plotType", height = chart_height)),
               column(4, h5("Incidents by severity"),
                      plotOutput("plotSeverity", height = chart_height))
             ),
             fluidRow(
               column(5, h5("Top 10 airlines by incident count"),
                      plotOutput("plotAirline", height = chart_height)),
               column(7, h5("Monthly incident trend"),
                      plotOutput("plotMonth", height = chart_height))
             )
    ),
    
    tabPanel("Add Incident",
             br(),
             fluidRow(
               column(4,
                      textInput("iid", "Incident ID", value = ""),
                      dateInput("incident_date", "Incident date", value = Sys.Date()),
                      numericInput("flight_number", "Flight number", value = 1000, min = 1),
                      numericInput("delay", "Delay (minutes)", value = 0, min = 0),
                      numericInput("num_injuries", "Number of injuries", value = 0, min = 0)
               ),
               column(4,
                      selectInput("airline_code", "Airline", choices = NULL),
                      selectInput("airport_code", "Departure airport", choices = NULL),
                      selectInput("aircraft_id", "Aircraft", choices = NULL),
                      selectInput("type_id", "Incident type", choices = NULL),
                      selectInput("severity_id", "Severity", choices = NULL),
                      selectInput("reporter_id", "Reported by", choices = NULL)
               ),
               column(4,
                      br(),
                      actionButton("addBtn", "Add incident", class = "btn-primary"),
                      br(), br(),
                      verbatimTextOutput("addStatus")
               )
             ),
             hr(),
             h4("10 most recently added incidents"),
             DTOutput("recentTable")
    )
  )
)

server <- function(input, output, session) {
  
  # Incremented after each insert to refresh dependent outputs
  refresh <- reactiveVal(0)
  
  # Populate dropdowns from lookup tables
  observe({
    airlines  <- runQuery("SELECT airline_code FROM airline ORDER BY airline_code")
    airports  <- runQuery("SELECT airport_code FROM airport ORDER BY airport_code")
    aircraft  <- runQuery("SELECT aircraft_id, model FROM aircraft ORDER BY model")
    types     <- runQuery("SELECT type_id, type_name FROM incident_type ORDER BY type_name")
    sevs      <- runQuery("SELECT severity_id, severity_name FROM severity ORDER BY severity_name")
    reporters <- runQuery("SELECT reporter_id, reporter_name FROM reporter ORDER BY reporter_name")
    
    updateSelectInput(session, "airline_code", choices = airlines$airline_code)
    updateSelectInput(session, "airport_code", choices = airports$airport_code)
    updateSelectInput(session, "aircraft_id",
                      choices = setNames(aircraft$aircraft_id, aircraft$model))
    updateSelectInput(session, "type_id",
                      choices = setNames(types$type_id, types$type_name))
    updateSelectInput(session, "severity_id",
                      choices = setNames(sevs$severity_id, sevs$severity_name))
    updateSelectInput(session, "reporter_id",
                      choices = setNames(reporters$reporter_id, reporters$reporter_name))
  })
  
  # KPIs
  output$statIncidents <- renderText({
    refresh()
    format(runQuery("SELECT COUNT(*) AS n FROM incident")$n, big.mark = ",")
  })
  output$statAirlines <- renderText({
    as.character(runQuery("SELECT COUNT(*) AS n FROM airline")$n)
  })
  output$statFlights <- renderText({
    refresh()
    format(runQuery(
      "SELECT COUNT(*) AS n FROM (SELECT DISTINCT airline_code, flight_number FROM incident) AS f"
    )$n, big.mark = ",")
  })
  output$statDates <- renderText({
    refresh()
    d <- runQuery("SELECT MIN(incident_date) AS lo, MAX(incident_date) AS hi FROM incident")
    paste(d$lo, "to", d$hi)
  })
  
  # Charts
  output$plotYear <- renderPlot({
    refresh()
    d <- runQuery(
      "SELECT strftime('%Y', incident_date) AS yr, COUNT(*) AS n
         FROM incident GROUP BY yr ORDER BY yr")
    ggplot(d, aes(x = factor(yr), y = n)) +
      geom_col(fill = "steelblue") +
      labs(x = NULL, y = "Incidents") +
      compact_theme +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })
  
  output$plotType <- renderPlot({
    refresh()
    d <- runQuery(
      "SELECT t.type_name AS type, COUNT(*) AS n
         FROM incident i JOIN incident_type t ON i.type_id = t.type_id
        GROUP BY t.type_name ORDER BY n DESC")
    ggplot(d, aes(x = reorder(type, n), y = n)) +
      geom_col(fill = "darkorange") +
      coord_flip() +
      labs(x = NULL, y = "Incidents") +
      compact_theme
  })
  
  output$plotSeverity <- renderPlot({
    refresh()
    d <- runQuery(
      "SELECT s.severity_name AS severity, COUNT(*) AS n
         FROM incident i JOIN severity s ON i.severity_id = s.severity_id
        GROUP BY s.severity_name ORDER BY n DESC")
    ggplot(d, aes(x = reorder(severity, n), y = n)) +
      geom_col(fill = "firebrick") +
      labs(x = NULL, y = "Incidents") +
      compact_theme
  })
  
  output$plotAirline <- renderPlot({
    refresh()
    d <- runQuery(
      "SELECT airline_code AS airline, COUNT(*) AS n
         FROM incident GROUP BY airline_code ORDER BY n DESC LIMIT 10")
    ggplot(d, aes(x = reorder(airline, n), y = n)) +
      geom_col(fill = "seagreen") +
      coord_flip() +
      labs(x = NULL, y = "Incidents") +
      compact_theme
  })
  
  output$plotMonth <- renderPlot({
    refresh()
    d <- runQuery(
      "SELECT strftime('%Y-%m-01', incident_date) AS mth, COUNT(*) AS n
         FROM incident GROUP BY mth ORDER BY mth")
    d$mth <- as.Date(d$mth)
    ggplot(d, aes(x = mth, y = n)) +
      geom_line(color = "steelblue") +
      labs(x = NULL, y = "Incidents") +
      compact_theme
  })
  
  # Insert a new incident from the form
  observeEvent(input$addBtn, {
    con <- get_connection()
    on.exit(dbDisconnect(con))
    
    result <- tryCatch({
      store_incident(con, input$iid, input$incident_date,
                     input$airline_code, input$flight_number,
                     input$airport_code, input$aircraft_id,
                     input$type_id, input$severity_id,
                     input$reporter_id, input$delay, input$num_injuries)
      "Incident added successfully."
    }, error = function(e) {
      paste("Error:", conditionMessage(e))
    })
    
    output$addStatus <- renderText(result)
    refresh(refresh() + 1)
  })
  
  output$recentTable <- renderDT({
    refresh()
    d <- runQuery(
      "SELECT iid, incident_date, airline_code, flight_number, airport_code, delay, num_injuries
         FROM incident ORDER BY iid DESC LIMIT 10")
    datatable(d, options = list(dom = "t"))
  })
}

shinyApp(ui = ui, server = server)