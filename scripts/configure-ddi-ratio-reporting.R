# Required because the plan schema permits one-sided limits, but Reporting
# Engine 2.4.0 drops them when the opposite bound is absent.
original_format_axis_properties <-
  ospsuite.reportingengine:::formatAxisProperties

if (!isTRUE(attr(original_format_axis_properties, "supportsPartialLimits"))) {
  patched_format_axis_properties <- function(axis_field) {
    properties <- original_format_axis_properties(axis_field)
    if (!is.null(axis_field$Min) && is.null(axis_field$Max)) {
      properties$max <- NA_real_
    }
    if (is.null(axis_field$Min) && !is.null(axis_field$Max)) {
      properties$min <- NA_real_
    }
    properties
  }
  attr(patched_format_axis_properties, "supportsPartialLimits") <- TRUE
  assignInNamespace(
    "formatAxisProperties",
    patched_format_axis_properties,
    ns = "ospsuite.reportingengine"
  )
}

# Required only for the portable local workflow, whose generated configuration
# and simulation files are staged in separate folders. Standard workflows do
# not set QUALIFICATION_REFERENCE_FOLDER and retain the public behavior.
original_load_configuration_plan <-
  ospsuite.reportingengine:::loadConfigurationPlan

if (!isTRUE(attr(original_load_configuration_plan, "supportsStagedInputs"))) {
  patched_load_configuration_plan <- function(
    configurationPlanFile,
    workflowFolder
  ) {
    plan <- original_load_configuration_plan(
      configurationPlanFile,
      workflowFolder
    )
    reference_folder <- Sys.getenv("QUALIFICATION_REFERENCE_FOLDER")
    if (!nzchar(reference_folder)) {
      return(plan)
    }

    plan$referenceFolder <- gsub("\\\\", "/", reference_folder)
    plan$intro[[1]]$Path <- "Intro/titlepage.md"
    mappings <- plan$.__enclos_env__$private$.simulationMappings
    mappings$path <- sub("[/\\\\]+$", "", mappings$path)
    plan$.__enclos_env__$private$.simulationMappings <- mappings
    plan
  }
  attr(patched_load_configuration_plan, "supportsStagedInputs") <- TRUE
  assignInNamespace(
    "loadConfigurationPlan",
    patched_load_configuration_plan,
    ns = "ospsuite.reportingengine"
  )
}

display_pk_parameter <- function(value) {
  sub("^CMAX$", "C<sub>max</sub>", as.character(value))
}

ratio_result_title <- function(title) {
  sub("s$", "", as.character(title))
}

reporting_namespace <- asNamespace("ospsuite.reportingengine")
reporting_captions <- get("captions", envir = reporting_namespace)
reporting_captions$ddi$gmfe <- function(title) {
  paste("GMFE for", ratio_result_title(title), "ratios")
}
reporting_captions$ddi$summaryTable <- function(title) {
  paste("Summary of", ratio_result_title(title), "results")
}
reporting_captions$ddi$measureTable <- function(
  title,
  pkParameter,
  guestDelta = NULL
) {
  paste(
    "Summary of",
    ratio_result_title(title),
    "results -",
    display_pk_parameter(pkParameter),
    "ratio.",
    "(&delta; =",
    guestDelta %||% 1,
    "in Guest *et al.* formula)"
  )
}
unlockBinding("captions", reporting_namespace)
assign("captions", reporting_captions, envir = reporting_namespace)
lockBinding("captions", reporting_namespace)

original_get_ddi_plot_caption <-
  ospsuite.reportingengine:::getDDIPlotCaption
patched_get_ddi_plot_caption <- function(
  title,
  subPlotCaption,
  pkParameter,
  plotTypeCaption,
  guestDelta = NULL
) {
  original_get_ddi_plot_caption(
    title = title,
    subPlotCaption = subPlotCaption,
    pkParameter = display_pk_parameter(pkParameter),
    plotTypeCaption = plotTypeCaption,
    guestDelta = guestDelta
  )
}
assignInNamespace(
  "getDDIPlotCaption",
  patched_get_ddi_plot_caption,
  ns = "ospsuite.reportingengine"
)

