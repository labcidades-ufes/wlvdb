#!/usr/bin/env Rscript

# Reproducible, process-isolated benchmark for the Leontief linear solve.
#
# The parent process reconstructs one annual system from the prepared WIOD
# source matrix and the published result artifacts. Each timed repetition is a
# fresh R process, so allocator state and retained matrices cannot leak from
# one strategy to the next. Peak resident memory is sampled by processx.

parse_arguments <- function(arguments) {
  values <- list(
    method = "wiodr16",
    channel = Sys.getenv("WLV_RELEASE_CHANNEL", "stable"),
    year = "2013",
    repetitions = 5L,
    poll_ms = 25,
    output = file.path(Sys.getenv("WLV_CAMPAIGN_ROOT"), "results", "leontief-benchmark")
  )
  child <- FALSE
  strategy <- fixture <- NULL

  index <- 1L
  while (index <= length(arguments)) {
    argument <- arguments[[index]]
    if (identical(argument, "--child")) {
      child <- TRUE
      index <- index + 1L
      next
    }
    if (!startsWith(argument, "--")) {
      stop(sprintf("Unexpected argument `%s`.", argument), call. = FALSE)
    }
    name <- gsub("-", "_", substring(argument, 3L), fixed = TRUE)
    if (index == length(arguments)) {
      stop(sprintf("Option `--%s` requires a value.", name), call. = FALSE)
    }
    value <- arguments[[index + 1L]]
    if (identical(name, "strategy")) {
      strategy <- value
    } else if (identical(name, "fixture")) {
      fixture <- value
    } else if (name %in% names(values)) {
      values[[name]] <- value
    } else {
      stop(sprintf("Unknown option `--%s`.", name), call. = FALSE)
    }
    index <- index + 2L
  }

  values$repetitions <- suppressWarnings(as.integer(values$repetitions))
  values$poll_ms <- suppressWarnings(as.numeric(values$poll_ms))
  if (is.na(values$repetitions) || values$repetitions < 1L) {
    stop("`--repetitions` must be a positive integer.", call. = FALSE)
  }
  if (!is.finite(values$poll_ms) || values$poll_ms <= 0) {
    stop("`--poll-ms` must be positive.", call. = FALSE)
  }
  values$child <- child
  values$strategy <- strategy
  values$fixture <- fixture
  values
}

run_child <- function(strategy, fixture_path) {
  if (is.null(strategy) || is.null(fixture_path)) {
    stop("Child mode requires `--strategy` and `--fixture`.", call. = FALSE)
  }
  fixture <- readRDS(fixture_path)
  if (
    !is.list(fixture) ||
      !is.matrix(fixture$system) ||
      !is.numeric(fixture$labour) ||
      nrow(fixture$system) != ncol(fixture$system) ||
      nrow(fixture$system) != length(fixture$labour)
  ) {
    stop("The benchmark fixture is invalid.", call. = FALSE)
  }
  gc()
  started <- proc.time()[["elapsed"]]
  solution <- switch(
    strategy,
    explicit_inverse_full = solve(fixture$system) %*% fixture$labour,
    direct_solve_full = solve(fixture$system, fixture$labour),
    direct_solve_productive = solve(fixture$system, fixture$labour),
    stop(sprintf("Unknown strategy `%s`.", strategy), call. = FALSE)
  )
  elapsed <- proc.time()[["elapsed"]] - started
  if (any(!is.finite(solution))) {
    stop("The child solve produced a non-finite result.", call. = FALSE)
  }
  cat(sprintf(
    "WLV_BENCHMARK\t%s\t%.17g\t%d\n",
    strategy,
    elapsed,
    length(solution)
  ))
  invisible(NULL)
}

