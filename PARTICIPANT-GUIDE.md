# Running the Study on Your Data

This guide is for study-a-thon participants. It takes you from a fresh clone to
aggregate results on your own OMOP CDM, in four steps.

You do **not** edit any tracked file. Everything specific to your site lives in
one checked-in file (`ExecuteAnalyses.R`), plus `.Renviron` for your password
if you do not use the OS keychain.

---

## Before you start

You need:

- **R 4.6.2** — `renv` pins it.
- **Java 17 or newer** — DatabaseConnector 8 fails on Java 8 with
  `NoSuchMethodError: java.nio.ByteBuffer.clear()`.
- **Git** and a terminal (or RStudio).
- Read access to your **OMOP CDM**, and a schema you can **write** to.
- The **JDBC driver** for your database platform.

The study creates cohort tables in your work schema. It never modifies your CDM.

---

## Step 1 — Clone and restore the R environment

```bash
git clone https://github.com/azimov/Can-BUILD.git
cd Can-BUILD
```

Then, in R, from the project root:

```r
renv::restore()
```

This installs the ~285 package versions pinned in `renv.lock`. It takes a while
the first time. **Restart R afterwards.**

> **Read [renv/README.md](renv/README.md) before running `renv::snapshot()`.**
> `renv.lock` pins more than the study scripts `library()` on purpose -
> CohortDiagnostics, OhdsiShinyAppBuilder, OhdsiShinyModules and
> OhdsiReportGenerator are needed for the results app and the report generator,
> which load at run time rather than being `library()`-ed. `StudyPackages.R`
> lists all of them so a snapshot keeps them. You never need to snapshot: just
> use `renv::restore()`.

> If `renv::restore()` asks to install renv itself or seems to hang before R
> starts, install renv into your system library once:
> `install.packages("renv")`, then start R in the project directory again.

---

## Step 2 — Tell the study about your database

Everything you need to change is in the **INPUTS block at the top of
`ExecuteAnalyses.R`**. Open the file, edit those values, save it. There is no
separate settings file and no script to run.

```r
##=========== START OF INPUTS ==========
cdmDatabaseSchema  <- "my_cdm"       # clinical tables AND vocabulary
workDatabaseSchema <- "my_scratch"   # must be writable
cohortTableName    <- "can_build_cohort"
resultsFolder      <- "results"
workFolder         <- "strategusInternals"
databaseName       <- "MY_SITE"
minCellCount       <- 5

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = Sys.getenv("OHDSI_SERVER", "db.example.org/cdm"),
  user = Sys.getenv("OHDSI_USER", "my_user"),
  password = Sys.getenv("OHDSI_PASSWORD"),
  pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
)
##=========== END OF INPUTS ==========
```

### The password

`ExecuteAnalyses.R` is committed to git, so **do not type your password into
it**. Use one of these instead:

**OS keychain (recommended).** Store it once per machine:

```r
keyring::key_set("ohdsi")     # prompts for the password, stores it encrypted
```

then set `password = keyring::key_get("ohdsi")` in the INPUTS block.

**.Renviron.** Create a file called `.Renviron` in the project folder:

```bash
OHDSI_PASSWORD="your password"
OHDSI_SERVER="db.example.org/cdm"
OHDSI_USER="my_user"
```

`.Renviron` is in `.gitignore`, so git will not commit it. R reads it **only at
startup** — after creating or changing it, restart R.

### Check list before your first run

Work down this list. Each item gives a clear error if it is wrong, so you will
find out immediately rather than half an hour into a run.

| Check | How to verify |
|---|---|
| Java 17 or newer | `export JAVA_HOME=/path/to/jdk-17`, restart R. Java 8 fails with `NoSuchMethodError: java.nio.ByteBuffer.clear()` |
| JDBC driver present | `DatabaseConnector::downloadJdbcDrivers("postgresql")`, or point `pathToDriver` at a folder of `.jar` files |
| Password loads | `Sys.getenv("OHDSI_PASSWORD")` returns it, not `""` |
| Connection works | uncomment the `connect()` / `disconnect()` pair in the INPUTS block and run it |
| CDM readable | the schema contains `person`, `observation_period` and `visit_occurrence` |
| Vocabulary present | `concept`, `concept_ancestor` and `concept_relationship` are in the **same** schema as `person` |
| Work schema writable | your database user has `CREATE` permission in `workDatabaseSchema` |

The vocabulary item trips people up most often: many sites keep the vocabulary
in a separate schema from the clinical data. The study needs both in one schema,
or a view layer that exposes both as one.


