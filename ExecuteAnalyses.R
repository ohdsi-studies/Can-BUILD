# -------------------------------------------------------
#                     PLEASE READ
# -------------------------------------------------------
#
# You must call "renv::restore()" and follow the prompts
# to install all of the necessary R libraries to run this
# project. This is a one-time operation that you must do
# before running any code.
#
# !!! PLEASE RESTART R AFTER RUNNING renv::restore() !!!
#
# -------------------------------------------------------
renv::restore()

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING STUDY ------------
Sys.setenv("_JAVA_OPTIONS" = "-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS" = 1) # Sets the number of threads to 1 to avoid deadlocks on file system

##=========== START OF INPUTS ==========
# Everything you need to change for your database is in this block. There is no
# separate settings file: edit the values below, save, then run this script.
#
# If you prefer to keep them outside the repo, put them in your .Renviron and
# read them with Sys.getenv() - see the notes further down.

# --- Where the data is -------------------------------------------------------
cdmDatabaseSchema <- "my_cdm"      # schema with the clinical tables AND vocabulary
workDatabaseSchema <- "my_scratch" # schema the study may write to (cohort tables)
cohortTableName <- "can_build_cohort" # table created inside workDatabaseSchema

# --- Where the output goes ---------------------------------------------------
resultsFolder <- "results"          # output files
workFolder <- "strategusInternals"  # intermediate files, safe to delete
databaseName <- "MY_SITE"           # names the results sub-folder
minCellCount <- 5                   # small cells are masked in the output

# --- How to connect ----------------------------------------------------------
# Full documentation: https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html
#
# The password is deliberately NOT written in this file. Read it from one of:
#
#   keyring::key_get("ohdsi")   # recommended: OS keychain, set once with
#                               # keyring::key_set("ohdsi")
#   Sys.getenv("OHDSI_PASSWORD")  # from .Renviron, which git ignores
#
# On macOS or Linux, .Renviron lives in this folder and is read when R starts:
#
#   OHDSI_PASSWORD="your password"
#   OHDSI_SERVER="db.example.org/cdm"
#   OHDSI_USER="my_user"
#
# .Renviron is read ONLY at R startup, so restart R after editing it.
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = Sys.getenv("OHDSI_SERVER", "db.example.org/cdm"),
  user = Sys.getenv("OHDSI_USER", "my_user"),
  password = Sys.getenv("OHDSI_PASSWORD"),
  pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
)

# Java: DatabaseConnector needs Java 17 or newer. If your default java is older,
# point JAVA_HOME at a newer JDK before starting R:
#
#   export JAVA_HOME=/path/to/jdk-17
#
# JDBC driver: if pathToDriver is not set, download one once with
#   DatabaseConnector::downloadJdbcDrivers("postgresql")

# Check the connection before running the study. Run these four lines on their
# own and fix any error before going further:
#
#conn <- DatabaseConnector::connect(connectionDetails)
#DatabaseConnector::disconnect(conn)

##=========== END OF INPUTS ==========

##################################
# DO NOT MODIFY BELOW THIS POINT
##################################
resultsFolder <- file.path(resultsFolder, databaseName)
workFolder <- file.path(workFolder, databaseName)
cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTableName)

analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = file.path("inst", "analysisSpecifications.json")
)

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = cohortTableNames,
  workFolder = workFolder,
  resultsFolder = resultsFolder,
  minCellCount = minCellCount
  # IF YOU NEED TO RE-RUN A STUDY BUT ONLY WANT TO RUN SPECIFIC MODULES,
  # USE modulesToExecute:
  # , modulesToExecute = c("CohortGeneratorModule", "CharacterizationModule")
)

if (!dir.exists(resultsFolder)) {
  dir.create(resultsFolder, recursive = T)
}

if (!dir.exists(workFolder)) {
  dir.create(workFolder, recursive = T)
}

ParallelLogger::saveSettingsToJson(
  object = executionSettings,
  fileName = file.path(resultsFolder, "executionSettings.json")
)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