arguments <- parse_arguments(commandArgs(trailingOnly = TRUE))
if (isTRUE(arguments$child)) {
  run_child(arguments$strategy, arguments$fixture)
  quit(save = "no", status = 0L)
}

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
if (length(script_argument) != 1L) {
  stop("Cannot locate the benchmark script.", call. = FALSE)
}
script_path <- normalizePath(
  sub("^--file=", "", script_argument),
  winslash = "/",
  mustWork = TRUE
)
project_root <- normalizePath(
  file.path(dirname(script_path), ".."),
  winslash = "/",
  mustWork = TRUE
)
Sys.setenv(RENV_PROJECT = project_root)
source(file.path(project_root, "renv", "activate.R"), local = TRUE)
campaign_root <- Sys.getenv("WLV_CAMPAIGN_ROOT", "")
if (!nzchar(campaign_root) || !dir.exists(campaign_root)) {
  stop("Launch benchmarks with scripts/run-experiment.ps1 (or scripts/run-experiment.sh on Linux) inside temp/<id>/.", call. = FALSE)
}
campaign_root <- normalizePath(campaign_root, winslash = "/", mustWork = TRUE)
campaign_parent <- normalizePath(file.path(project_root, "temp"), winslash = "/", mustWork = TRUE)
if (!identical(tolower(dirname(campaign_root)), tolower(campaign_parent)) ||
    basename(campaign_root) == "054") {
  stop("Benchmark campaign must be a new campaign inside this repository's temp/.", call. = FALSE)
}
manifest_path <- file.path(campaign_root, ".campaign.json")
if (!file.exists(manifest_path)) {
  stop("Benchmark campaign is not registered.", call. = FALSE)
}
campaign_record <- jsonlite::fromJSON(manifest_path)
if (!identical(campaign_record$schema, "wlv-campaign/1") ||
    !identical(campaign_record$id, basename(campaign_root)) ||
    !identical(campaign_record$status, "active")) {
  stop("Benchmark requires an active campaign.", call. = FALSE)
}
session_temporary <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
if (!startsWith(tolower(session_temporary), paste0(tolower(campaign_root), "/"))) {
  stop("Set TEMP, TMP and TMPDIR to the campaign scratch/ before starting R.", call. = FALSE)
}
# Resolve and validate the destination before loading data or starting a benchmark.
benchmark_output <- arguments$output
if (!grepl("^([A-Za-z]:[/\\\\]|/)", benchmark_output)) {
  benchmark_output <- file.path(project_root, benchmark_output)
}
output_parts <- strsplit(chartr("\\", "/", benchmark_output), "/", fixed = TRUE)[[1L]]
if (any(output_parts %in% c(".", ".."))) {
  stop("Benchmark output cannot contain dot path components.", call. = FALSE)
}
if (!startsWith(tolower(chartr("\\", "/", benchmark_output)),
                paste0(tolower(campaign_root), "/"))) {
  stop("Benchmark output must stay inside its campaign.", call. = FALSE)
}
ancestor <- benchmark_output
while (!dir.exists(ancestor)) ancestor <- dirname(ancestor)
resolved_ancestor <- normalizePath(ancestor, winslash = "/", mustWork = TRUE)
if (!identical(tolower(resolved_ancestor), tolower(campaign_root)) &&
    !startsWith(tolower(resolved_ancestor), paste0(tolower(campaign_root), "/"))) {
  stop("Benchmark output must stay inside its campaign.", call. = FALSE)
}
arguments$output <- benchmark_output
bootstrap_environment <- new.env(parent = baseenv())
sys.source(
  file.path(project_root, "scripts", "runtime_bootstrap.R"),
  envir = bootstrap_environment,
  chdir = FALSE
)
publication_environment <- bootstrap_environment$wlv_load_runtime(project_root)

if (!requireNamespace("fst", quietly = TRUE)) {
  stop("Package `fst` is required for the benchmark fixture.", call. = FALSE)
}
if (!requireNamespace("processx", quietly = TRUE)) {
  stop("Package `processx` is required for isolated peak-RSS measurement.", call. = FALSE)
}

method <- as.character(arguments$method)
year <- as.character(arguments$year)
if (!method %in% c("wiodr13", "wiodr16", "wiodr16v09", "zerodep_2")) {
  stop(
    "`--method` must be wiodr13, wiodr16, wiodr16v09, or zerodep_2.",
    call. = FALSE
  )
}
source_method <- if (method %in% c("wiodr16", "wiodr16v09", "zerodep_2")) {
  "wiodr16"
} else {
  "wiodr13"
}

source_path <- file.path(
  project_root,
  "source_data",
  source_method,
  "m_io.fst"
)
result_dir <- publication_environment$wlv_current_result_dir(
  method = method,
  root = project_root,
  channel = arguments$channel
)
sector_path <- file.path(result_dir, "sea_sectors.fst")
sector_contract_path <- file.path(result_dir, "_sectors.csv")
result_candidates <- list.files(
  result_dir,
  pattern = "^m_io.*[.]fst$",
  full.names = TRUE
)
if (
  !file.exists(source_path) ||
    !file.exists(paste0(source_path, ".meta")) ||
    !file.exists(sector_path) ||
    !file.exists(paste0(sector_path, ".meta")) ||
    !file.exists(sector_contract_path) ||
    length(result_candidates) != 1L ||
    !file.exists(paste0(result_candidates, ".meta"))
) {
  stop(
    paste0(
      "The benchmark needs one complete published result generation and its ",
      "prepared source. Run the method before benchmarking."
    ),
    call. = FALSE
  )
}
result_path <- result_candidates[[1L]]

