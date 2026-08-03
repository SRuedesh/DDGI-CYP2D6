suppressPackageStartupMessages(library(ospsuite.reportingengine))

repo_root <- normalizePath(
  Sys.getenv("REPO_ROOT"),
  winslash = "/",
  mustWork = TRUE
)
work_dir <- normalizePath(
  Sys.getenv("QUALIFICATION_WORK_DIR"),
  winslash = "/",
  mustWork = TRUE
)
reference_folder <- normalizePath(
  Sys.getenv("QUALIFICATION_REFERENCE_FOLDER"),
  winslash = "/",
  mustWork = TRUE
)

source(file.path(repo_root, "scripts", "configure-ddi-ratio-reporting.R"))

# Ratio-only runs reuse staged PK analysis files. Disable the ospsuite
# simulation cache because renamed simulation aliases can otherwise resolve
# to a stale staged path within the same R session.
original_load_simulation <- ospsuite::loadSimulation
ratio_simulation_cache <- new.env(parent = emptyenv())
ratio_load_simulation <- function(filePath, loadFromCache = TRUE, ...) {
  cache_key <- normalizePath(filePath, winslash = "/", mustWork = TRUE)
  if (!exists(cache_key, envir = ratio_simulation_cache, inherits = FALSE)) {
    assign(
      cache_key,
      original_load_simulation(filePath, loadFromCache = FALSE, ...),
      envir = ratio_simulation_cache
    )
  }
  get(cache_key, envir = ratio_simulation_cache, inherits = FALSE)
}
assignInNamespace(
  "loadSimulation",
  ratio_load_simulation,
  ns = "ospsuite"
)

report_theme_file <- file.path(
  repo_root,
  "Qualification",
  "Input",
  "report-theme.json"
)
resetRESettingsToDefault()
setDefaultThemeFromJson(report_theme_file)

workflow_folder <- file.path(work_dir, "re_output")
configuration_plan <- loadConfigurationPlan(
  workflowFolder = workflow_folder,
  configurationPlanFile = file.path(
    reference_folder,
    "report-configuration-plan.json"
  )
)
section_reference <- Sys.getenv("RATIO_SECTION_REFERENCE")
selected_plot_index <- NA_integer_
section_output_path <- NULL
if (nzchar(section_reference)) {
  ratio_plots <- configuration_plan$plots$DDIRatioPlots
  keep_plot <- vapply(
    ratio_plots,
    function(plot) identical(plot$SectionReference, section_reference),
    logical(1)
  )
  selected_plot_index <- which(keep_plot)
  configuration_plan$plots$DDIRatioPlots <- ratio_plots[keep_plot]
  if (!any(keep_plot)) {
    stop("No ratio plot section matches: ", section_reference)
  }
}
workflow <- QualificationWorkflow$new(
  configurationPlan = configuration_plan,
  simulationSets = list(),
  workflowFolder = workflow_folder,
  createWordReport = FALSE
)
if (nzchar(section_reference)) {
  section_output_path <- configuration_plan$getSectionPath(section_reference)
  dir.create(
    section_output_path,
    recursive = TRUE,
    showWarnings = FALSE
  )
}
workflow$plotDDIRatio$runTask(configuration_plan)

if (!is.na(selected_plot_index) && selected_plot_index != 1L) {
  generated_files <- list.files(
    section_output_path,
    pattern = "^DDIRatio_1_.*[.]png$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  renamed_files <- sub(
    "^DDIRatio_1_",
    paste0("DDIRatio_", selected_plot_index, "_"),
    basename(generated_files)
  )
  renamed <- file.rename(
    generated_files,
    file.path(dirname(generated_files), renamed_files)
  )
  if (any(!renamed)) {
    stop("Could not preserve ratio-plot section numbering.")
  }
}

ratio_files <- list.files(
  file.path(workflow_folder, "images"),
  pattern = "ddi_ratio_plot.*[.]png$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(ratio_files) == 0L) {
  stop("No ratio-plot images were generated.")
}

copy_ratio_files <- function(target_root) {
  source_root <- normalizePath(workflow_folder, winslash = "/")
  for (source_file in ratio_files) {
    normalized_source <- normalizePath(source_file, winslash = "/")
    relative_file <- substring(
      normalized_source,
      nchar(source_root) + 2L
    )
    target_file <- file.path(target_root, relative_file)
    dir.create(dirname(target_file), recursive = TRUE, showWarnings = FALSE)
    copied <- file.copy(source_file, target_file, overwrite = TRUE)
    if (!copied) {
      stop("Could not copy ratio plot to ", target_file)
    }
  }
}

copy_ratio_files(file.path(work_dir, "report"))
copy_ratio_files(file.path(repo_root, "Qualification", "report"))

message(
  "Regenerated and copied ",
  length(ratio_files),
  " ratio-plot images without running simulations or PK calculations."
)
