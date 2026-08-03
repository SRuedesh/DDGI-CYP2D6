suppressPackageStartupMessages(library(ospsuite.reportingengine))

repo_root <- normalizePath(
  Sys.getenv("REPO_ROOT"),
  winslash = "/",
  mustWork = TRUE
)
source(file.path(repo_root, "scripts", "configure-ddi-ratio-reporting.R"))

if (!isTRUE(l10n_info()[["UTF-8"]])) {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
}
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  stop("A UTF-8 R locale is required to render the qualification report.")
}

enable_memory_safe_simulation_validation <- function() {
  original_initialize <- SimulationSet$public_methods$initialize
  patched_initialize <- original_initialize
  original_body <- as.list(body(original_initialize))
  body(patched_initialize) <- as.call(c(
    as.name("{"),
    original_body[-1],
    quote(rm(simulation)),
    quote(ospsuite::clearMemory())
  ))

  SimulationSet$unlock()
  on.exit(SimulationSet$lock())
  SimulationSet$set(
    "public",
    "initialize",
    patched_initialize,
    overwrite = TRUE
  )
}

enable_memory_safe_simulation_validation()

split_markdown_row <- function(line) {
  line <- sub("^\\s*\\|", "", line)
  line <- sub("\\|\\s*$", "", line)
  trimws(strsplit(line, "|", fixed = TRUE)[[1]])
}

format_markdown_row <- function(values) {
  paste0("| ", paste(values, collapse = " | "), " |")
}

harmonize_markdown_tables <- function(lines) {
  legacy_columns <- c(
    "Source",
    "Route",
    "Schedule",
    "Pop.",
    "Sex",
    "N",
    "Perpetrator"
  )
  legacy_order <- c(1L, 3L, 2L, 7L, 4L, 5L, 6L)
  legacy_names <- c(
    "Clinical reference",
    "Victim dose regimen",
    "Victim route",
    "Perpetrator regimen",
    "Population",
    "Sex",
    "Participants"
  )

  line_index <- 1L
  while (line_index < length(lines)) {
    if (
      !grepl("^\\s*\\|", lines[[line_index]]) ||
        !grepl("^\\s*\\|(?:\\s*:?-+:?\\s*\\|)+\\s*$", lines[[line_index + 1L]])
    ) {
      line_index <- line_index + 1L
      next
    }

    header <- gsub("\\*\\*", "", split_markdown_row(lines[[line_index]]))
    table_end <- line_index + 1L
    while (
      table_end < length(lines) &&
        grepl("^\\s*\\|", lines[[table_end + 1L]])
    ) {
      table_end <- table_end + 1L
    }

    if (identical(header, legacy_columns)) {
      table_rows <- lapply(
        lines[(line_index + 2L):table_end],
        split_markdown_row
      )
      lines[[line_index]] <- format_markdown_row(legacy_names)
      lines[[line_index + 1L]] <- format_markdown_row(
        rep("---", length(legacy_names))
      )
      for (row_offset in seq_along(table_rows)) {
        lines[[line_index + 1L + row_offset]] <- format_markdown_row(
          table_rows[[row_offset]][legacy_order]
        )
      }
    } else {
      header <- sub("^Data identifier$", "Data ID", header)
      header <- sub("^Study$", "Clinical reference", header)
      header <- sub("^Route and dose$", "Victim dose regimen", header)
      header <- sub("^CYP2D6 groups$", "CYP2D6 group(s)", header)
      header <- sub("^(Endpoints|Analyte\\(s\\))$", "Analyte(s)", header)
      lines[[line_index]] <- format_markdown_row(header)
    }

    line_index <- table_end + 1L
  }
  lines
}

renumber_report_tables <- function(lines) {
  chapter <- NA_integer_
  chapter_table <- 0L
  previous_caption <- 0L

  for (line_index in seq_along(lines)) {
    heading_match <- regexec("^# ([0-9]+) ", lines[[line_index]])
    heading_parts <- regmatches(lines[[line_index]], heading_match)[[1]]
    if (length(heading_parts) > 0L) {
      chapter <- as.integer(heading_parts[[2]])
      chapter_table <- 0L
      previous_caption <- line_index
      next
    }

    caption_match <- regexec(
      "^\\*\\*Table ([0-9]+)-([0-9]+):",
      lines[[line_index]]
    )
    caption_parts <- regmatches(lines[[line_index]], caption_match)[[1]]
    if (length(caption_parts) == 0L || is.na(chapter)) {
      next
    }

    chapter_table <- chapter_table + 1L
    old_number <- paste(caption_parts[[2]], caption_parts[[3]], sep = "-")
    new_number <- paste(chapter, chapter_table, sep = "-")
    block <- seq.int(previous_caption + 1L, line_index)
    lines[block] <- gsub(
      paste0("Table ", old_number),
      paste0("Table ", new_number),
      lines[block],
      fixed = TRUE
    )
    lines[block] <- gsub(
      paste0("table-", old_number),
      paste0("table-", new_number),
      lines[block],
      fixed = TRUE
    )
    previous_caption <- line_index
  }
  lines
}

