suppressPackageStartupMessages(library(ospsuite.reportingengine))

original_load_configuration_plan <- ospsuite.reportingengine:::loadConfigurationPlan

patched_load_configuration_plan <- function(
  configurationPlanFile,
  workflowFolder
) {
  plan <- original_load_configuration_plan(
    configurationPlanFile,
    workflowFolder
  )
  plan$referenceFolder <- gsub(
    "\\\\",
    "/",
    Sys.getenv("QUALIFICATION_REFERENCE_FOLDER")
  )
  plan$intro[[1]]$Path <- "Intro/titlepage.md"

  mappings <- plan$.__enclos_env__$private$.simulationMappings
  mappings$path <- sub("[/\\\\]+$", "", mappings$path)
  simulation_files <- file.path(
    plan$referenceFolder,
    mappings$path,
    paste0(mappings$simulationFile, ".pkml")
  )
  file_sizes <- file.info(simulation_files)$size
  valid_mappings <- file.exists(simulation_files) &
    !is.na(file_sizes) &
    file_sizes > 0

  if (!any(valid_mappings)) {
    stop(
      "No valid PKML simulation mapping is available for the report-only render."
    )
  }

  if (any(!valid_mappings)) {
    warning(
      sprintf(
        "Excluding %d simulation mapping(s) with missing or empty PKML files.",
        sum(!valid_mappings)
      )
    )
  }

  first_valid_mapping <- which(valid_mappings)[1]
  plan$.__enclos_env__$private$.simulationMappings <- mappings[
    first_valid_mapping,
    ,
    drop = FALSE
  ]
  plan$plots$AllPlots <- list()
  plan$plots$GOFMergedPlots <- list()
  plan$plots$ComparisonTimeProfilePlots <- list()
  plan$plots$DDIRatioPlots <- list()

  plan
}

assignInNamespace(
  "loadConfigurationPlan",
  patched_load_configuration_plan,
  ns = "ospsuite.reportingengine"
)

repo_root <- normalizePath(
  Sys.getenv("REPO_ROOT"),
  winslash = "/",
  mustWork = TRUE
)
work_dir <- gsub("\\\\", "/", Sys.getenv("QUALIFICATION_WORK_DIR"))
workflow <- loadQualificationWorkflow(
  workflowFolder = file.path(work_dir, "re_output"),
  configurationPlanFile = file.path(
    work_dir,
    "re_input",
    "report-configuration-plan.json"
  )
)
workflow$reportFilePath <- file.path(
  repo_root,
  "Qualification",
  "report",
  "report.md"
)
workflow$createWordReport <- FALSE
workflow$inactivateTasks(c(
  "simulate",
  "calculatePKParameters",
  "plotTimeProfiles",
  "plotComparisonTimeProfile",
  "plotGOFMerged",
  "plotPKRatio",
  "plotDDIRatio"
))

markdown_files <- ospsuite.reportingengine:::createSectionOutput(
  workflow$configurationPlan
)
initial_report_path <- file.path(
  workflow$workflowFolder,
  workflow$reportFileName
)
ospsuite.reportingengine:::mergeMarkdownFiles(
  markdown_files$appendices,
  initial_report_path
)
ospsuite.reportingengine:::renderReport(
  fileName = initial_report_path,
  createWordReport = workflow$createWordReport,
  numberSections = workflow$numberSections,
  intro = markdown_files$intro,
  wordConversionTemplate = workflow$wordConversionTemplate
)
ospsuite.reportingengine:::copyReport(
  from = initial_report_path,
  to = workflow$reportFilePath,
  copyWordReport = workflow$createWordReport,
  keep = TRUE
)