comparison_time_profile_caption <- function(plot) {
  study <- sub(":.*$", "", as.character(plot$Title))
  contexts <- unique(vapply(
    plot$OutputMappings,
    function(mapping) as.character(mapping$Caption),
    character(1)
  ))
  contexts <- contexts[nzchar(trimws(contexts))]
  if (length(contexts) == 0L) {
    stop("A concentration-time profile has no report-facing context: ", study)
  }
  paste0(study, ": ", paste(contexts, collapse = "; "))
}

parent_victim <- function(analyte) {
  analyte <- as.character(analyte)
  normalized <- tolower(analyte)
  families <- c(
    "(e)-clomiphene" = "(E)-Clomiphene",
    "(e)-4-hydroxyclomiphene" = "(E)-Clomiphene",
    "(e)-n-desethylclomiphene" = "(E)-Clomiphene",
    "(e)-4-hydroxy-n-desethylclomiphene" = "(E)-Clomiphene",
    "desipramine" = "Desipramine",
    "2-hydroxydesipramine" = "Desipramine",
    "dextromethorphan" = "Dextromethorphan",
    "dextrorphan" = "Dextromethorphan",
    "total dextrorphan" = "Dextromethorphan",
    "metoprolol" = "Metoprolol",
    "metoprolol racemate" = "Metoprolol",
    "r-metoprolol" = "Metoprolol",
    "s-metoprolol" = "Metoprolol",
    "alpha-hydroxymetoprolol" = "Metoprolol",
    "risperidone" = "Risperidone",
    "9-hydroxyrisperidone" = "Risperidone",
    "quinidine" = "Quinidine",
    "3-hydroxyquinidine" = "Quinidine"
  )
  mapped <- unname(families[normalized])
  mapped[is.na(mapped)] <- analyte[is.na(mapped)]
  mapped
}

normalize_ddi_source_metadata <- function(dataframe, ddi_data_ids) {
  repository_root <- Sys.getenv("REPO_ROOT")
  map_candidates <- c(
    file.path(
      repository_root,
      "Qualification",
      "Input",
      "study_reference_map.csv"
    ),
    file.path(getwd(), "Input", "study_reference_map.csv")
  )
  map_path <- map_candidates[file.exists(map_candidates)][1]
  if (is.na(map_path)) {
    stop("The canonical DataID-to-study reference map is missing.")
  }

  study_map <- read.csv(
    map_path,
    colClasses = "character",
    check.names = FALSE
  )
  data_ids <- as.character(dataframe$id)
  ddi_rows <- data_ids %in% as.character(ddi_data_ids)
  row_index <- match(data_ids[ddi_rows], study_map$DataID)
  missing_ids <- unique(data_ids[ddi_rows][is.na(row_index)])
  if (length(missing_ids) > 0L) {
    stop(
      "The study reference map does not contain DataID(s): ",
      paste(missing_ids, collapse = ", ")
    )
  }
  dataframe$studyId <- as.character(dataframe$studyId)
  dataframe$studyId[ddi_rows] <- study_map$StudyKey[row_index]
  dataframe$description <- as.character(dataframe$description)
  storelli_paroxetine <-
    dataframe$studyId %in%
    "Storelli 2018" &
    tolower(as.character(dataframe$perpetrator)) %in% "paroxetine" &
    (is.na(dataframe$description) |
      !nzchar(trimws(dataframe$description)))
  dataframe$description[storelli_paroxetine] <- "BID"
  dataframe
}

parse_ratio_caption <- function(caption) {
  parts <- strsplit(as.character(caption), "\n", fixed = TRUE)[[1]]
  list(
    analyte = parts[[1]],
    perpetrator = if (length(parts) >= 2L && grepl("^\\+ ", parts[[2]])) {
      sub("^\\+ ", "", parts[[2]])
    } else {
      NA_character_
    },
    comparison = if (length(parts) >= 2L) {
      comparison_part <- parts[grepl("^\\| ", parts)]
      if (length(comparison_part) == 1L) {
        sub("^\\| ", "", comparison_part)
      } else {
        NA_character_
      }
    } else {
      NA_character_
    }
  )
}

is_ddgi_reference <- function(comparison) {
  comparison %in%
    c(
      "activity score 2 / activity score 2",
      "normal metabolizer / normal metabolizer"
    )
}

