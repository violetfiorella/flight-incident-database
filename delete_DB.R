# delete_db.R
# Author: Violet Fiorella
# Drops all tables so the database can be rebuilt from scratch.

source("db_connect.R")
con <- get_connection()

# Fact table first, since it references the lookup tables
dbExecute(con, "DROP TABLE IF EXISTS incident")
dbExecute(con, "DROP TABLE IF EXISTS airline")
dbExecute(con, "DROP TABLE IF EXISTS airport")
dbExecute(con, "DROP TABLE IF EXISTS aircraft")
dbExecute(con, "DROP TABLE IF EXISTS incident_type")
dbExecute(con, "DROP TABLE IF EXISTS severity")
dbExecute(con, "DROP TABLE IF EXISTS reporter")

print(dbListTables(con))
dbDisconnect(con)