read_metadata <- function(path, rank) {
  metadata <- readRDS(paste0(path, ".meta"))
  if (
    !is.list(metadata) ||
      length(metadata) != rank + 1L ||
      length(metadata$dim) != rank ||
      any(metadata$dim < 1L) ||
      !all(vapply(
        seq_len(rank),
        function(axis) length(metadata[[axis + 1L]]) == metadata$dim[[axis]],
        logical(1L)
      ))
  ) {
    stop(sprintf("Invalid FST array metadata for `%s`.", path), call. = FALSE)
  }
  metadata
}

read_array <- function(path, rank) {
  metadata <- read_metadata(path, rank)
  values <- fst::read_fst(path)[[1L]]
  if (length(values) != prod(metadata$dim)) {
    stop(sprintf("FST payload length differs for `%s`.", path), call. = FALSE)
  }
  array(
    values,
    dim = metadata$dim,
    dimnames = metadata[seq_len(rank) + 1L]
  )
}

# Read one year of a rank-three [year, input, output] array without loading all
# annual matrices. Output columns are processed in contiguous FST row chunks.
read_rank3_year <- function(path, metadata, year_index, columns, chunk = 16L) {
  periods <- metadata$dim[[1L]]
  inputs <- metadata$dim[[2L]]
  outputs <- metadata$dim[[3L]]
  if (any(columns < 1L | columns > outputs)) {
    stop("Requested source output is outside the array.", call. = FALSE)
  }
  result <- matrix(NA_real_, nrow = inputs, ncol = length(columns))
  groups <- split(columns, ceiling(seq_along(columns) / chunk))
  offset <- 0L
  for (group in groups) {
    if (!identical(group, seq.int(min(group), max(group)))) {
      stop("Rank-three output columns must be contiguous.", call. = FALSE)
    }
    from <- 1L + periods * inputs * (min(group) - 1L)
    to <- periods * inputs * max(group)
    payload <- fst::read_fst(path, from = from, to = to)[[1L]]
    block <- array(payload, dim = c(periods, inputs, length(group)))
    selected <- block[year_index, , , drop = FALSE]
    dim(selected) <- c(inputs, length(group))
    positions <- seq.int(offset + 1L, offset + length(group))
    result[, positions] <- selected
    offset <- offset + length(group)
  }
  result
}

# Equivalent slice reader for [year, indicator, input, output] result arrays.
read_rank4_year_indicator <- function(
    path,
    metadata,
    year_index,
    indicator_index,
    columns,
    chunk = 8L) {
  periods <- metadata$dim[[1L]]
  indicators <- metadata$dim[[2L]]
  inputs <- metadata$dim[[3L]]
  outputs <- metadata$dim[[4L]]
  if (any(columns < 1L | columns > outputs)) {
    stop("Requested result output is outside the array.", call. = FALSE)
  }
  result <- matrix(NA_real_, nrow = inputs, ncol = length(columns))
  groups <- split(columns, ceiling(seq_along(columns) / chunk))
  offset <- 0L
  for (group in groups) {
    if (!identical(group, seq.int(min(group), max(group)))) {
      stop("Rank-four output columns must be contiguous.", call. = FALSE)
    }
    from <- 1L + periods * indicators * inputs * (min(group) - 1L)
    to <- periods * indicators * inputs * max(group)
    payload <- fst::read_fst(path, from = from, to = to)[[1L]]
    block <- array(
      payload,
      dim = c(periods, indicators, inputs, length(group))
    )
    selected <- block[year_index, indicator_index, , , drop = FALSE]
    dim(selected) <- c(inputs, length(group))
    positions <- seq.int(offset + 1L, offset + length(group))
    result[, positions] <- selected
    offset <- offset + length(group)
  }
  result
}

