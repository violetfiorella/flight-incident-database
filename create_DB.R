# create_db.R
# Author: Violet Fiorella
# Creates the normalized (3NF) schema.

source("db_connect.R")
con <- get_connection()

# Lookup tables
dbExecute(con, "
  CREATE TABLE IF NOT EXISTS airline (
    airline_code VARCHAR(8) NOT NULL PRIMARY KEY
  )")

dbExecute(con, "
  CREATE TABLE IF NOT EXISTS airport (
    airport_code VARCHAR(8) NOT NULL PRIMARY KEY
  )")

dbExecute(con, "
  CREATE TABLE IF NOT EXISTS aircraft (
    aircraft_id INTEGER PRIMARY KEY AUTOINCREMENT,
    model VARCHAR(64) NOT NULL DEFAULT 'unknown'
  )")

dbExecute(con, "
  CREATE TABLE IF NOT EXISTS incident_type (
    type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name VARCHAR(32) NOT NULL DEFAULT 'unknown'
  )")

dbExecute(con, "
  CREATE TABLE IF NOT EXISTS severity (
    severity_id INTEGER PRIMARY KEY AUTOINCREMENT,
    severity_name VARCHAR(16) NOT NULL DEFAULT 'unknown'
  )")

dbExecute(con, "
  CREATE TABLE IF NOT EXISTS reporter (
    reporter_id INTEGER PRIMARY KEY AUTOINCREMENT,
    reporter_name VARCHAR(32) NOT NULL DEFAULT 'unknown'
  )")

# Fact table
dbExecute(con, "
  CREATE TABLE IF NOT EXISTS incident (
    iid VARCHAR(16) NOT NULL PRIMARY KEY,
    incident_date DATE NULL,
    airline_code VARCHAR(8) NULL,
    flight_number INTEGER NULL,
    airport_code VARCHAR(8) NULL,
    aircraft_id INTEGER NULL,
    type_id INTEGER NULL,
    severity_id INTEGER NULL,
    reporter_id INTEGER NULL,
    delay INTEGER NOT NULL DEFAULT 0,
    num_injuries INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (airline_code) REFERENCES airline (airline_code),
    FOREIGN KEY (airport_code) REFERENCES airport (airport_code),
    FOREIGN KEY (aircraft_id) REFERENCES aircraft (aircraft_id),
    FOREIGN KEY (type_id) REFERENCES incident_type (type_id),
    FOREIGN KEY (severity_id) REFERENCES severity (severity_id),
    FOREIGN KEY (reporter_id) REFERENCES reporter (reporter_id)
  )")

print(dbListTables(con))
dbDisconnect(con)
cat("Schema created.\n")