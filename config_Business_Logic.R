# config_business_logic.R
# Author: Violet Fiorella
# Demonstrates inserting a new incident with store_incident().

source("db_connect.R")
con <- get_connection()

# Existing lookup keys for the test record
demo <- list(
  airline  = dbGetQuery(con, "SELECT airline_code FROM airline LIMIT 1")$airline_code,
  airport  = dbGetQuery(con, "SELECT airport_code FROM airport LIMIT 1")$airport_code,
  aircraft = dbGetQuery(con, "SELECT aircraft_id FROM aircraft LIMIT 1")$aircraft_id,
  type     = dbGetQuery(con, "SELECT type_id FROM incident_type LIMIT 1")$type_id,
  severity = dbGetQuery(con, "SELECT severity_id FROM severity LIMIT 1")$severity_id,
  reporter = dbGetQuery(con, "SELECT reporter_id FROM reporter LIMIT 1")$reporter_id
)

dbExecute(con, "DELETE FROM incident WHERE iid = 'iTEST01'")

store_incident(con, "iTEST01", "2025-01-01", demo$airline, 9999,
               demo$airport, demo$aircraft, demo$type, demo$severity,
               demo$reporter, delay = 42, num_injuries = 0)

print(dbGetQuery(con, "SELECT * FROM incident WHERE iid = 'iTEST01'"))

# Clean up the test record
dbExecute(con, "DELETE FROM incident WHERE iid = 'iTEST01'")

dbDisconnect(con)