## Step 3 — Create the analysis specification

Only needed once, or after a design change — the specification is already in the
repository:

```r
source("scriptsForStudyDesigner/CreateStrategusAnalysisSpecifications.R")
```

It reads the cohorts from `inst/` and writes `inst/analysisSpecifications.json`.
No database connection is needed for this step.

---

## Step 4 — Run the study

```r
source("ExecuteAnalyses.R")
```

This runs three Strategus modules in order:

| Module | What it does | Rough time on 10k patients |
|---|---|---|
| CohortGenerator | Builds the cohorts into your work schema | under a minute |
| CohortDiagnostics | Cohort diagnostics | ~3 minutes |
| Characterization | Baseline characteristics, incidence rates, point prevalence | ~30 minutes |

Progress is printed as each module runs, and you get a summary at the end:

```
✔ CohortGeneratorModule
✔ CohortDiagnosticsModule
✔ CharacterizationModule
```

Results land in `results/<databaseName>/`:

```
results/MY_SITE/
├── CohortGeneratorModule/   cohort counts, inclusion rules
├── CohortDiagnosticsModule/ cohort diagnostics tables
└── CharacterizationModule/
    ├── c_incidence_summary.csv   ← the primary output
    ├── c_target_covariates.csv   baseline characteristics
    ├── c_target_counts.csv
    └── ...
```

### If it fails part-way

Each module is incremental, so re-running `ExecuteAnalyses.R` resumes where it
stopped rather than starting again. To run only one module, uncomment
`modulesToExecute` in `ExecuteAnalyses.R`:

```r
executionSettings <- Strategus::createCdmExecutionSettings(
  ...,
  modulesToExecute = c("CharacterizationModule")
)
```

To start completely afresh, delete the folders under
`strategusInternals/<databaseName>/` and `results/<databaseName>/`, and drop the
cohort tables from your work schema.

---

## Reading the results

`c_incidence_summary.csv` is long-format. Two things to know:

- **`ref_id` distinguishes the two designs**: `1` is the incidence-rate design,
  `2` the point-prevalence design. A `tar_id` of 1 is reused by both, so filter
  on `ref_id`, not `tar_id`.
- **`characterization_target_id` is an internal ID**, not your cohort ID. Join
  through `c_target_settings.csv` to get it back.

```r
library(dplyr); library(readr)
path <- "results/MY_SITE/CharacterizationModule"

incidence <- read_csv(file.path(path, "c_incidence_summary.csv"))
targets   <- read_csv(file.path(path, "c_target_settings.csv"))
outcomes  <- read_csv(file.path(path, "c_outcome_def.csv"))

incidence |>
  filter(ref_id == 1, is.na(age_group_id), is.na(gender_name)) |>  # overall, not a stratum
  left_join(select(targets, characterization_target_id, target_id),
            by = "characterization_target_id") |>
  left_join(select(outcomes, outcome_id, outcome_cohort_definition_id),
            by = "outcome_id") |>
  select(target = target_id, outcome = outcome_cohort_definition_id,
         start_year, persons_at_risk, person_days, outcomes,
         rate_per_100py = incidence_rate_p_100py)
```

Cells smaller than `minCellCount` are masked with `-5`, so your site's small
counts are not disclosed.

---

## Sharing your results

```r
source("ShareResults.R")
```

This zips the aggregate CSVs in `results/<databaseName>/`. Only aggregate results
are included — no patient-level data. Send the ZIP to the study coordinator as
directed.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `NoSuchMethodError: java.nio.ByteBuffer.clear()` | Java 8. The setup script checks for this first; install Java 17+ and set `JAVA_HOME`. |
| `The pathToDriver argument hasn't been specified` | Set `pathToDriver`, or run `DatabaseConnector::downloadJdbcDrivers("<dbms>")`. |
| `You must provide a default configuration` | `config.yml` is missing — you are not in the project root, or the clone is incomplete. |
| `These target cohort IDs are not in inst/Cohorts.csv` | `inst/` is incomplete; re-clone or restore the cohort assets. |
| R seems to hang at startup | renv is installing itself. Let it finish once; after that under a minute is normal. |
| `roles` / permission errors creating tables | Your work schema is not writable, or the user lacks `CREATE`. |
| Very slow characterization | Expected on large datasets. It is parallelised; raise `maxCores` in `createCdmExecutionSettings()` if you have cores free. |

Raise an issue with the log from `results/<databaseName>/strategus-log.txt`
attached. Do not post credentials or patient-level data.
