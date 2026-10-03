# load_db.R
# Author: Violet Fiorella
# Loads the incident CSV and populates the normalized tables.

source("db_connect.R")
con <- get_connection()

url <- "https://s3.us-east-2.amazonaws.com/artificium.us/datasets/incidents-v2.csv"
df.raw <- read.csv(url, header = TRUE, stringsAsFactors = FALSE)

# Optional row limit for development (0 loads all rows)
dev.limit <- 0
if (dev.limit > 0) {
  df.raw <- df.raw[1:dev.limit, ]
}

n.rows <- nrow(df.raw)

# Source dates use D.M.YYYY format
incident.dates <- as.Date(df.raw$date, format = "%d.%m.%Y")

# Escapes single quotes for SQL string literals
escapeSQL <- function(txt) {
  gsub("'", "''", txt)
}

# Single transaction so a failed load leaves the database unchanged
dbBegin(con)

# Populate lookup tables with unique values
unique.airlines <- unique(df.raw$airline)
vals <- paste0("('", escapeSQL(unique.airlines), "')", collapse = ", ")
dbExecute(con, paste0("INSERT INTO airline (airline_code) VALUES ", vals))

unique.airports <- unique(df.raw$dep.airport)
vals <- paste0("('", escapeSQL(unique.airports), "')", collapse = ", ")
dbExecute(con, paste0("INSERT INTO airport (airport_code) VALUES ", vals))

unique.aircraft <- unique(df.raw$aircraft)
vals <- paste0("('", escapeSQL(unique.aircraft), "')", collapse = ", ")
dbExecute(con, paste0("INSERT INTO aircraft (model) VALUES ", vals))

unique.types <- unique(df.raw$incidentType)
vals <- paste0("('", escapeSQL(unique.types), "')", collapse = ", ")
dbExecute(con, paste0("INSERT INTO incident_type (type_name) VALUES ", vals))

unique.severities <- unique(df.raw$severity)
vals <- paste0("('", escapeSQL(unique.severities), "')", collapse = ", ")
dbExecute(con, paste0("INSERT INTO severity (severity_name) VALUES ", vals))

unique.reporters <- unique(df.raw$reported.by)
vals <- paste0("('", escapeSQL(unique.reporters), "')", collapse = ", ")
dbExecute(con, paste0("INSERT INTO reporter (reporter_name) VALUES ", vals))

# Map each row to its surrogate keys
map.aircraft <- dbGetQuery(con, "SELECT aircraft_id, model FROM aircraft")
map.type     <- dbGetQuery(con, "SELECT type_id, type_name FROM incident_type")
map.severity <- dbGetQuery(con, "SELECT severity_id, severity_name FROM severity")
map.reporter <- dbGetQuery(con, "SELECT reporter_id, reporter_name FROM reporter")

aircraft.ids <- map.aircraft$aircraft_id[match(df.raw$aircraft, map.aircraft$model)]
type.ids     <- map.type$type_id[match(df.raw$incidentType, map.type$type_name)]
severity.ids <- map.severity$severity_id[match(df.raw$severity, map.severity$severity_name)]
reporter.ids <- map.reporter$reporter_id[match(df.raw$reported.by, map.reporter$reporter_name)]

# Insert incidents in batches of 500 rows
batch.size <- 500

for (start in seq(1, n.rows, by = batch.size)) {
  end <- min(start + batch.size - 1, n.rows)
  
  row.values <- character(end - start + 1)
  pos <- 1
  for (i in start:end) {
    row.values[pos] <- paste0(
      "('", escapeSQL(df.raw$iid[i]), "', ",
      "'", incident.dates[i], "', ",
      "'", escapeSQL(df.raw$airline[i]), "', ",
      df.raw$flightNumber[i], ", ",
      "'", escapeSQL(df.raw$dep.airport[i]), "', ",
      aircraft.ids[i], ", ",
      type.ids[i], ", ",
      severity.ids[i], ", ",
      reporter.ids[i], ", ",
      df.raw$delay[i], ", ",
      df.raw$num.injuries[i], ")"
    )
    pos <- pos + 1
  }
  
  sql <- paste0(
    "INSERT INTO incident ",
    "(iid, incident_date, airline_code, flight_number, airport_code, ",
    "aircraft_id, type_id, severity_id, reporter_id, delay, num_injuries) VALUES ",
    paste0(row.values, collapse = ", ")
  )
  dbExecute(con, sql)
}

dbCommit(con)

loaded <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM incident")
cat("Rows loaded into incident:", loaded$n, "\n")

dbDisconnect(con)