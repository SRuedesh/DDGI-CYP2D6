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

title_regex <- Sys.getenv("PROFILE_TITLE_REGEX")
observed_data_regex <- Sys.getenv("PROFILE_OBSERVED_DATA_REGEX")
if (!nzchar(title_regex)) {
  stop("PROFILE_TITLE_REGEX must select the profiles to regenerate.")
}

source(file.path(repo_root, "scripts", "configure-ddi-ratio-reporting.R"))

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

profile_plots <- configuration_plan$plots$ComparisonTimeProfilePlots
source_plan <- jsonlite::fromJSON(
  file.path(
    repo_root,
    "Qualification",
    "Input",
    "qualification_plan.json"
  ),
  simplifyVector = FALSE
)
source_profile_plots <- source_plan$Plots$ComparisonTimeProfilePlots

get_mapping_key <- function(mapping) {
  paste(
    mapping$Simulation,
    mapping$ObservedData,
    mapping$Output,
    sep = "\r"
  )
}

for (plot_index in seq_along(profile_plots)) {
  plot <- profile_plots[[plot_index]]
  mapping_keys <- vapply(plot$OutputMappings, get_mapping_key, character(1))
  source_matches <- vapply(
    source_profile_plots,
    function(source_plot) {
      identical(source_plot$SectionReference, plot$SectionReference) &&
        identical(
          vapply(source_plot$OutputMappings, get_mapping_key, character(1)),
          mapping_keys
        )
    },
    logical(1)
  )
  if (sum(source_matches) != 1L) {
    next
  }

  source_plot <- source_profile_plots[[which(source_matches)]]
  plot$Title <- source_plot$Title
  for (mapping_index in seq_along(plot$OutputMappings)) {
    source_mapping <- source_plot$OutputMappings[[mapping_index]]
    plot$OutputMappings[[mapping_index]]$Caption <- source_mapping$Caption
    plot$OutputMappings[[mapping_index]]$Color <- source_mapping$Color
    plot$OutputMappings[[mapping_index]]$Symbol <- source_mapping$Symbol
  }
  profile_plots[[plot_index]] <- plot
}

keep_plot <- vapply(
  profile_plots,
  function(plot) {
    title_matches <- grepl(title_regex, plot$Title, perl = TRUE)
    observed_data_matches <- !nzchar(observed_data_regex) ||
      any(vapply(
        plot$OutputMappings,
        function(mapping) {
          grepl(observed_data_regex, mapping$ObservedData, perl = TRUE)
        },
        logical(1)
      ))
    title_matches && observed_data_matches
  },
  logical(1)
)
selected_plot_indices <- which(keep_plot)
configuration_plan$plots$ComparisonTimeProfilePlots <- profile_plots[keep_plot]
if (!any(keep_plot)) {
  stop("No comparison-time-profile plot matches the requested filters.")
}

section_paths <- unique(vapply(
  configuration_plan$plots$ComparisonTimeProfilePlots,
  function(plot) configuration_plan$getSectionPath(plot$SectionReference),
  character(1)
))
for (section_path in section_paths) {
  dir.create(section_path, recursive = TRUE, showWarnings = FALSE)
}

render_started <- Sys.time()
workflow <- QualificationWorkflow$new(
  configurationPlan = configuration_plan,
  simulationSets = list(),
  workflowFolder = workflow_folder,
  createWordReport = FALSE
)
workflow$plotComparisonTimeProfile$runTask(configuration_plan)

profile_files <- unlist(
  lapply(
    section_paths,
    function(section_path) {
      files <- list.files(
        section_path,
        pattern = "^comparison_time_profile_.*[.]png$",
        recursive = TRUE,
        full.names = TRUE,
        ignore.case = TRUE
      )
      files[file.info(files)$mtime >= render_started]
    }
  ),
  use.names = FALSE
)
if (length(profile_files) == 0L) {
  stop("No selected profile images were regenerated.")
}
generated_plot_indices <- as.integer(sub(
  "^.*_([0-9]+)[.]png$",
  "\\1",
  profile_files
))
profile_files <- profile_files[order(generated_plot_indices)]
if (length(profile_files) != length(selected_plot_indices)) {
  stop("The number of regenerated profiles does not match the selection.")
}

workflow_root <- normalizePath(workflow_folder, winslash = "/")
manifest <- data.frame(source = character(), destination = character())
for (file_index in seq_along(profile_files)) {
  source_file <- profile_files[[file_index]]
  normalized_source <- normalizePath(source_file, winslash = "/")
  relative_file <- substring(normalized_source, nchar(workflow_root) + 2L)
  relative_file <- sub(
    "_[0-9]+[.]png$",
    paste0("_", selected_plot_indices[[file_index]], ".png"),
    relative_file
  )
  manifest <- rbind(
    manifest,
    data.frame(
      source = normalized_source,
      destination = file.path(
        repo_root,
        "Qualification",
        "report",
        relative_file
      )
    )
  )
}
manifest_file <- file.path(work_dir, "profile-plot-manifest.csv")
write.csv(manifest, manifest_file, row.names = FALSE, fileEncoding = "UTF-8")

message(
  "Regenerated ",
  length(profile_files),
  " comparison-time-profile image(s) without running the full report. ",
  "Copy manifest: ",
  manifest_file
)
