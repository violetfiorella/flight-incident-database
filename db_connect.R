# db_connect.R
# Author: Violet Fiorella
# Shared database helpers for the flight incident project.

if (!require(DBI)) install.packages("DBI")
if (!require(RSQLite)) install.packages("RSQLite")
library(DBI)
library(RSQLite)

db_file <- "incidents.db"

# Opens a connection with foreign key enforcement enabled
get_connection <- function() {
  con <- dbConnect(RSQLite::SQLite(), db_file)
  dbExecute(con, "PRAGMA foreign_keys = ON")
  con
}

# Inserts a single incident using a parameterized query
store_incident <- function(con, iid, incident_date, airline_code,
                           flight_number, airport_code, aircraft_id,
                           type_id, severity_id, reporter_id,
                           delay = 0, num_injuries = 0) {
  dbExecute(con,
            "INSERT INTO incident
       (iid, incident_date, airline_code, flight_number, airport_code,
        aircraft_id, type_id, severity_id, reporter_id, delay, num_injuries)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            params = list(iid, as.character(incident_date), airline_code,
                          as.integer(flight_number), airport_code,
                          as.integer(aircraft_id), as.integer(type_id),
                          as.integer(severity_id), as.integer(reporter_id),
                          as.integer(delay), as.integer(num_injuries)))
}