harmonize_profile_captions <- function(lines, profile_plots) {
  profile_indices <- integer()

  for (line_index in seq_along(lines)) {
    image_match <- regexec(
      "comparison_time_profile_.*_([0-9]+)[.]png",
      lines[[line_index]]
    )
    image_parts <- regmatches(lines[[line_index]], image_match)[[1]]
    if (length(image_parts) == 0L) {
      next
    }

    profile_index <- as.integer(image_parts[[2]])
    if (profile_index < 1L || profile_index > length(profile_plots)) {
      stop("A concentration-time image has an invalid plot index.")
    }

    caption_candidates <- seq.int(
      line_index + 1L,
      min(line_index + 3L, length(lines))
    )
    caption_candidates <- caption_candidates[
      grepl("^\\*\\*Figure [0-9]+-[0-9]+:", lines[caption_candidates])
    ]
    if (length(caption_candidates) != 1L) {
      stop("A concentration-time image has no unique figure caption.")
    }

    caption_index <- caption_candidates[[1]]
    figure_match <- regexec(
      "^\\*\\*Figure ([0-9]+-[0-9]+):",
      lines[[caption_index]]
    )
    figure_parts <- regmatches(lines[[caption_index]], figure_match)[[1]]
    lines[[caption_index]] <- paste0(
      "**Figure ",
      figure_parts[[2]],
      ": ",
      comparison_time_profile_caption(profile_plots[[profile_index]]),
      "**"
    )
    profile_indices <- c(profile_indices, profile_index)
  }

  expected_indices <- seq_along(profile_plots)
  if (
    length(profile_indices) != length(expected_indices) ||
      !identical(sort(profile_indices), expected_indices)
  ) {
    stop(
      "The report does not contain exactly one image for every profile plot."
    )
  }

  lines
}

harmonize_report_notation <- function(lines) {
  table_rows <- grepl("^\\s*\\|", lines)
  lines[table_rows] <- gsub(
    "(?<=\\|)\\s*CMAX\\s*(?=\\|)",
    " C<sub>max</sub> ",
    lines[table_rows],
    perl = TRUE
  )
  lines[table_rows] <- gsub(
    "alpha-hydroxymetoprolol",
    "α-hydroxymetoprolol",
    lines[table_rows],
    fixed = TRUE
  )
  lines
}

report_theme_file <- file.path(
  repo_root,
  "Qualification",
  "Input",
  "report-theme.json"
)
if (!file.exists(report_theme_file)) {
  stop("The centralized report theme is missing: ", report_theme_file)
}
resetRESettingsToDefault()
setDefaultThemeFromJson(report_theme_file)

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
  work_dir,
  "report",
  "report.md"
)
workflow$createWordReport <- FALSE

static_images_folder <- file.path(
  repo_root,
  "Qualification",
  "Input",
  "Content",
  "images"
)
workflow_images_folder <- file.path(workflow$workflowFolder, "images")
dir.create(workflow_images_folder, recursive = TRUE, showWarnings = FALSE)
static_images <- list.files(static_images_folder, full.names = TRUE)
copied_images <- file.copy(
  static_images,
  workflow_images_folder,
  overwrite = TRUE
)
if (length(static_images) > 0L && !all(copied_images)) {
  stop("Not all static report images could be staged for rendering.")
}

workflow$runWorkflow()

report_folder <- dirname(workflow$reportFilePath)
report_text <- readLines(
  workflow$reportFilePath,
  encoding = "UTF-8",
  warn = FALSE
)
report_text <- harmonize_markdown_tables(report_text)
report_text <- renumber_report_tables(report_text)
source_plan <- jsonlite::fromJSON(
  file.path(
    repo_root,
    "Qualification",
    "Input",
    "qualification_plan.json"
  ),
  simplifyVector = FALSE
)
report_text <- harmonize_profile_captions(
  report_text,
  source_plan$Plots$ComparisonTimeProfilePlots
)
report_text <- harmonize_report_notation(report_text)
writeLines(
  report_text,
  workflow$reportFilePath,
  useBytes = TRUE
)
image_matches <- regmatches(
  report_text,
  gregexpr("!\\[[^]]*\\]\\([^)]+\\)", report_text, perl = TRUE)
)
image_links <- unlist(image_matches, use.names = FALSE)
image_paths <- sub(
  "^!\\[[^]]*\\]\\(([^ )]+).*$",
  "\\1",
  image_links,
  perl = TRUE
)
local_image_paths <- image_paths[!grepl("^https?://", image_paths)]
missing_images <- local_image_paths[
  !file.exists(file.path(report_folder, local_image_paths))
]

if (length(missing_images) > 0L) {
  stop(
    sprintf(
      "The rendered report references %d missing image(s).",
      length(missing_images)
    )
  )
}