derive_ddgi_ratios <- function(dataframe) {
  reference_rows <- is_ddgi_reference(dataframe$cyp2d6Comparison)
  variants <- dataframe[!reference_rows, , drop = FALSE]
  references <- dataframe[reference_rows, , drop = FALSE]
  derived <- vector("list", nrow(variants))

  for (row_index in seq_len(nrow(variants))) {
    variant <- variants[row_index, , drop = FALSE]
    reference_selection <-
      references$ddgiPairingKey == variant$ddgiPairingKey &
      references$analyte == variant$analyte &
      references$perpetrator == variant$perpetrator &
      references$pkParameter == variant$pkParameter
    reference <- references[reference_selection, , drop = FALSE]
    if (nrow(reference) != 1L) {
      stop(
        "Expected one DDGI reference ratio for ",
        variant$ddgiPairingKey,
        ", ",
        variant$analyte,
        ", ",
        variant$pkParameter,
        "; found ",
        nrow(reference),
        "."
      )
    }

    variant$simulatedRatio <-
      variant$simulatedRatio / reference$simulatedRatio
    variant$observedRatio <-
      variant$observedRatio / reference$observedRatio
    variant$id <- paste(variant$id, reference$id, sep = " / ")
    derived[[row_index]] <- variant
  }

  derived <- do.call(rbind.data.frame, derived)
  endpoint_counts <- table(derived$pkParameter)
  expected_counts <- c(AUC = 41L, CMAX = 41L)
  if (
    !all(
      as.integer(endpoint_counts[names(expected_counts)]) ==
        unname(expected_counts)
    )
  ) {
    stop(
      "The derived DDGI dataset must contain 41 AUC and 41 Cmax ratios."
    )
  }
  derived
}

perpetrator_from_caption <- function(caption) {
  parse_ratio_caption(caption)$perpetrator
}

# Required because the public DDI data preparation does not retain analyte and
# CYP2D6 comparison fields and cannot calculate a DDGI ratio of DDI ratios.
original_get_ddi_plot_data <-
  ospsuite.reportingengine:::getQualificationDDIPlotData

if (!isTRUE(attr(original_get_ddi_plot_data, "supportsParentVictims"))) {
  patched_get_ddi_plot_data <- function(configurationPlan) {
    plot_data <- original_get_ddi_plot_data(configurationPlan)
    observed_groupings <- list()

    for (observed_id in c("DDI Ratios", "DGI Ratios")) {
      observed_path <- tryCatch(
        configurationPlan$getObservedDataPath(id = observed_id),
        error = function(error) NULL
      )
      if (is.null(observed_path) || !file.exists(observed_path)) {
        next
      }
      observed_data <- ospsuite.reportingengine:::readObservedDataFile(
        observed_path
      )
      observed_groupings[[observed_id]] <- setNames(
        as.character(observed_data$Grouping),
        as.character(observed_data$ID)
      )
    }

    for (plot_index in seq_along(plot_data)) {
      dataframe <- normalize_ddi_source_metadata(
        plot_data[[plot_index]]$dataframe,
        ddi_data_ids = names(observed_groupings[["DDI Ratios"]])
      )
      dataframe$analyte <- as.character(dataframe$victim)
      dataframe$victim <- parent_victim(dataframe$analyte)
      dataframe$cyp2d6Comparison <- "\u2014"
      dataframe$ddgiPairingKey <- NA_character_

      plot_groups <- plot_data[[plot_index]]$metadata$plotSettings$Groups
      for (group_index in seq_along(plot_groups)) {
        group <- plot_groups[[group_index]]
        caption_parts <- parse_ratio_caption(group$Caption)
        plan_perpetrator <- perpetrator_from_caption(group$Caption)
        if (!is.na(plan_perpetrator)) {
          dataframe$perpetrator[
            dataframe$groupNumber == group_index
          ] <- plan_perpetrator
        }
        if (!is.na(caption_parts$comparison)) {
          dataframe$cyp2d6Comparison[
            dataframe$groupNumber == group_index
          ] <- caption_parts$comparison
        }

        for (ratio in group$DDIRatios) {
          grouping_map <- observed_groupings[[ratio$ObservedData]]
          if (is.null(grouping_map)) {
            next
          }
          record_id <- as.character(ratio$ObservedDataRecordId)
          grouping <- grouping_map[[record_id]]
          if (is.null(grouping)) {
            next
          }
          row_selection <- as.character(dataframe$id) == record_id
          dataframe$ddgiPairingKey[row_selection] <- sub(
            "_(?:AS[0-9.]+|PM|IM|NM|UM|fastNM)$",
            "",
            grouping,
            ignore.case = TRUE,
            perl = TRUE
          )
        }
      }
      section_reference <-
        plot_data[[plot_index]]$metadata$plotSettings$SectionReference
      if (identical(section_reference, "ddgi-evaluations")) {
        dataframe <- derive_ddgi_ratios(dataframe)
      }
      plot_data[[plot_index]]$dataframe <- dataframe
    }
    plot_data
  }
  attr(patched_get_ddi_plot_data, "supportsParentVictims") <- TRUE
  assignInNamespace(
    "getQualificationDDIPlotData",
    patched_get_ddi_plot_data,
    ns = "ospsuite.reportingengine"
  )
}

