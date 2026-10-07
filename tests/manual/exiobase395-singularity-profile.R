#!/usr/bin/Rscript --vanilla

# M0 diagnostic (docs/leontief-singularity-recovery.md, Fase 0): source-level
# Leontief singularity profile per EXIOBASE 3.9.5 year, without running the
# full pipeline. Coefficients C = Z / x come straight from the prepared
# source_data/exiobase395/m_io_<year>.fst arrays (Z = intermediate block,
# x = rowSums over all outputs = gross_output_mp), mirroring
# scripts/modules/matrices/transformation.R: zero-output columns are zeroed.
# Direct labour totals the six "Employment hours" variables of sea.fst over x.
# Each year writes <year>_singular_profile.csv (and, when nullity > 0,
# <year>_dependent_columns.csv) into $WLV_CAMPAIGN_ROOT/results, plus a
# combined artifact covering every processed year. Set WLV_PROFILE_YEARS
# (comma separated) to process a subset of 1995:2022.

repo_root <- local({
  arguments <- commandArgs(trailingOnly = FALSE)
  file_argument <- grep("^--file=", arguments, value = TRUE)
  if (!length(file_argument)) {
    stop("Run this tool as an Rscript file.", call. = FALSE)
  }
  normalizePath(file.path(
    dirname(sub("^--file=", "", file_argument[[1L]])),
    "..", ".."
  ))
})

campaign_root <- Sys.getenv("WLV_CAMPAIGN_ROOT")
if (!nzchar(campaign_root)) {
  stop(
    "WLV_CAMPAIGN_ROOT is not set; launch via scripts/run-experiment.sh.",
    call. = FALSE
  )
}
results_dir <- file.path(campaign_root, "results")
if (!dir.exists(results_dir)) {
  stop(sprintf("Missing campaign results directory: %s", results_dir), call. = FALSE)
}

years_argument <- Sys.getenv("WLV_PROFILE_YEARS")
years <- if (nzchar(years_argument)) {
  trimws(strsplit(years_argument, ",", fixed = TRUE)[[1L]])
} else {
  as.character(1995:2022)
}
if (!length(years) || any(!grepl("^[0-9]{4}$", years))) {
  stop("WLV_PROFILE_YEARS must be comma separated four-digit years.", call. = FALSE)
}

method <- "exiobase395"
source_dir <- file.path(repo_root, "source_data", "exiobase395")
io_paths <- file.path(source_dir, sprintf("m_io_%s.fst", years))
missing_io <- years[!file.exists(io_paths)]
if (length(missing_io)) {
  stop(sprintf(
    "Missing prepared EXIOBASE 3.9.5 files for year(s): %s.",
    paste(missing_io, collapse = ", ")
  ), call. = FALSE)
}

source(file.path(repo_root, "scripts", "lib", "functions.R"))
source(file.path(repo_root, "scripts", "lib", "leontief_diagnostics.R"))

print(sessionInfo())

sea <- read_fst_array(file.path(source_dir, "sea.fst"))
sea_dimnames <- dimnames(sea)
sea_years <- sea_dimnames[[1L]]
sea_variables <- sea_dimnames[[2L]]
sea_sectors <- sea_dimnames[[3L]]
sea_countries <- sea_dimnames[[4L]]
sector_count <- length(sea_sectors)
country_count <- length(sea_countries)
hours_variables <- grep("^Employment hours: ", sea_variables, value = TRUE)
if (length(hours_variables) != 6L) {
  stop(sprintf(
    "Expected six 'Employment hours' variables in sea.fst, found %s.",
    length(hours_variables)
  ), call. = FALSE)
}
hours_variable_indices <- match(hours_variables, sea_variables)
gross_output_variable_index <- match("gross_output_mp", sea_variables)
if (is.na(gross_output_variable_index)) {
  stop("sea.fst does not carry the gross_output_mp variable.", call. = FALSE)
}

hours_total <- apply(
  sea[, hours_variable_indices, , , drop = FALSE],
  c(3L, 4L),
  sum,
  na.rm = TRUE
)
sea_hours_missing <- sum(!is.finite(
  sea[, hours_variable_indices, , , drop = FALSE]
))
gross_output_mp <- sea[, gross_output_variable_index, , , drop = FALSE]
rm(sea)
gc(full = TRUE)

profile_rows <- vector("list", length(years))
names(profile_rows) <- years

