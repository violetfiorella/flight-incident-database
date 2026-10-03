# test_db_loading.R
# Author: Violet Fiorella
# Validates the database load against the source CSV.

source("db_connect.R")
con <- get_connection()

url <- "https://s3.us-east-2.amazonaws.com/artificium.us/datasets/incidents-v2.csv"
df.raw <- read.csv(url, header = TRUE, stringsAsFactors = FALSE)

reportTest <- function(label, csv.value, db.value) {
  outcome <- if (csv.value == db.value) "PASSED" else "FAILED"
  cat(sprintf("%-40s CSV = %-12s DB = %-12s [%s]\n",
              label, csv.value, db.value, outcome))
}

cat("-------------------------------------------------------------\n")

# Row count
csv.incidents <- nrow(df.raw)
db.incidents  <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM incident")$n
reportTest("Number of incidents", csv.incidents, db.incidents)

# Unique airlines
csv.airlines <- length(unique(df.raw$airline))
db.airlines  <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM airline")$n
reportTest("Number of unique airlines", csv.airlines, db.airlines)

# Unique flights, defined as distinct (airline, flight number) pairs
csv.flights <- nrow(unique(df.raw[, c("airline", "flightNumber")]))
db.flights  <- dbGetQuery(con,
                          "SELECT COUNT(*) AS n FROM (SELECT DISTINCT airline_code, flight_number FROM incident) AS f")$n
reportTest("Number of unique flights", csv.flights, db.flights)

# Date range
csv.dates <- as.Date(df.raw$date, format = "%d.%m.%Y")

csv.first <- as.character(min(csv.dates))
db.first  <- dbGetQuery(con, "SELECT MIN(incident_date) AS d FROM incident")$d
reportTest("Earliest incident date", csv.first, db.first)

csv.last <- as.character(max(csv.dates))
db.last  <- dbGetQuery(con, "SELECT MAX(incident_date) AS d FROM incident")$d
reportTest("Latest incident date", csv.last, db.last)

# Aggregates
csv.delay <- sum(df.raw$delay)
db.delay  <- dbGetQuery(con, "SELECT SUM(delay) AS s FROM incident")$s
reportTest("Total delay (sum)", csv.delay, db.delay)

csv.injuries <- sum(df.raw$num.injuries)
db.injuries  <- dbGetQuery(con, "SELECT SUM(num_injuries) AS s FROM incident")$s
reportTest("Total injuries (sum)", csv.injuries, db.injuries)

csv.avg <- round(mean(df.raw$delay), 2)
db.avg  <- round(dbGetQuery(con, "SELECT AVG(delay) AS a FROM incident")$a, 2)
reportTest("Average delay (rounded)", csv.avg, db.avg)

cat("-------------------------------------------------------------\n")

dbDisconnect(con)