# Required to omit non-evaluable endpoint/subunit combinations before the
# engine creates empty plots and repeated warnings.
original_get_ddi_section <- ospsuite.reportingengine:::getDDISection

if (!isTRUE(attr(original_get_ddi_section, "filtersUnevaluableRatios"))) {
  patched_get_ddi_section <- function(
    dataframe,
    metadata,
    sectionID,
    idPrefix,
    captionSuffix = NULL
  ) {
    evaluable <- is.finite(dataframe$observedRatio) &
      is.finite(dataframe$simulatedRatio)
    original_get_ddi_section(
      dataframe = dataframe[evaluable, , drop = FALSE],
      metadata = metadata,
      sectionID = sectionID,
      idPrefix = idPrefix,
      captionSuffix = captionSuffix
    )
  }
  attr(patched_get_ddi_section, "filtersUnevaluableRatios") <- TRUE
  assignInNamespace(
    "getDDISection",
    patched_get_ddi_section,
    ns = "ospsuite.reportingengine"
  )
}

# Required because the public table uses an inner merge for AUC and Cmax and
# does not provide separate parent-victim, analyte, and CYP2D6 columns.
patched_get_ddi_table <- function(dataframe) {
  dataframe$simObsRatio <- dataframe$simulatedRatio / dataframe$observedRatio
  perpetrator_values <- trimws(as.character(dataframe$perpetrator))
  is_dgi <- all(
    is.na(dataframe$perpetrator) |
      perpetrator_values %in% c("", "-", "NA")
  )
  ddi_tables <- list()

  for (pk_parameter in unique(dataframe$pkParameter)) {
    pk_dataframe <- dataframe[dataframe$pkParameter == pk_parameter, ]
    reference <- sprintf("[%s](#references)", pk_dataframe$studyId)
    table_data <- data.frame(
      DataID = pk_dataframe$id,
      Victim = pk_dataframe$victim,
      Analyte = pk_dataframe$analyte,
      `Victim route` = pk_dataframe$routeVictim,
      `CYP2D6 comparison` = pk_dataframe$cyp2d6Comparison,
      Reference = reference,
      check.names = FALSE
    )

    if (!is_dgi) {
      display_dose <- as.character(pk_dataframe$dose)
      display_dose[display_dose == "10.10.2010"] <- "10"
      table_data$Perpetrator <- paste(
        pk_dataframe$perpetrator,
        paste(display_dose, pk_dataframe$doseUnit),
        pk_dataframe$routePerpetrator,
        pk_dataframe$description,
        sep = ", "
      )
    }

    table_data[[paste("Predicted", pk_parameter, "ratio")]] <-
      pk_dataframe$simulatedRatio
    table_data[[paste("Observed", pk_parameter, "ratio")]] <-
      pk_dataframe$observedRatio
    table_data[[paste("Predicted/observed", pk_parameter, "ratio")]] <-
      pk_dataframe$simObsRatio
    ddi_tables[[pk_parameter]] <- table_data
  }

  merge_columns <- c(
    "DataID",
    "Victim",
    "Analyte",
    "Victim route",
    "CYP2D6 comparison",
    "Reference"
  )
  if (!is_dgi) {
    merge_columns <- c(merge_columns, "Perpetrator")
  }
  merged_table <- Reduce(
    function(x, y) merge(x, y, by = merge_columns, all = TRUE),
    ddi_tables
  )

  measure_columns <- setdiff(names(merged_table), merge_columns)
  auc_columns <- measure_columns[grepl(" AUC ratio$", measure_columns)]
  cmax_columns <- measure_columns[grepl(" CMAX ratio$", measure_columns)]
  identity_columns <- c("Victim", "Analyte")
  if (!is_dgi) {
    identity_columns <- c(identity_columns, "Perpetrator")
  }
  identity_columns <- c(
    identity_columns,
    "Victim route",
    "CYP2D6 comparison",
    "DataID"
  )
  merged_table <- merged_table[,
    c(identity_columns, auc_columns, cmax_columns, "Reference")
  ]

  row_order <- order(
    merged_table$Victim,
    merged_table$Analyte,
    if (is_dgi) rep("", nrow(merged_table)) else merged_table$Perpetrator,
    merged_table$`CYP2D6 comparison`,
    merged_table$DataID
  )
  merged_table <- merged_table[row_order, ]

  for (column in measure_columns) {
    merged_table[[column]] <- round(as.numeric(merged_table[[column]]), 2L)
  }

  for (column in names(merged_table)) {
    missing_values <- is.na(merged_table[[column]]) |
      trimws(as.character(merged_table[[column]])) == ""
    if (any(missing_values)) {
      merged_table[[column]] <- as.character(merged_table[[column]])
      merged_table[[column]][missing_values] <- "\u2014"
    }
  }
  data_id_label <- if (is_dgi) "Ratio record ID" else "Data ID"
  names(merged_table) <- sub("^DataID$", data_id_label, names(merged_table))
  names(merged_table) <- gsub(
    "CMAX",
    "C<sub>max</sub>",
    names(merged_table),
    fixed = TRUE
  )
  merged_table
}