for (year in years) {
  started_at <- proc.time()
  cat(sprintf("\n=== year %s ===\n", year))
  sea_year_index <- match(year, sea_years)
  if (is.na(sea_year_index)) {
    stop(sprintf("sea.fst does not cover the year %s.", year), call. = FALSE)
  }

  m_io <- read_fst_array(file.path(source_dir, sprintf("m_io_%s.fst", year)))
  inputs <- dimnames(m_io)[[2L]]
  outputs <- dimnames(m_io)[[3L]]
  dimension <- length(inputs)
  if (dimension != sector_count * country_count ||
      length(outputs) <= dimension ||
      !identical(outputs[seq_len(dimension)], inputs)) {
    stop(sprintf("Unexpected m_io layout for the year %s.", year), call. = FALSE)
  }

  flows <- m_io[1L, , , drop = FALSE]
  dim(flows) <- c(dimension, length(outputs))
  dimnames(flows) <- list(inputs, outputs)
  x <- as.numeric(rowSums(flows))
  coefficients <- flows[, seq_len(dimension), drop = FALSE]
  rm(flows, m_io)
  gc(full = TRUE)

  zero_output <- !(x > 0)
  if (any(!zero_output)) {
    coefficients[, !zero_output] <- sweep(
      coefficients[, !zero_output, drop = FALSE],
      2L,
      x[!zero_output],
      "/"
    )
  }
  if (any(zero_output)) {
    coefficients[, zero_output] <- 0
  }
  dimnames(coefficients) <- list(inputs, inputs)

  sea_gross_output <- as.numeric(gross_output_mp[
    sea_year_index, 1L, , , drop = FALSE
  ])
  dim(sea_gross_output) <- c(sector_count, country_count)
  aligned_sea_gross_output <- numeric(dimension)
  labour_hours <- numeric(dimension)
  label_mismatches <- 0L
  for (country_index in seq_len(country_count)) {
    block <- ((country_index - 1L) * sector_count + 1L):
      (country_index * sector_count)
    country_code <- sea_countries[[country_index]]
    expected_labels <- paste(country_code, sea_sectors, sep = ".")
    if (!identical(inputs[block], expected_labels)) {
      label_mismatches <- label_mismatches + 1L
      next
    }
    labour_hours[block] <- hours_total[, country_index]
    aligned_sea_gross_output[block] <-
      sea_gross_output[, country_index]
  }
  if (label_mismatches > 0L) {
    stop(sprintf(
      "m_io input labels disagree with sea.fst in %s country block(s) for %s.",
      label_mismatches,
      year
    ), call. = FALSE)
  }
  gross_output_disagreement <- max(abs(
    aligned_sea_gross_output - x
  ) / pmax(abs(aligned_sea_gross_output), 1), na.rm = TRUE)
  labour_zero_output_anomalies <- sum(labour_hours > 0 & zero_output)

  labour <- numeric(dimension)
  labour[!zero_output] <-
    labour_hours[!zero_output] / x[!zero_output]
  names(labour) <- inputs

  result <- wlv_leontief_singularity_profile(
    coefficient_matrix = coefficients,
    labour_requirements = labour,
    method = method,
    year = year
  )
  profile_path <- file.path(results_dir, sprintf("%s_singular_profile.csv", year))
  utils::write.csv(
    result$profile,
    profile_path,
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
  if (length(result$dependent_columns) > 0L) {
    utils::write.csv(
      data.frame(sector = result$dependent_columns),
      file.path(results_dir, sprintf("%s_dependent_columns.csv", year)),
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
  }
  profile_rows[[year]] <- result$profile

  elapsed <- (proc.time() - started_at)[["elapsed"]]
  cat(sprintf(
    "year %s: dimension %s, classification %s, nullity %s, zero-VA %s, rcond %g, labour/zero-output %s, labels OK, go disagreement %g, %.0fs\n",
    year,
    dimension,
    result$profile$classification,
    result$profile$nullity,
    result$profile$zero_value_added_candidate_count,
    result$profile$rcond,
    labour_zero_output_anomalies,
    gross_output_disagreement,
    elapsed
  ))
  rm(coefficients, labour, result, x, labour_hours,
      aligned_sea_gross_output, sea_gross_output)
  gc(full = TRUE)
}

combined <- do.call(rbind, unname(profile_rows))
combined_path <- file.path(
  results_dir,
  sprintf("singular_profile_%s-%s.csv", min(years), max(years))
)
utils::write.csv(
  combined,
  combined_path,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
cat(sprintf("\nCombined profile artifact: %s\n", combined_path))
print(combined[
  ,
  c("year", "nullity", "zero_value_added_candidate_count", "classification"),
  drop = FALSE
], row.names = FALSE)
if (sea_hours_missing > 0L) {
  cat(sprintf(
    "NOTE: %s non-finite 'Employment hours' cells were treated as zero.\n",
    sea_hours_missing
  ))
}