source_metadata <- read_metadata(source_path, 3L)
result_metadata <- read_metadata(result_path, 4L)
sector_metadata <- read_metadata(sector_path, 4L)
source_years <- as.character(source_metadata[[2L]])
result_years <- as.character(result_metadata[[2L]])
sector_years <- as.character(sector_metadata[[2L]])
if (!year %in% Reduce(intersect, list(source_years, result_years, sector_years))) {
  stop(sprintf("Year `%s` is not common to the fixture artifacts.", year), call. = FALSE)
}
source_year_index <- match(year, source_years)
result_year_index <- match(year, result_years)
sector_year_index <- match(year, sector_years)

source_inputs <- as.character(source_metadata[[3L]])
source_outputs <- as.character(source_metadata[[4L]])
result_indicators <- as.character(result_metadata[[3L]])
result_inputs <- as.character(result_metadata[[4L]])
result_outputs <- as.character(result_metadata[[5L]])
if (
  !identical(source_inputs, result_inputs) ||
    !identical(source_outputs, result_outputs) ||
    !identical(source_outputs[seq_along(source_inputs)], source_inputs) ||
    !"k_depreciation" %in% result_indicators
) {
  stop("Source and published result matrix axes do not agree.", call. = FALSE)
}

sector_contract <- utils::read.csv2(
  sector_contract_path,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
if (
  !all(c("sector.source", "productive") %in% names(sector_contract)) ||
    anyNA(sector_contract[c("sector.source", "productive")]) ||
    any(!sector_contract$productive %in% c(0, 1))
) {
  stop("The published sector contract is invalid.", call. = FALSE)
}

sector_results <- read_array(sector_path, 4L)
sector_names <- dimnames(sector_results)[[3L]]
country_names <- dimnames(sector_results)[[4L]]
if (!identical(as.character(sector_contract$sector.source), sector_names)) {
  stop("The published productive-sector order differs from the result.", call. = FALSE)
}
expected_inputs <- paste(
  rep(country_names, each = length(sector_names)),
  rep(sector_names, times = length(country_names)),
  sep = "."
)
if (!identical(expected_inputs, source_inputs)) {
  stop("The country-sector product differs from the matrix input axis.", call. = FALSE)
}

required_sector_indicators <- c(
  "gross_output.s.us",
  "abstract_labour.emp.s.mv",
  "gross_output.s.mv"
)
missing_indicators <- setdiff(
  required_sector_indicators,
  dimnames(sector_results)[[2L]]
)
if (length(missing_indicators)) {
  stop(
    sprintf(
      "Published sector result lacks: %s.",
      paste(missing_indicators, collapse = ", ")
    ),
    call. = FALSE
  )
}

productive <- rep(
  as.logical(sector_contract$productive),
  times = length(country_names)
)
productive_indices <- which(productive)
dimension_full <- length(source_inputs)
dimension_productive <- length(productive_indices)
gross_output <- as.vector(
  sector_results[sector_year_index, "gross_output.s.us", , ]
)
labour_numerator <- as.vector(
  sector_results[sector_year_index, "abstract_labour.emp.s.mv", , ]
) * productive
published_value_output <- as.vector(
  sector_results[sector_year_index, "gross_output.s.mv", , ]
)
rm(sector_results)
gc()

message("Reading the annual source and depreciation matrices in chunks...")
source_block <- read_rank3_year(
  source_path,
  source_metadata,
  source_year_index,
  seq_len(dimension_full)
) * 1000000
depreciation_block <- read_rank4_year_indicator(
  result_path,
  result_metadata,
  result_year_index,
  match("k_depreciation", result_indicators),
  seq_len(dimension_full)
)
numerator <- source_block + depreciation_block
numerator[!productive, ] <- 0
numerator[, !productive] <- 0
zero_output <- gross_output == 0
invalid_ratio <- rep(zero_output, each = dimension_full) & numerator != 0
if (any(invalid_ratio)) {
  anomaly_path <- file.path(result_dir, "_anomalies.csv")
  if (!identical(method, "wiodr13") || !file.exists(anomaly_path)) {
    stop(
      paste0(
        "The selected real fixture contains nonzero Leontief input over zero ",
        "output without a published allowlist."
      ),
      call. = FALSE
    )
  }
  anomalies <- utils::read.csv2(
    anomaly_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  required_anomaly_columns <- c(
    "artifact", "indicator", "year", "sector", "output", "policy_id", "action"
  )
  if (!all(required_anomaly_columns %in% names(anomalies))) {
    stop("The published anomaly ledger cannot authorize the fixture.", call. = FALSE)
  }
  allowed <- anomalies[
    anomalies$artifact == "m_io" &
      anomalies$indicator == "leontief_input_ratio" &
      as.character(anomalies$year) == year &
      anomalies$policy_id == "wiodr13_leontief_zero_output_v1" &
      anomalies$action == "allowlisted_nonzero_over_zero",
    ,
    drop = FALSE
  ]
  positions <- which(invalid_ratio, arr.ind = TRUE)
  observed_keys <- sort(
    unique(paste(
      source_inputs[positions[, 1L]],
      source_inputs[positions[, 2L]],
      sep = "|"
    )),
    method = "radix"
  )
  allowed_keys <- sort(
    unique(paste(allowed$sector, allowed$output, sep = "|")),
    method = "radix"
  )
  if (!identical(observed_keys, allowed_keys)) {
    stop(
      "The fixture zero-output coordinates differ from the published allowlist.",
      call. = FALSE
    )
  }
  numerator[invalid_ratio] <- 0
  rm(anomalies, allowed, positions, observed_keys, allowed_keys)
}
coefficient_full <- sweep(numerator, 2L, gross_output, "/")
coefficient_full[, zero_output] <- 0
if (any(!is.finite(coefficient_full))) {
  stop("The reconstructed coefficient matrix is non-finite.", call. = FALSE)
}

invalid_labour <- gross_output == 0 & labour_numerator != 0
if (any(invalid_labour)) {
  stop("The selected fixture has nonzero labour over zero output.", call. = FALSE)
}
labour_full <- labour_numerator / gross_output
labour_full[gross_output == 0 & labour_numerator == 0] <- 0
if (any(!is.finite(labour_full))) {
  stop("The reconstructed direct-labour vector is non-finite.", call. = FALSE)
}

system_full <- t(diag(dimension_full) - coefficient_full)
system_productive <- system_full[productive_indices, productive_indices]
labour_productive <- labour_full[productive_indices]

fixture_dir <- tempfile("wlv-leontief-benchmark-")
dir.create(fixture_dir, recursive = FALSE)
fixture_dir_normalized <- normalizePath(fixture_dir, winslash = "/", mustWork = TRUE)
temporary_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
if (!startsWith(fixture_dir_normalized, paste0(temporary_root, "/"))) {
  stop("Refusing to use a benchmark fixture outside the session tempdir.", call. = FALSE)
}
on.exit(unlink(fixture_dir_normalized, recursive = TRUE, force = TRUE), add = TRUE)
full_fixture_path <- file.path(fixture_dir_normalized, "full.rds")
productive_fixture_path <- file.path(fixture_dir_normalized, "productive.rds")
saveRDS(
  list(system = system_full, labour = labour_full),
  full_fixture_path,
  compress = FALSE
)
saveRDS(
  list(system = system_productive, labour = labour_productive),
  productive_fixture_path,
  compress = FALSE
)

rm(source_block, depreciation_block, numerator)
gc()

rscript <- file.path(R.home("bin"), "Rscript")
child_environment <- Sys.getenv()
child_environment[c(
  "OMP_NUM_THREADS",
  "OPENBLAS_NUM_THREADS",
  "MKL_NUM_THREADS",
  "VECLIB_MAXIMUM_THREADS"
)] <- "1"

memory_sample <- function(process) {
  information <- tryCatch(
    process$get_memory_info(),
    error = function(error) NULL
  )
  if (is.null(information) || !length(information)) {
    return(NA_real_)
  }
  candidates <- if (.Platform$OS.type == "windows") {
    intersect(c("peak_wset", "wset", "rss"), names(information))
  } else {
    intersect(c("rss", "peak_rss", "wset"), names(information))
  }
  if (!length(candidates)) {
    return(NA_real_)
  }
  max(as.numeric(unlist(information[candidates])), na.rm = TRUE)
}

run_isolated <- function(strategy, fixture_path, repetition, poll_ms) {
  process <- processx::process$new(
    command = rscript,
    args = c(
      "--vanilla",
      script_path,
      "--child",
      "--strategy", strategy,
      "--fixture", fixture_path
    ),
    stdout = "|",
    stderr = "|",
    env = child_environment,
    cleanup = TRUE
  )
  peak_rss <- 0
  while (process$is_alive()) {
    sample <- memory_sample(process)
    if (is.finite(sample)) {
      peak_rss <- max(peak_rss, sample)
    }
    Sys.sleep(poll_ms / 1000)
  }
  sample <- memory_sample(process)
  if (is.finite(sample)) {
    peak_rss <- max(peak_rss, sample)
  }
  status <- process$get_exit_status()
  output <- process$read_all_output_lines()
  errors <- process$read_all_error_lines()
  marker <- grep("^WLV_BENCHMARK\\t", output, value = TRUE)
  if (!identical(status, 0L) || length(marker) != 1L || peak_rss <= 0) {
    stop(
      sprintf(
        "Child %s/%d failed (status %s). stdout: %s; stderr: %s",
        strategy,
        repetition,
        status,
        paste(output, collapse = " | "),
        paste(errors, collapse = " | ")
      ),
      call. = FALSE
    )
  }
  fields <- strsplit(marker, "\t", fixed = TRUE)[[1L]]
  data.frame(
    strategy = strategy,
    repetition = repetition,
    system_dimension = as.integer(fields[[4L]]),
    elapsed_seconds = as.numeric(fields[[3L]]),
    peak_rss_bytes = peak_rss,
    stringsAsFactors = FALSE
  )
}

strategies <- data.frame(
  strategy = c(
    "explicit_inverse_full",
    "direct_solve_full",
    "direct_solve_productive"
  ),
  fixture = c(
    full_fixture_path,
    full_fixture_path,
    productive_fixture_path
  ),
  stringsAsFactors = FALSE
)

message(sprintf(
  "Running %d fresh process(es) for each of three strategies...",
  arguments$repetitions
))
rows <- vector("list", nrow(strategies) * arguments$repetitions)
row_index <- 0L
for (repetition in seq_len(arguments$repetitions)) {
  for (strategy_index in seq_len(nrow(strategies))) {
    row_index <- row_index + 1L
    rows[[row_index]] <- run_isolated(
      strategies$strategy[[strategy_index]],
      strategies$fixture[[strategy_index]],
      repetition,
      arguments$poll_ms
    )
    message(sprintf(
      "  %s repetition %d: %.3f s, %.2f MiB",
      rows[[row_index]]$strategy,
      repetition,
      rows[[row_index]]$elapsed_seconds,
      rows[[row_index]]$peak_rss_bytes / 1024^2
    ))
  }
}
raw <- do.call(rbind, rows)
raw$strategy <- factor(raw$strategy, levels = strategies$strategy)
raw <- raw[order(raw$strategy, raw$repetition), ]
raw$strategy <- as.character(raw$strategy)
row.names(raw) <- NULL

summary_rows <- lapply(strategies$strategy, function(strategy) {
  current <- raw[raw$strategy == strategy, , drop = FALSE]
  data.frame(
    strategy = strategy,
    system_dimension = unique(current$system_dimension),
    repetitions = nrow(current),
    elapsed_median_seconds = median(current$elapsed_seconds),
    elapsed_min_seconds = min(current$elapsed_seconds),
    elapsed_max_seconds = max(current$elapsed_seconds),
    peak_rss_median_bytes = median(current$peak_rss_bytes),
    peak_rss_min_bytes = min(current$peak_rss_bytes),
    peak_rss_max_bytes = max(current$peak_rss_bytes),
    stringsAsFactors = FALSE
  )
})
summary <- do.call(rbind, summary_rows)
row.names(summary) <- NULL
baseline_time <- summary$elapsed_median_seconds[
  summary$strategy == "explicit_inverse_full"
]
baseline_memory <- summary$peak_rss_median_bytes[
  summary$strategy == "explicit_inverse_full"
]
summary$speedup_vs_inverse <- baseline_time / summary$elapsed_median_seconds
summary$rss_reduction_vs_inverse <-
  1 - summary$peak_rss_median_bytes / baseline_memory

message("Computing untimed numerical comparisons...")
inverse_matrix <- solve(system_full)
lambda_inverse <- as.vector(inverse_matrix %*% labour_full)
rm(inverse_matrix)
gc()
lambda_direct_full <- as.vector(solve(system_full, labour_full))
lambda_direct_productive <- numeric(dimension_full)
lambda_direct_productive[productive_indices] <- as.vector(
  solve(system_productive, labour_productive)
)
published_lambda <- published_value_output / gross_output
published_lambda[gross_output == 0 & published_value_output == 0] <- 0
if (any(!is.finite(published_lambda))) {
  stop("Published result cannot be converted back to finite lambda.", call. = FALSE)
}

comparison_row <- function(name, observed, expected) {
  difference <- abs(observed - expected)
  scale <- pmax(abs(observed), abs(expected), .Machine$double.xmin)
  data.frame(
    comparison = name,
    observations = length(difference),
    maximum_absolute_difference = max(difference),
    maximum_relative_difference = max(difference / scale),
    stringsAsFactors = FALSE
  )
}
accuracy <- rbind(
  comparison_row(
    "explicit_inverse_full_vs_direct_solve_full",
    lambda_inverse,
    lambda_direct_full
  ),
  comparison_row(
    "direct_solve_full_vs_direct_solve_productive",
    lambda_direct_full,
    lambda_direct_productive
  ),
  comparison_row(
    "direct_solve_productive_vs_published_lambda",
    lambda_direct_productive,
    published_lambda
  )
)
row.names(accuracy) <- NULL

period_count <- length(source_years)
array_sizes <- data.frame(
  object = c(
    "annual_full_inverse_array",
    "annual_productive_inverse_array",
    "one_full_system",
    "one_productive_system"
  ),
  matrices = c(period_count, period_count, 1, 1),
  dimension = c(
    dimension_full,
    dimension_productive,
    dimension_full,
    dimension_productive
  ),
  theoretical_numeric_bytes = c(
    period_count * dimension_full^2 * 8,
    period_count * dimension_productive^2 * 8,
    dimension_full^2 * 8,
    dimension_productive^2 * 8
  ),
  stringsAsFactors = FALSE
)

fixture_manifest <- data.frame(
  field = c(
    "method",
    "source_method",
    "year",
    "source_matrix",
    "published_io_result",
    "published_sector_result",
    "source_matrix_bytes",
    "published_io_result_bytes",
    "published_sector_result_bytes",
    "full_dimension",
    "productive_dimension",
    "productive_sectors_per_country",
    "countries",
    "full_fixture_md5",
    "productive_fixture_md5",
    "R_version",
    "platform",
    "BLAS",
    "LAPACK",
    "rss_poll_milliseconds"
  ),
  value = c(
    method,
    source_method,
    year,
    normalizePath(source_path, winslash = "/", mustWork = TRUE),
    normalizePath(result_path, winslash = "/", mustWork = TRUE),
    normalizePath(sector_path, winslash = "/", mustWork = TRUE),
    file.info(source_path)$size,
    file.info(result_path)$size,
    file.info(sector_path)$size,
    dimension_full,
    dimension_productive,
    sum(sector_contract$productive),
    length(country_names),
    unname(tools::md5sum(full_fixture_path)),
    unname(tools::md5sum(productive_fixture_path)),
    R.version.string,
    R.version$platform,
    if (!is.null(sessionInfo()$BLAS) && nzchar(sessionInfo()$BLAS)) {
      sessionInfo()$BLAS
    } else {
      paste0("matrix products: ", sessionInfo()$matprod)
    },
    if (!is.null(sessionInfo()$LAPACK) && nzchar(sessionInfo()$LAPACK)) {
      sessionInfo()$LAPACK
    } else if (!is.null(sessionInfo()$LA_version)) {
      sessionInfo()$LA_version
    } else {
      ""
    },
    arguments$poll_ms
  ),
  stringsAsFactors = FALSE
)

output_path <- arguments$output
if (!grepl("^([A-Za-z]:[/\\\\]|/)", output_path)) {
  output_path <- file.path(project_root, output_path)
}
output_directory <- normalizePath(
  output_path,
  winslash = "/",
  mustWork = FALSE
)
dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
output_directory <- normalizePath(output_directory, winslash = "/", mustWork = TRUE)
utils::write.csv(raw, file.path(output_directory, "raw.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(output_directory, "summary.csv"), row.names = FALSE)
utils::write.csv(accuracy, file.path(output_directory, "accuracy.csv"), row.names = FALSE)
utils::write.csv(
  array_sizes,
  file.path(output_directory, "array-sizes.csv"),
  row.names = FALSE
)
utils::write.csv(
  fixture_manifest,
  file.path(output_directory, "fixture.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
writeLines(
  capture.output(sessionInfo()),
  file.path(output_directory, "session-info.txt"),
  useBytes = TRUE
)

message(sprintf("Benchmark artifacts written to %s", output_directory))
print(summary, row.names = FALSE)
print(accuracy, row.names = FALSE)