attr(patched_get_ddi_table, "supportsParentVictims") <- TRUE
assignInNamespace(
  "getDDITable",
  patched_get_ddi_table,
  ns = "ospsuite.reportingengine"
)

# Required because the public plot maps both color and shape to one caption.
# It cannot provide independent victim fill, perpetrator shape, comparison
# outline, split legends, or content-responsive aggregate height.
original_generate_ddi_plot <-
  ospsuite.reportingengine:::generateDDIQualificationDDIPlot

coerce_point_shapes <- function(shapes) {
  shape_values <- as.character(unlist(shapes, use.names = FALSE))
  numeric_shapes <- suppressWarnings(as.integer(shape_values))
  numeric_entries <- !is.na(numeric_shapes) &
    grepl("^[0-9]+$", shape_values)

  if (all(numeric_entries)) {
    return(numeric_shapes)
  }
  if (any(numeric_entries)) {
    stop(
      "DDI plot shape values must not mix numeric codes and symbol glyphs."
    )
  }
  if (anyNA(shape_values) || any(!nzchar(shape_values))) {
    stop("DDI plot shape values must be non-empty symbol glyphs.")
  }
  shape_values
}

aggregate_ddi_chart_height <- function(
  current_height,
  analyte_count,
  perpetrator_count,
  legend_columns = 2L
) {
  legend_rows <- ceiling(analyte_count / legend_columns) +
    ceiling(perpetrator_count / legend_columns)
  max(current_height, 320 + 10 * legend_rows)
}

