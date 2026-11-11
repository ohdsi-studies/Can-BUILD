# Running the Study on Your Data

Instructions for running this study against your own OMOP CDM. If you get stuck
on anything platform-specific, the [OHDSI HADES guides](#where-to-look-if-you-get-stuck)
cover it in more detail.

**The only file you edit is `ExecuteAnalyses.R`.** Everything else is either code
you do not need to touch, or files this guide tells you to create.

---

## 1. Install the environment

Follow [Setting up the R environment](https://ohdsi.github.io/Hades/rSetup.html)
for your operating system. You need:

- **R 4.6.2** — the version pinned in `renv.lock`. (HADES currently targets 4.6.1;
  either works, but 4.6.2 is what this study was tested with.)
- **Java 17 or newer** — [Corretto 21](https://docs.aws.amazon.com/corretto/latest/corretto-21-ug/downloads-list.html)
  is what OHDSI recommends.
- **RStudio** (recommended, not required).

> **Java 8 will not work.** DatabaseConnector 8 fails on it with
> `NoSuchMethodError: java.nio.ByteBuffer.clear()`. Check with `java -version`.

---

## 2. Get the repository

```bash
git clone https://github.com/ohdsi-studies/Can-BUILD.git
cd Can-BUILD
```

Then in R, from the project folder:

```r
renv::restore()
```

**Restart R afterwards.** The first restore takes a while.

> Do **not** run `renv::snapshot()`. `renv.lock` is frozen before sites run;
> see [renv/README.md](renv/README.md).

---

## 3. Find out how to connect to your database

Each database platform needs slightly different connection details. Look yours
up in [the DatabaseConnector connection reference](https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html)
— it lists exactly which arguments each platform requires.

The common cases:

### PostgreSQL

```r
dbms   <- "postgresql"
server <- "host/database"        # e.g. "db.example.org/cdm"
user   <- "my_user"
```

### Microsoft SQL Server

```r
dbms   <- "sql server"
server <- "host.example.org"     # host name only - no database name
user   <- "my_user"
```

If you leave `user` blank, Windows Integrated Security is used instead.

To use Kerberos from a Mac or Linux machine,
`extraSettings = "authenticationScheme=JavaKerberos"`, with a ticket from
`kinit` — see
[Windows authentication](https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html#windows-authentication-for-sql-server).

### Oracle

```r
dbms   <- "oracle"
server <- "host/sid"             # SID, host/sid, host/service name, or a TNS name
user   <- "my_user"
```

### Snowflake, IRIS, Spark / Databricks, BigQuery

These use a JDBC connection string rather than host, e.g. for Snowflake:

```r
dbms             <- "snowflake"
connectionString <- "jdbc:snowflake://<account>.snowflakecomputing.com/?db=<db>&warehouse=<wh>&schema=<schema>"
user             <- "my_user"
```

### Redshift and Synapse

Both accept `server` and `port` like PostgreSQL:

```r
dbms   <- "redshift"             # or "synapse"
server <- "host.example.org/database"
user   <- "my_user"
```

Check the [reference](https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html)
for your platform's exact `server` format and default port.

### SQLite and DuckDB

No JDBC driver is needed — the `RSQLite` / `duckdb` packages are used instead.
Give the database file path as `server`:

```r
dbms   <- "sqlite"               # or "duckdb"
server <- "/path/to/database.file"
```

The full list of supported platforms, and their HADES support status, is at
[Supported Database Platforms](https://ohdsi.github.io/Hades/supportedPlatforms.html).

---

## 4. Install the database driver

The JDBC driver is a `.jar` file. Put it in a folder and tell R where that
folder is — ideally once, in your `.Renviron`:

```bash
DATABASECONNECTOR_JAR_FOLDER="C:/temp/jdbcDrivers"     # Windows
DATABASECONNECTOR_JAR_FOLDER="/Users/me/jdbcDrivers"   # macOS / Linux
```

Then download the driver for your platform:

```r
DatabaseConnector::downloadJdbcDrivers("postgresql")   # or "sql server", "oracle", ...
```

This works for SQL Server, Oracle, PostgreSQL, PDW, Spark, Redshift, Snowflake,
BigQuery and Synapse. BigQuery, Netezza, Impala and InterSystems IRIS need to be
obtained separately — see
[the driver instructions](https://ohdsi.github.io/DatabaseConnector/reference/jdbcDrivers.html).

To open `.Renviron`:

```r
usethis::edit_r_environ()    # or create the file yourself in the project folder
```

`.Renviron` is read **only at R startup** — restart R after editing it.

---

## 5. Put your password somewhere safe

**Do not type your password into `ExecuteAnalyses.R`.** That file is committed to
GitHub.

Use your operating system's keychain:

```r
keyring::key_set("ohdsi")     # prompts once, stores it encrypted
```

Or put it in `.Renviron`, which git ignores:

```bash
OHDSI_PASSWORD="your password"
OHDSI_SERVER="db.example.org/cdm"
OHDSI_USER="my_user"
```

---

## 6. Edit the INPUTS block in `ExecuteAnalyses.R`

Open `ExecuteAnalyses.R`. The first ~40 lines are the INPUTS block. Change these
values to match your site:

```r
cdmDatabaseSchema  <- "my_cdm"        # schema with the clinical tables AND vocabulary
workDatabaseSchema <- "my_scratch"    # schema the study may write to
cohortTableName    <- "can_build_cohort"
resultsFolder      <- "results"
workFolder         <- "strategusInternals"
databaseName       <- "MY_SITE"       # names the results sub-folder
minCellCount       <- 5               # small cells are masked in the output
```

Then the connection, using whichever form you found in step 3:

```r
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms        = "postgresql",
  server      = Sys.getenv("OHDSI_SERVER", "db.example.org/cdm"),
  user        = Sys.getenv("OHDSI_USER", "my_user"),
  password    = Sys.getenv("OHDSI_PASSWORD"),
  pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
)
```

### Two things that catch people out

**The vocabulary must be in the same schema as the clinical tables.** The study
needs `person` *and* `concept` in `cdmDatabaseSchema`. Many sites keep the
vocabulary in a separate schema; if yours does, ask your DBA for a schema or a
view layer that exposes both.

**The work schema must be writable.** The study creates cohort tables there. It
never writes to your CDM.

---

## 7. Test the connection before running anything

Uncomment these two lines at the end of the INPUTS block and run them:

```r
conn <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::disconnect(conn)
```

If that errors, fix it now — the message will tell you whether the problem is the
driver, the server, the credentials, or the schema name.

Then check the data is where you said it is:

```r
conn <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::querySql(conn, "SELECT COUNT(*) FROM my_cdm.person;")
DatabaseConnector::querySql(conn, "SELECT COUNT(*) FROM my_cdm.concept;")
DatabaseConnector::disconnect(conn)
```

Both should return a number. `0` people means you have pointed at the wrong
schema; an error on `concept` means the vocabulary is not there.

---

## 8. Run the study

```r
source("ExecuteAnalyses.R")
```

Three modules run in order: CohortGenerator, CohortDiagnostics,
Characterization. You get a summary at the end:

```
✔ CohortGeneratorModule
✔ CohortDiagnosticsModule
✔ CharacterizationModule
```

Results appear in `results/<databaseName>/`.

If it stops part-way, re-running resumes where it stopped — the modules are
incremental.

---

## 9. Check the results and share them

The main output is `results/<databaseName>/CharacterizationModule/c_incidence_summary.csv`.

Then:

```r
source("ShareResults.R")
```

It zips the aggregate results and asks before uploading anything. The ZIP
contains counts and statistics only — no patient-level data.

---

## Where to look if you get stuck

| Problem | Guide |
|---|---|
| Installing R, Java, RTools, RStudio | [Setting up the R environment](https://ohdsi.github.io/Hades/rSetup.html) |
| Installing all HADES packages | [Installing HADES](https://ohdsi.github.io/Hades/installingHades.html) |
| Connecting to your database | [Connecting to a Database](https://ohdsi.github.io/Hades/connecting.html) |
| Which arguments your platform needs | [`createConnectionDetails` reference](https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html) |
| JDBC drivers, Windows auth, Kerberos | [Connecting to a database (DatabaseConnector)](https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html) |
| Drivers that must be sourced separately | [jdbcDrivers reference](https://ohdsi.github.io/DatabaseConnector/reference/jdbcDrivers.html) |
| Is my platform supported? | [Supported Database Platforms](https://ohdsi.github.io/Hades/supportedPlatforms.html) |
| How the CDM is organised | [The Book of OHDSI](https://ohdsi.github.io/TheBookOfOhdsi/) |

### Known error messages

| Message | Cause |
|---|---|
| `NoSuchMethodError: java.nio.ByteBuffer.clear()` | Java 8. Install Java 17+ and restart R. |
| `The pathToDriver argument hasn't been specified` | No JDBC driver. Set `DATABASECONNECTOR_JAR_FOLDER` or `pathToDriver`. |
| `relation "my_cdm.concept" does not exist` | Vocabulary is in a different schema from `person`. |
| `permission denied for schema my_scratch` | Your user cannot write to the work schema. |
| R hangs at startup | renv is installing itself. Let it finish once. |

If none of this helps, raise an issue with the log attached — it is at
`results/<databaseName>/strategus-log.txt`. Please do not post credentials or
patient-level data.
