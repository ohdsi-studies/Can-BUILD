################################################################################
# INSTRUCTIONS: This script assumes you have cohorts you would like to use in an
# ATLAS instance. Please note you will need to update the baseUrl to match
# the settings for your enviroment. You will also want to change the 
# CohortGenerator::saveCohortDefinitionSet() function call arguments to identify
# a folder to store your cohorts. This code will store the cohorts in 
# "inst/sampleStudy" as part of the template for reference. You should store
# your settings in the root of the "inst" folder and consider removing the 
# "inst/sampleStudy" resources when you are ready to release your study.
# 
# See the Download cohorts section
# of the UsingThisTemplate.md for more details.
# ##############################################################################

source("scriptsForStudyDesigner/WebApiHelperFunctions.R")
library(dplyr)
config <- config::get()
authWebApi(authMethod = "none")

# Define the cohorts that you'd like to download for use in this 
# study. Here is how the cohortsToDownload tribble is organized
#  - atlasCohortId: must match the ATLAS cohort identifier
#  - cohortId: a custom cohort ID or set to NA to use the ATLAS cohort identifier
#  - cohortName: a custom cohort name or set to NA to the ATLAS cohort name
cohortsToDownload <- tibble::tribble(
  ~atlasCohortId, ~cohortId, ~cohortName,
  # The study cohorts. These must stay in step with inst/Cohorts.csv, which
  # this script regenerates.
  1798688, 1, "Fiscal year cohort with 365 days prior observation",
  1798701, 2, "Fiscal year cohort with 1095 days prior observation",
  1798796, 101, "[BUILD] Autism_opl_591",
  1798795, 201,	"[BUILD] Asthma_opl_334",
  1798794, 202, "[BUILD] Asthma_opl_1164",
  1798793, 203, "[BUILD] Asthma_opl_521",
  1798792, 301, "[BUILD] Epilepsy_opl_254",
  1798791, 302, "[BUILD] Epilepsy_opl_549",
  1798790, 303, "[BUILD] Epilepsy_opl_1007",
  1798789, 401, "[BUILD] COPD_opl_1271",
  1798788, 402, "[BUILD] COPD_opl_1192"
)

downloadCohortDefinitionSet(
  config = config,
  cohortsToDownload = cohortsToDownload
)
	