if (!isTRUE(attr(original_generate_ddi_plot, "supportsSplitLegends"))) {
  patched_generate_ddi_plot <- function(ddiPlotData, delta) {
    section_reference <- ddiPlotData$plotSettings$SectionReference
    captions <- unique(as.character(ddiPlotData$ddiPlotDataframe$Caption))
    caption_parts <- lapply(captions, parse_ratio_caption)
    analytes <- vapply(caption_parts, `[[`, character(1), "analyte")
    perpetrators <- vapply(
      caption_parts,
      `[[`,
      character(1),
      "perpetrator"
    )
    comparisons <- vapply(
      caption_parts,
      `[[`,
      character(1),
      "comparison"
    )
    is_dgi_ratio_plot <- identical(section_reference, "dgi-ratio-plots")
    is_ddgi_ratio_plot <- identical(section_reference, "ddgi-evaluations")
    is_aggregate_dgi_plot <- is_dgi_ratio_plot && length(captions) > 10L
    is_aggregate_ddi_plot <-
      identical(section_reference, "ddi-ratio-evaluations") &&
      length(captions) > 10L

    if (is_aggregate_ddi_plot) {
      analyte_count <- length(unique(analytes))
      perpetrator_count <- length(
        unique(perpetrators[!is.na(perpetrators)])
      )
      current_height <- ddiPlotData$plotSettings$FontAndSize$ChartHeight
      if (is.null(current_height)) {
        current_height <- 400
      }
      ddiPlotData$plotSettings$FontAndSize$ChartHeight <-
        aggregate_ddi_chart_height(
          current_height,
          analyte_count,
          perpetrator_count
        )
    }

    ddi_plot <- original_generate_ddi_plot(ddiPlotData, delta)
    if (is.null(ddi_plot)) {
      return(NULL)
    }

    if (identical(section_reference, "ddi-ratio-evaluations")) {
      ddi_plot$plotConfiguration$yAxis$axisLimits <- NULL
      ddi_plot$plotConfiguration$yAxis$ticks <- NULL
      ddi_plot$plotConfiguration$yAxis$ticklabels <- NULL
      ddi_plot <- ddi_plot$plotConfiguration$yAxis$updatePlot(
        ddi_plot,
        xAxisLimits = ddi_plot$plotConfiguration$xAxis$axisLimits
      )
    }

    colors <- unlist(ddiPlotData$aestheticsList$color[captions])
    shapes <- coerce_point_shapes(
      unlist(ddiPlotData$aestheticsList$shape[captions])
    )
    names(colors) <- captions
    names(shapes) <- captions

    ddi_plot$scales$scales <- Filter(
      function(scale) {
        !any(scale$aesthetics %in% c("colour", "color", "fill", "shape"))
      },
      ddi_plot$scales$scales
    )

    if (is_dgi_ratio_plot || is_ddgi_ratio_plot) {
      native_data <- ddiPlotData$ddiPlotDataframe
      native_caption_parts <- lapply(
        as.character(native_data$Caption),
        parse_ratio_caption
      )
      native_data$Analyte <- vapply(
        native_caption_parts,
        `[[`,
        character(1),
        "analyte"
      )
      native_data$Perpetrator <- vapply(
        native_caption_parts,
        `[[`,
        character(1),
        "perpetrator"
      )
      native_data$Comparison <- vapply(
        native_caption_parts,
        `[[`,
        character(1),
        "comparison"
      )
      ddi_plot$layers <- Filter(
        function(layer) {
          !any(grepl("Point", class(layer$geom), fixed = TRUE))
        },
        ddi_plot$layers
      )

      x_axis <- ddiPlotData$axesSettings$X$label
      y_axis <- ddiPlotData$axesSettings$Y$label
      native_mapping <- ggplot2::aes(
        x = .data[[x_axis]],
        y = .data[[y_axis]],
        fill = .data$Analyte,
        colour = .data$Comparison
      )
      if (is_ddgi_ratio_plot) {
        native_mapping$shape <-
          ggplot2::aes(shape = .data$Perpetrator)$shape
      }
      if (is_ddgi_ratio_plot) {
        ddi_plot <- ddi_plot +
          ggplot2::geom_point(
            data = native_data,
            mapping = native_mapping,
            inherit.aes = FALSE,
            size = 3,
            stroke = 0.9
          )
      } else {
        ddi_plot <- ddi_plot +
          ggplot2::geom_point(
            data = native_data,
            mapping = native_mapping,
            inherit.aes = FALSE,
            shape = 21L,
            size = 3,
            stroke = 0.9
          )
      }

      unique_analytes <- unique(analytes)
      fill_values <- colors[match(unique_analytes, analytes)]
      names(fill_values) <- unique_analytes
      unique_comparisons <- sort(unique(comparisons))
      comparison_values <- grDevices::hcl.colors(
        length(unique_comparisons),
        palette = "Dark 3"
      )
      names(comparison_values) <- unique_comparisons

      updated_plot <- ddi_plot +
        ggplot2::scale_fill_manual(
          values = fill_values,
          breaks = unique_analytes,
          name = "Analyte",
          drop = FALSE
        ) +
        ggplot2::scale_colour_manual(
          values = comparison_values,
          breaks = unique_comparisons,
          name = "Phenotype/activity-score comparison",
          drop = FALSE
        )

      if (is_ddgi_ratio_plot) {
        unique_perpetrators <- unique(perpetrators[!is.na(perpetrators)])
        if (length(unique_perpetrators) > 5L) {
          stop("DDGI fill/outline symbols support at most five perpetrators.")
        }
        perpetrator_shapes <- seq.int(
          21L,
          length.out = length(unique_perpetrators)
        )
        names(perpetrator_shapes) <- unique_perpetrators
        updated_plot <- updated_plot +
          ggplot2::scale_shape_manual(
            values = perpetrator_shapes,
            breaks = unique_perpetrators,
            name = "Perpetrator",
            drop = FALSE
          ) +
          ggplot2::guides(
            fill = ggplot2::guide_legend(
              order = 1,
              override.aes = list(shape = 21L, colour = "black", size = 4)
            ),
            shape = ggplot2::guide_legend(
              order = 2,
              override.aes = list(fill = "grey80", colour = "black", size = 4)
            ),
            colour = ggplot2::guide_legend(
              order = 3,
              override.aes = list(shape = 21L, fill = "white", size = 4)
            )
          )
      } else {
        legend_columns <- if (is_aggregate_dgi_plot) 2L else 1L
        updated_plot <- updated_plot +
          ggplot2::guides(
            fill = ggplot2::guide_legend(
              ncol = legend_columns,
              byrow = TRUE,
              order = 1,
              override.aes = list(shape = 21L, colour = "black", size = 4)
            ),
            colour = ggplot2::guide_legend(
              ncol = legend_columns,
              byrow = TRUE,
              order = 2,
              override.aes = list(shape = 21L, fill = "white", size = 4)
            ),
            shape = "none"
          )
        if (is_aggregate_dgi_plot) {
          updated_plot <- updated_plot +
            ggplot2::theme(
              legend.text = ggplot2::element_text(size = 10),
              legend.title = ggplot2::element_text(size = 10),
              legend.key.size = grid::unit(0.5, "cm")
            )
        }
      }
      return(updated_plot)
    }

    is_interaction_plot <- all(!is.na(perpetrators))
    if (is_interaction_plot) {
      color_entries <- !duplicated(analytes)
      shape_entries <- !duplicated(perpetrators)
      color_breaks <- captions[color_entries]
      color_labels <- analytes[color_entries]
      shape_breaks <- captions[shape_entries]
      shape_labels <- perpetrators[shape_entries]
      color_title <- "Analyte"
      shape_title <- "Perpetrator"
    } else {
      color_breaks <- captions
      color_labels <- captions
      shape_breaks <- captions
      shape_labels <- captions
      color_title <- "Analyte"
      shape_title <- NULL
    }

    color_guide <- ggplot2::guide_legend(
      ncol = 1,
      label.hjust = 0,
      order = 1
    )
    shape_guide <- if (is_dgi_ratio_plot) {
      "none"
    } else {
      ggplot2::guide_legend(ncol = 1, label.hjust = 0, order = 2)
    }

    if (is_aggregate_ddi_plot) {
      color_guide <- ggplot2::guide_legend(
        ncol = 2,
        byrow = TRUE,
        label.hjust = 0,
        order = 1,
        override.aes = list(size = 4)
      )
      shape_guide <- ggplot2::guide_legend(
        ncol = 2,
        byrow = TRUE,
        label.hjust = 0,
        order = 2,
        override.aes = list(size = 4)
      )
    }

    updated_plot <- ddi_plot +
      ggplot2::scale_color_manual(
        values = colors,
        limits = captions,
        breaks = color_breaks,
        labels = color_labels,
        drop = FALSE,
        name = color_title
      ) +
      ggplot2::scale_shape_manual(
        values = shapes,
        limits = captions,
        breaks = shape_breaks,
        labels = shape_labels,
        drop = FALSE,
        name = shape_title
      ) +
      ggplot2::guides(
        color = color_guide,
        shape = shape_guide
      )

    if (is_aggregate_ddi_plot) {
      updated_plot <- updated_plot +
        ggplot2::theme(
          legend.text = ggplot2::element_text(size = 11),
          legend.title = ggplot2::element_text(size = 11),
          legend.key.size = grid::unit(0.5, "cm")
        )
    }

    updated_plot
  }
  attr(patched_generate_ddi_plot, "supportsSplitLegends") <- TRUE
  assignInNamespace(
    "generateDDIQualificationDDIPlot",
    patched_generate_ddi_plot,
    ns = "ospsuite.reportingengine"
  )
}
