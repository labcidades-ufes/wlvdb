wlv_leontief_diagnostic_columns <- function() {
  c(
    "method", "year", "system_orientation", "matrix_scope",
    "rcond_norm", "certificate_type", "lambda_fingerprint", "total_dimension",
    "productive_dimension", "refinement_count", "machine_epsilon",
    "gamma_n", "forward_error_budget", "rcond_min", "max_backward_error",
    "refinement_trigger", "rcond",
    "absolute_residual_max", "eta_normwise", "berr_componentwise",
    "sensitivity_estimate", "forward_error_bound", "coefficient_count",
    "coefficient_zero_count", "coefficient_negative_count",
    "coefficient_nonfinite_count", "coefficient_min", "coefficient_max",
    "gross_output_count",
    "gross_output_zero_count", "gross_output_nonfinite_count",
    "gross_output_min", "gross_output_max", "labour_zero_count",
    "labour_negative_count", "labour_nonfinite_count", "labour_min",
    "labour_max", "lambda_zero_count", "lambda_negative_count",
    "lambda_nonfinite_count", "lambda_min", "lambda_max",
    "certificate_rcond", "certificate_margin", "certificate_ratio_upper",
    "certificate_roundoff_bound_max"
  )
}

wlv_leontief_context <- function(method, year) {
  sprintf("method `%s`, year `%s`", method, year)
}

wlv_lambda_fingerprint <- function(lambda, labels = names(lambda)) {
  if (!is.numeric(lambda) || !length(lambda) || any(!is.finite(lambda))) {
    stop("A lambda fingerprint requires a nonempty finite numeric vector.", call. = FALSE)
  }
  if (is.null(labels)) {
    labels <- as.character(seq_along(lambda))
  }
  if (
    !is.character(labels) || length(labels) != length(lambda) ||
    anyNA(labels) || any(!nzchar(labels)) || anyDuplicated(labels) ||
    any(grepl("[\r\n\t]", labels))
  ) {
    stop("A lambda fingerprint requires unique, nonempty scalar labels.", call. = FALSE)
  }
  payload <- paste(
    enc2utf8(labels),
    sprintf("%.17g", as.numeric(lambda)),
    sep = "\t",
    collapse = "\n"
  )
  unclass(tolower(as.character(openssl::md5(
    charToRaw(enc2utf8(payload))
  ))))
}

wlv_leontief_policy <- function(dimension, policy = NULL) {
  if (
    !is.numeric(dimension) || length(dimension) != 1L ||
    is.na(dimension) || !is.finite(dimension) || dimension < 1 ||
    dimension != as.integer(dimension)
  ) {
    stop("The productive Leontief dimension must be a positive integer.", call. = FALSE)
  }
  dimension <- as.integer(dimension)
  epsilon <- .Machine$double.eps
  operations <- as.double(dimension)
  if (operations * epsilon >= 1) {
    stop("The Leontief dimension exceeds the floating-point error model.", call. = FALSE)
  }
  gamma_n <- operations * epsilon / (1 - operations * epsilon)
  defaults <- list(
    forward_error_budget = 1e-8,
    max_backward_error = 8 * gamma_n,
    refinement_trigger = 64 * epsilon,
    max_refinements = 2L
  )
  if (is.null(policy)) {
    policy <- list()
  }
  if (!is.list(policy) || (length(policy) && is.null(names(policy)))) {
    stop("The Leontief numerical policy must be a named list.", call. = FALSE)
  }
  unknown <- setdiff(names(policy), c(names(defaults), "rcond_min"))
  if (length(unknown)) {
    stop(
      sprintf(
        "Unknown Leontief numerical policy field(s): %s.",
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  values <- utils::modifyList(defaults, policy, keep.null = TRUE)
  if (
    !is.numeric(values$forward_error_budget) ||
    length(values$forward_error_budget) != 1L ||
    is.na(values$forward_error_budget) ||
    !is.finite(values$forward_error_budget) ||
    values$forward_error_budget <= 0
  ) {
    stop(
      "Invalid Leontief numerical policy field(s): forward_error_budget.",
      call. = FALSE
    )
  }
  if (!"rcond_min" %in% names(policy)) {
    values$rcond_min <- gamma_n / values$forward_error_budget
  }
  scalar_nonnegative <- c(
    "forward_error_budget", "rcond_min", "max_backward_error",
    "refinement_trigger"
  )
  invalid_scalar <- vapply(scalar_nonnegative, function(name) {
    value <- values[[name]]
    !is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value <= 0
  }, logical(1L))
  if (any(invalid_scalar)) {
    stop(
      sprintf(
        "Invalid Leontief numerical policy field(s): %s.",
        paste(scalar_nonnegative[invalid_scalar], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (
    values$forward_error_budget > 1 || values$rcond_min > 1 ||
    values$max_backward_error > 1 || values$refinement_trigger > 1
  ) {
    stop("Leontief numerical policy thresholds cannot exceed one.", call. = FALSE)
  }
  if (
    !is.numeric(values$max_refinements) || length(values$max_refinements) != 1L ||
    is.na(values$max_refinements) || !is.finite(values$max_refinements) ||
    values$max_refinements < 0 ||
    values$max_refinements != as.integer(values$max_refinements)
  ) {
    stop("Leontief max_refinements must be a nonnegative integer.", call. = FALSE)
  }
  values$max_refinements <- as.integer(values$max_refinements)
  values$machine_epsilon <- epsilon
  values$gamma_n <- gamma_n
  values
}

wlv_leontief_diagnose_solution <- function(
    system_matrix,
    solution,
    right_hand_side,
    rcond_value = NULL) {
  if (
    !is.matrix(system_matrix) || !is.numeric(system_matrix) ||
    nrow(system_matrix) != ncol(system_matrix) || !nrow(system_matrix) ||
    any(!is.finite(system_matrix)) ||
    !is.numeric(solution) || !is.numeric(right_hand_side) ||
    length(solution) != nrow(system_matrix) ||
    length(right_hand_side) != nrow(system_matrix) ||
    any(!is.finite(solution)) || any(!is.finite(right_hand_side))
  ) {
    stop("Invalid Leontief system, solution, or right-hand side.", call. = FALSE)
  }
  if (is.null(rcond_value)) {
    rcond_value <- tryCatch(
      base::rcond(system_matrix, norm = "I"),
      error = function(error) NA_real_
    )
  }
  if (
    !is.numeric(rcond_value) || length(rcond_value) != 1L ||
    is.na(rcond_value) || !is.finite(rcond_value) || rcond_value < 0
  ) {
    stop("Invalid reciprocal condition estimate for the Leontief system.", call. = FALSE)
  }

  residual <- as.vector(system_matrix %*% solution - right_hand_side)
  absolute_residual_max <- max(abs(residual))
  matrix_norm_inf <- max(rowSums(abs(system_matrix)))
  solution_norm_inf <- max(abs(solution))
  rhs_norm_inf <- max(abs(right_hand_side))
  normwise_denominator <-
    matrix_norm_inf * solution_norm_inf + rhs_norm_inf
  eta_normwise <- if (normwise_denominator == 0) {
    if (absolute_residual_max == 0) 0 else Inf
  } else {
    absolute_residual_max / normwise_denominator
  }

  componentwise_denominator <- as.vector(
    abs(system_matrix) %*% abs(solution) + abs(right_hand_side)
  )
  componentwise_ratio <- numeric(length(residual))
  positive_denominator <- componentwise_denominator > 0
  componentwise_ratio[positive_denominator] <-
    abs(residual[positive_denominator]) /
    componentwise_denominator[positive_denominator]
  componentwise_ratio[!positive_denominator & residual != 0] <- Inf
  berr_componentwise <- max(componentwise_ratio)
  sensitivity_estimate <- if (rcond_value == 0) {
    if (eta_normwise == 0) 0 else Inf
  } else {
    eta_normwise / rcond_value
  }

  list(
    residual = residual,
    absolute_residual_max = absolute_residual_max,
    eta_normwise = eta_normwise,
    berr_componentwise = berr_componentwise,
    sensitivity_estimate = sensitivity_estimate
  )
}

wlv_leontief_dense_matrix <- function(value) {
  dense <- Matrix::Matrix(value, sparse = FALSE)
  methods::as(methods::as(dense, "generalMatrix"), "unpackedMatrix")
}

wlv_leontief_factor <- function(system_matrix) {
  tryCatch(
    suppressWarnings(Matrix::lu(wlv_leontief_dense_matrix(system_matrix))),
    error = function(error) NULL
  )
}

wlv_leontief_factor_solve <- function(factorization, right_hand_side) {
  vector_result <- is.null(dim(right_hand_side))
  if (vector_result) {
    right_hand_side <- matrix(right_hand_side, ncol = 1L)
  } else {
    right_hand_side <- as.matrix(right_hand_side)
  }
  dense_right_hand_side <- wlv_leontief_dense_matrix(right_hand_side)
  solve_method <- methods::selectMethod(
    "solve",
    c("denseLU", "dgeMatrix")
  )
  result <- as.matrix(solve_method(factorization, dense_right_hand_side))
  if (vector_result) as.vector(result) else result
}

# Certifica que as rodadas sucessivas de insumos convergem: para A não negativa,
# isso corresponde ao critério de produtividade do sistema; havendo sinais,
# aplica-se a |A| para exigir convergência absoluta. O vetor positivo precisa
# dominar |A|' vezes ele mesmo, inclusive após a margem de arredondamento.
# É uma condição matemática de admissibilidade, não a classificação marxista
# dos setores produtivos, que já chegou ao solver como uma máscara distinta.
wlv_leontief_certificate <- function(
    coefficients,
    policy,
    context,
    factorization = NULL,
    certificate_vector = NULL,
    certificate_rcond = NULL) {
  dimension <- nrow(coefficients)
  absolute_coefficients <- abs(coefficients)
  certificate_system <-
    t(diag(1, nrow = dimension, ncol = dimension) - absolute_coefficients)
  if (is.null(certificate_rcond)) {
    certificate_rcond <- tryCatch(
      base::rcond(certificate_system, norm = "I"),
      error = function(error) NA_real_
    )
  }
  if (is.null(certificate_vector)) {
    if (is.null(factorization)) {
      factorization <- wlv_leontief_factor(certificate_system)
    }
    certificate_vector <- if (is.null(factorization)) {
      NULL
    } else {
      tryCatch(
        wlv_leontief_factor_solve(factorization, rep(1, dimension)),
        error = function(error) NULL
      )
    }
  }
  certificate_type <- if (any(coefficients < 0)) {
    "absolute_convergence_signed"
  } else {
    "productivity_nonnegative"
  }
  failure_label <- if (identical(certificate_type, "productivity_nonnegative")) {
    "productive"
  } else {
    "absolutely convergent"
  }
  if (
    is.null(certificate_vector) ||
    !is.finite(certificate_rcond) || certificate_rcond <= 0 ||
    any(!is.finite(certificate_vector)) || any(certificate_vector <= 0)
  ) {
    stop(
      sprintf(
        "Leontief system for %s is not certified as %s.",
        context,
        failure_label
      ),
      call. = FALSE
    )
  }

  transformed <- as.vector(crossprod(
    absolute_coefficients,
    certificate_vector
  ))
  slack <- certificate_vector - transformed
  operations <- as.double(dimension + 2L)
  gamma_certificate <-
    operations * policy$machine_epsilon /
    (1 - operations * policy$machine_epsilon)
  roundoff_bound <- gamma_certificate * (
    abs(certificate_vector) +
      as.vector(crossprod(absolute_coefficients, abs(certificate_vector)))
  )
  guarded_slack <- slack - roundoff_bound
  ratio_upper <- (transformed + roundoff_bound) / certificate_vector
  certificate_margin <- min(guarded_slack)
  certificate_ratio_upper <- max(ratio_upper)
  if (
    any(!is.finite(guarded_slack)) ||
    any(!is.finite(ratio_upper)) ||
    certificate_margin <= 0 || certificate_ratio_upper >= 1
  ) {
    stop(
      sprintf(
        paste0(
          "Leontief system for %s is not certified as %s after the ",
          "floating-point roundoff guard."
        ),
        context,
        failure_label
      ),
      call. = FALSE
    )
  }

  list(
    type = certificate_type,
    rcond = certificate_rcond,
    margin = certificate_margin,
    ratio_upper = certificate_ratio_upper,
    roundoff_bound_max = max(roundoff_bound)
  )
}

# Resolve (I-A)' lambda = l: a transposição permite representar o vetor-linha
# econômico lambda = l + lambda A como vetor-coluna no solucionador R.
# A é fornecedor × usuário e l mede trabalho direto por unidade monetária;
# lambda devolve trabalho total incorporado na mesma unidade. Somente o bloco
# produtivo participa; setores excluídos voltam com zero por hipótese.
# Guias: docs/guide-pt.md e docs/guide-en.md; detalhes: docs/leontief-benchmark.md.
wlv_solve_leontief <- function(
    coefficient_matrix,
    labour_requirements,
    productive = rep(TRUE, length(labour_requirements)),
    gross_output = rep(1, length(labour_requirements)),
    method,
    year,
    policy = NULL) {
  if (
    !is.character(method) || length(method) != 1L || is.na(method) ||
    !nzchar(method) ||
    length(year) != 1L || is.na(year) || !nzchar(as.character(year))
  ) {
    stop("Leontief diagnostics require one nonempty method and year.", call. = FALSE)
  }
  year <- as.character(year)
  context <- wlv_leontief_context(method, year)
  total_dimension <- length(labour_requirements)
  if (
    !is.matrix(coefficient_matrix) || !is.numeric(coefficient_matrix) ||
    nrow(coefficient_matrix) != ncol(coefficient_matrix) ||
    !nrow(coefficient_matrix) ||
    !is.numeric(labour_requirements) || !length(labour_requirements) ||
    !is.logical(productive) || length(productive) != total_dimension ||
    anyNA(productive) || !any(productive) ||
    !is.numeric(gross_output) ||
    length(gross_output) != total_dimension
  ) {
    stop(sprintf("Invalid Leontief inputs for %s.", context), call. = FALSE)
  }
  productive_dimension <- sum(productive)
  coefficient_dimension <- nrow(coefficient_matrix)
  full_coefficient_matrix <- coefficient_dimension == total_dimension
  block_coefficient_matrix <- coefficient_dimension == productive_dimension
  if (!full_coefficient_matrix && !block_coefficient_matrix) {
    stop(
      sprintf(
        paste0(
          "Leontief coefficients for %s must be either the full %d x %d ",
          "matrix or the productive %d x %d block."
        ),
        context,
        total_dimension,
        total_dimension,
        productive_dimension,
        productive_dimension
      ),
      call. = FALSE
    )
  }
  coefficient_nonfinite_count <- sum(!is.finite(coefficient_matrix))
  labour_nonfinite_count <- sum(!is.finite(labour_requirements))
  gross_output_nonfinite_count <- sum(!is.finite(gross_output))
  if (
    coefficient_nonfinite_count || labour_nonfinite_count ||
    gross_output_nonfinite_count
  ) {
    stop(
      sprintf(
        paste0(
          "Non-finite Leontief inputs for %s: %d coefficient(s), ",
          "%d labour requirement(s), and %d gross output value(s)."
        ),
        context,
        coefficient_nonfinite_count,
        labour_nonfinite_count,
        gross_output_nonfinite_count
      ),
      call. = FALSE
    )
  }

  row_labels <- rownames(coefficient_matrix)
  column_labels <- colnames(coefficient_matrix)
  labour_labels <- names(labour_requirements)
  gross_output_labels <- names(gross_output)
  if (
    !is.null(labour_labels) && !is.null(gross_output_labels) &&
    !identical(labour_labels, gross_output_labels)
  ) {
    stop(
      sprintf("Leontief labour and gross-output labels differ for %s.", context),
      call. = FALSE
    )
  }
  full_labels <- if (!is.null(labour_labels)) {
    labour_labels
  } else {
    gross_output_labels
  }
  if (
    !is.null(row_labels) && !is.null(column_labels) &&
    !identical(row_labels, column_labels)
  ) {
    stop(
      sprintf("Leontief row and column labels differ for %s.", context),
      call. = FALSE
    )
  }
  coefficient_labels <- if (!is.null(column_labels)) column_labels else row_labels
  if (is.null(full_labels) && full_coefficient_matrix) {
    full_labels <- coefficient_labels
  }
  expected_coefficient_labels <- if (is.null(full_labels)) {
    NULL
  } else if (full_coefficient_matrix) {
    full_labels
  } else {
    full_labels[productive]
  }
  if (
    !is.null(coefficient_labels) && !is.null(expected_coefficient_labels) &&
    !identical(coefficient_labels, expected_coefficient_labels)
  ) {
    stop(
      sprintf("Leontief and labour labels differ for %s.", context),
      call. = FALSE
    )
  }

  inactive <- !productive
  if (any(labour_requirements[inactive] != 0)) {
    stop(
      sprintf(
        "Non-productive sectors are not zero-filtered for %s.",
        context
      ),
      call. = FALSE
    )
  }
  if (
    full_coefficient_matrix &&
    (any(coefficient_matrix[inactive, , drop = FALSE] != 0) ||
      any(coefficient_matrix[, inactive, drop = FALSE] != 0))
  ) {
    stop(
      sprintf(
        "Non-productive sectors are not zero-filtered for %s.",
        context
      ),
      call. = FALSE
    )
  }

  productive_coefficients <- if (full_coefficient_matrix) {
    coefficient_matrix[productive, productive, drop = FALSE]
  } else {
    coefficient_matrix
  }
  productive_labour <- labour_requirements[productive]
  dimension <- nrow(productive_coefficients)
  implicit_zero_count <-
    total_dimension^2 - productive_dimension^2
  coefficient_count <- total_dimension^2
  coefficient_zero_count <-
    implicit_zero_count + sum(productive_coefficients == 0)
  coefficient_negative_count <- sum(productive_coefficients < 0)
  coefficient_min <- if (implicit_zero_count) {
    min(0, productive_coefficients)
  } else {
    min(productive_coefficients)
  }
  coefficient_max <- if (implicit_zero_count) {
    max(0, productive_coefficients)
  } else {
    max(productive_coefficients)
  }
  numerical_policy <- wlv_leontief_policy(dimension, policy)
  system_matrix <-
    t(diag(1, nrow = dimension, ncol = dimension) - productive_coefficients)
  # rcond estima o inverso do condicionamento: próximo de zero significa que
  # pequenas perturbações dos dados podem causar grande mudança em lambda.
  # Não aceitar um sistema quase singular evita publicar precisão ilusória.
  reciprocal_condition <- tryCatch(
    base::rcond(system_matrix, norm = "I"),
    error = function(error) NA_real_
  )
  if (!is.finite(reciprocal_condition) || reciprocal_condition <= 0) {
    stop(
      sprintf(
        paste0(
          "Leontief system is singular for %s ",
          "(rcond of t(I - C), infinity norm, is zero or unavailable)."
        ),
        context
      ),
      call. = FALSE
    )
  }
  if (reciprocal_condition < numerical_policy$rcond_min) {
    stop(
      sprintf(
        paste0(
          "Leontief system is numerically near-singular for %s: ",
          "rcond(t(I - C), infinity norm) = %.17g is below %.17g."
        ),
        context,
        reciprocal_condition,
        numerical_policy$rcond_min
      ),
      call. = FALSE
    )
  }

  factorization <- wlv_leontief_factor(system_matrix)
  nonnegative_coefficients <- !any(productive_coefficients < 0)
  initial_right_hand_side <- if (nonnegative_coefficients) {
    cbind(productive_labour, certificate = rep(1, dimension))
  } else {
    productive_labour
  }
  initial_solution <- if (is.null(factorization)) {
    NULL
  } else {
    tryCatch(
      wlv_leontief_factor_solve(factorization, initial_right_hand_side),
      error = function(error) NULL
    )
  }
  productive_lambda <- if (is.null(initial_solution)) {
    NULL
  } else if (nonnegative_coefficients) {
    initial_solution[, 1L]
  } else {
    as.vector(initial_solution)
  }
  if (is.null(productive_lambda) || any(!is.finite(productive_lambda))) {
    stop(
      sprintf("Leontief solve failed for %s despite a finite rcond.", context),
      call. = FALSE
    )
  }
  solution_diagnostics <- wlv_leontief_diagnose_solution(
    system_matrix,
    productive_lambda,
    productive_labour,
    reciprocal_condition
  )
  # Refinamento corrige resíduos de arredondamento reutilizando a fatoração.
  # Os limites de erro regressivo/sensibilidade são conferidos mesmo quando o
  # sistema retornou números finitos; sucesso do solver não encerra a validação.
  refinement_count <- 0L
  backward_error <- max(
    solution_diagnostics$eta_normwise,
    solution_diagnostics$berr_componentwise
  )
  while (
    backward_error > numerical_policy$refinement_trigger &&
    refinement_count < numerical_policy$max_refinements
  ) {
    correction <- tryCatch(
      wlv_leontief_factor_solve(
        factorization,
        solution_diagnostics$residual
      ),
      error = function(error) NULL
    )
    if (is.null(correction) || any(!is.finite(correction))) {
      break
    }
    productive_lambda <- productive_lambda - correction
    refinement_count <- refinement_count + 1L
    solution_diagnostics <- wlv_leontief_diagnose_solution(
      system_matrix,
      productive_lambda,
      productive_labour,
      reciprocal_condition
    )
    backward_error <- max(
      solution_diagnostics$eta_normwise,
      solution_diagnostics$berr_componentwise
    )
  }
  forward_error_bound <- solution_diagnostics$sensitivity_estimate
  if (
    !is.finite(solution_diagnostics$absolute_residual_max) ||
    !is.finite(solution_diagnostics$eta_normwise) ||
    !is.finite(solution_diagnostics$berr_componentwise) ||
    !is.finite(forward_error_bound) ||
    backward_error > numerical_policy$max_backward_error ||
    forward_error_bound > numerical_policy$forward_error_budget
  ) {
    stop(
      sprintf(
        paste0(
          "Leontief solve failed the numerical error policy for %s: ",
          "max(eta, berr) = %.17g (limit %.17g), estimated forward error = %.17g ",
          "(budget %.17g)."
        ),
        context,
        backward_error,
        numerical_policy$max_backward_error,
        forward_error_bound,
        numerical_policy$forward_error_budget
      ),
      call. = FALSE
    )
  }

  certificate <- wlv_leontief_certificate(
    productive_coefficients,
    numerical_policy,
    context,
    factorization = if (nonnegative_coefficients) factorization else NULL,
    certificate_vector = if (nonnegative_coefficients) {
      initial_solution[, 2L]
    } else {
      NULL
    },
    certificate_rcond = if (nonnegative_coefficients) {
      reciprocal_condition
    } else {
      NULL
    }
  )
  lambda <- rep(0, length(labour_requirements))
  lambda[productive] <- productive_lambda
  labels <- full_labels
  if (!is.null(labels)) {
    names(lambda) <- labels
  }

  diagnostics <- data.frame(
    method = method,
    year = year,
    system_orientation =
      "t(I - C)[productive, productive] %*% lambda = direct_labour",
    matrix_scope = "productive_block",
    rcond_norm = "infinity",
    certificate_type = certificate$type,
    lambda_fingerprint = wlv_lambda_fingerprint(lambda, labels),
    total_dimension = total_dimension,
    productive_dimension = dimension,
    refinement_count = refinement_count,
    machine_epsilon = numerical_policy$machine_epsilon,
    gamma_n = numerical_policy$gamma_n,
    forward_error_budget = numerical_policy$forward_error_budget,
    rcond_min = numerical_policy$rcond_min,
    max_backward_error = numerical_policy$max_backward_error,
    refinement_trigger = numerical_policy$refinement_trigger,
    rcond = reciprocal_condition,
    absolute_residual_max = solution_diagnostics$absolute_residual_max,
    eta_normwise = solution_diagnostics$eta_normwise,
    berr_componentwise = solution_diagnostics$berr_componentwise,
    sensitivity_estimate = solution_diagnostics$sensitivity_estimate,
    forward_error_bound = forward_error_bound,
    coefficient_count = coefficient_count,
    coefficient_zero_count = coefficient_zero_count,
    coefficient_negative_count = coefficient_negative_count,
    coefficient_nonfinite_count = coefficient_nonfinite_count,
    coefficient_min = coefficient_min,
    coefficient_max = coefficient_max,
    gross_output_count = length(gross_output),
    gross_output_zero_count = sum(gross_output == 0),
    gross_output_nonfinite_count = gross_output_nonfinite_count,
    gross_output_min = min(gross_output),
    gross_output_max = max(gross_output),
    labour_zero_count = sum(labour_requirements == 0),
    labour_negative_count = sum(labour_requirements < 0),
    labour_nonfinite_count = labour_nonfinite_count,
    labour_min = min(labour_requirements),
    labour_max = max(labour_requirements),
    lambda_zero_count = sum(lambda == 0),
    lambda_negative_count = sum(lambda < 0),
    lambda_nonfinite_count = sum(!is.finite(lambda)),
    lambda_min = min(lambda),
    lambda_max = max(lambda),
    certificate_rcond = certificate$rcond,
    certificate_margin = certificate$margin,
    certificate_ratio_upper = certificate$ratio_upper,
    certificate_roundoff_bound_max = certificate$roundoff_bound_max,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  diagnostics <- diagnostics[wlv_leontief_diagnostic_columns()]

  list(lambda = lambda, diagnostics = diagnostics)
}

wlv_leontief_singularity_profile_columns <- function() {
  c(
    "method", "year", "system_orientation", "matrix_scope",
    "dimension", "qr_rank", "qr_tolerance", "nullity",
    "dependent_column_count", "dependent_column_fingerprint",
    "dependent_column_sample",
    "coefficient_null_row_count", "coefficient_null_column_count",
    "system_null_row_count", "system_null_column_count",
    "duplicate_coefficient_row_count", "duplicate_coefficient_column_count",
    "column_sum_min", "column_sum_max",
    "zero_value_added_candidate_count", "negative_value_added_candidate_count",
    "row_sum_max", "spectral_radius_estimate", "spectral_radius_bound",
    "spectral_radius_converged", "rcond", "rcond_min", "system_norm_inf",
    "min_norm_residual_max", "eta_normwise_min_norm", "compatible",
    "classification"
  )
}

# Mede o tamanho e a causa da singularidade antes de qualquer tentativa de
# recuperação (roadmap: docs/leontief-singularity-recovery.md). A singularidade
# de t(I - C) equivale a um autovalor exatamente 1 de C: tipicamente, um ciclo
# de setores cuja produção é inteiramente consumida como insumo intermediário
# (valor adicionado nulo na fonte). Linhas ou colunas nulas de C, sozinhas, não
# singularizam o sistema; continuam reportadas porque localizam lacunas de
# cobertura da fonte. Quando trabalho direto é informado, a compatibilidade
# distingue sistemas resolúveis por métodos sem alteração de dados (resíduo de
# mínimos quadrados nulo) de sistemas com informação conflitante na fonte.
wlv_leontief_singularity_profile <- function(
    coefficient_matrix,
    labour_requirements = NULL,
    method,
    year,
    policy = NULL) {
  if (
    !is.character(method) || length(method) != 1L || is.na(method) ||
    !nzchar(method) ||
    length(year) != 1L || is.na(year) || !nzchar(as.character(year))
  ) {
    stop(
      "Leontief singularity profiles require one nonempty method and year.",
      call. = FALSE
    )
  }
  year <- as.character(year)
  context <- wlv_leontief_context(method, year)
  if (
    !is.matrix(coefficient_matrix) || !is.numeric(coefficient_matrix) ||
    nrow(coefficient_matrix) != ncol(coefficient_matrix) ||
    !nrow(coefficient_matrix) ||
    any(!is.finite(coefficient_matrix))
  ) {
    stop(
      sprintf(
        "Invalid Leontief coefficients for the singularity profile of %s.",
        context
      ),
      call. = FALSE
    )
  }
  dimension <- nrow(coefficient_matrix)
  if (
    !is.null(labour_requirements) &&
    (!is.numeric(labour_requirements) ||
      length(labour_requirements) != dimension ||
      any(!is.finite(labour_requirements)))
  ) {
    stop(
      sprintf(
        "Invalid direct labour for the singularity profile of %s.",
        context
      ),
      call. = FALSE
    )
  }
  row_labels <- rownames(coefficient_matrix)
  column_labels <- colnames(coefficient_matrix)
  if (
    !is.null(row_labels) && !is.null(column_labels) &&
    !identical(row_labels, column_labels)
  ) {
    stop(
      sprintf("Leontief row and column labels differ for %s.", context),
      call. = FALSE
    )
  }
  sector_labels <- if (!is.null(column_labels)) {
    column_labels
  } else {
    row_labels
  }
  if (is.null(sector_labels)) {
    sector_labels <- as.character(seq_len(dimension))
  }
  labour_labels <- names(labour_requirements)
  if (
    !is.null(labour_labels) && !is.null(column_labels) &&
    !identical(labour_labels, column_labels)
  ) {
    stop(
      sprintf("Leontief and labour labels differ for %s.", context),
      call. = FALSE
    )
  }

  system_matrix <- t(diag(1, nrow = dimension, ncol = dimension) -
    coefficient_matrix)
  numerical_policy <- wlv_leontief_policy(dimension, policy)
  system_norm_inf <- max(rowSums(abs(system_matrix)))
  qr_tolerance <- numerical_policy$gamma_n * max(1, system_norm_inf)
  factorization <- base::qr(system_matrix, tol = qr_tolerance)
  qr_rank <- as.integer(factorization$rank)
  nullity <- dimension - qr_rank
  dependent_indices <- if (nullity > 0L) {
    sort(factorization$pivot[(qr_rank + 1L):dimension])
  } else {
    integer(0L)
  }
  dependent_labels <- sector_labels[dependent_indices]
  dependent_fingerprint <- unclass(tolower(as.character(openssl::md5(
    charToRaw(enc2utf8(paste(sort(dependent_labels), collapse = "\n")))
  ))))
  dependent_sample <- paste(utils::head(sort(dependent_labels), 20L),
    collapse = "|"
  )

  coefficient_null_row_count <- sum(rowSums(abs(coefficient_matrix)) == 0)
  coefficient_null_column_count <- sum(colSums(abs(coefficient_matrix)) == 0)
  system_null_row_count <- sum(rowSums(abs(system_matrix)) == 0)
  system_null_column_count <- sum(colSums(abs(system_matrix)) == 0)
  duplicate_coefficient_row_count <- sum(duplicated(coefficient_matrix))
  duplicate_coefficient_column_count <- sum(duplicated(t(coefficient_matrix)))
  column_sums <- colSums(coefficient_matrix)
  # As tabelas publicadas carregam no máximo oito dígitos significativos por
  # célula; somas de coluna a menos de 1e-8 de 1 indicam valor adicionado nulo
  # (produção inteiramente explicada por insumos intermediários).
  value_added_tolerance <- 1e-8
  zero_value_added_candidate_count <-
    sum(column_sums >= 1 - value_added_tolerance)
  negative_value_added_candidate_count <-
    sum(column_sums > 1 + value_added_tolerance)

  absolute_coefficients <- abs(coefficient_matrix)
  row_sum_max <- max(rowSums(absolute_coefficients))
  spectral_radius_bound <- row_sum_max
  spectral_radius_estimate <- if (row_sum_max == 0) 0 else NA_real_
  spectral_radius_converged <- row_sum_max == 0
  if (!spectral_radius_converged) {
    radius_state <- rep(1 / dimension, dimension)
    previous_estimate <- Inf
    for (iteration in seq_len(200L)) {
      projected <- as.vector(absolute_coefficients %*% radius_state)
      estimate <- max(projected)
      if (!is.finite(estimate)) {
        spectral_radius_estimate <- NA_real_
        break
      }
      if (estimate <= 0) {
        spectral_radius_estimate <- 0
        break
      }
      radius_state <- projected / estimate
      spectral_radius_estimate <- estimate
      if (abs(estimate - previous_estimate) <=
        4 * .Machine$double.eps * estimate) {
        spectral_radius_converged <- TRUE
        break
      }
      previous_estimate <- estimate
    }
  }

  reciprocal_condition <- tryCatch(
    base::rcond(system_matrix, norm = "I"),
    error = function(error) NA_real_
  )
  if (!is.numeric(reciprocal_condition) ||
    length(reciprocal_condition) != 1L ||
    is.na(reciprocal_condition)
  ) {
    reciprocal_condition <- NA_real_
  }

  min_norm_residual_max <- NA_real_
  eta_normwise_min_norm <- NA_real_
  compatible <- NA
  least_squares <- NULL
  if (!is.null(labour_requirements)) {
    beta <- tryCatch(
      base::qr.coef(factorization, labour_requirements),
      error = function(error) NULL
    )
    if (!is.null(beta)) {
      beta[is.na(beta)] <- 0
      residual <- as.vector(system_matrix %*% beta - labour_requirements)
      min_norm_residual_max <- max(abs(residual))
      denominator <-
        system_norm_inf * max(abs(beta)) + max(abs(labour_requirements))
      eta_normwise_min_norm <- if (denominator == 0) {
        if (min_norm_residual_max == 0) 0 else Inf
      } else {
        min_norm_residual_max / denominator
      }
      compatible <- is.finite(eta_normwise_min_norm) &&
        eta_normwise_min_norm <= numerical_policy$max_backward_error
      least_squares <- list(
        solution = beta,
        residual = residual,
        eta_normwise = eta_normwise_min_norm,
        compatible = compatible
      )
    }
  }

  classification <- if (nullity > 0L) {
    structural <- zero_value_added_candidate_count > 0 ||
      negative_value_added_candidate_count > 0 ||
      coefficient_null_row_count > 0 || coefficient_null_column_count > 0 ||
      system_null_row_count > 0 || system_null_column_count > 0 ||
      duplicate_coefficient_row_count > 0 ||
      duplicate_coefficient_column_count > 0
    if (structural) "singular_null_structure" else "singular_collinear"
  } else if (
    !is.finite(reciprocal_condition) || reciprocal_condition <= 0
  ) {
    "singular_collinear"
  } else if (reciprocal_condition < numerical_policy$rcond_min) {
    "ill_conditioned"
  } else {
    "invertible"
  }

  profile <- data.frame(
    method = method,
    year = year,
    system_orientation = "t(I - C)",
    matrix_scope = "coefficient_block",
    dimension = dimension,
    qr_rank = qr_rank,
    qr_tolerance = qr_tolerance,
    nullity = nullity,
    dependent_column_count = length(dependent_indices),
    dependent_column_fingerprint = dependent_fingerprint,
    dependent_column_sample = dependent_sample,
    coefficient_null_row_count = coefficient_null_row_count,
    coefficient_null_column_count = coefficient_null_column_count,
    system_null_row_count = system_null_row_count,
    system_null_column_count = system_null_column_count,
    duplicate_coefficient_row_count = duplicate_coefficient_row_count,
    duplicate_coefficient_column_count = duplicate_coefficient_column_count,
    column_sum_min = min(column_sums),
    column_sum_max = max(column_sums),
    zero_value_added_candidate_count = zero_value_added_candidate_count,
    negative_value_added_candidate_count = negative_value_added_candidate_count,
    row_sum_max = row_sum_max,
    spectral_radius_estimate = spectral_radius_estimate,
    spectral_radius_bound = spectral_radius_bound,
    spectral_radius_converged = spectral_radius_converged,
    rcond = reciprocal_condition,
    rcond_min = numerical_policy$rcond_min,
    system_norm_inf = system_norm_inf,
    min_norm_residual_max = min_norm_residual_max,
    eta_normwise_min_norm = eta_normwise_min_norm,
    compatible = compatible,
    classification = classification,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  profile <- profile[wlv_leontief_singularity_profile_columns()]

  list(
    profile = profile,
    dependent_indices = dependent_indices,
    dependent_columns = dependent_labels,
    least_squares = least_squares
  )
}

wlv_validate_leontief_diagnostic_artifact <- function(
    diagnostics,
    method = NULL,
    expected_years = NULL) {
  columns <- wlv_leontief_diagnostic_columns()
  character_columns <- c(
    "method", "year", "system_orientation", "matrix_scope", "rcond_norm",
    "certificate_type", "lambda_fingerprint"
  )
  numeric_columns <- setdiff(columns, character_columns)
  count_columns <- c(
    "total_dimension", "productive_dimension", "refinement_count",
    "coefficient_count", "coefficient_zero_count",
    "coefficient_negative_count", "coefficient_nonfinite_count",
    "gross_output_count", "gross_output_zero_count",
    "gross_output_nonfinite_count", "labour_zero_count",
    "labour_negative_count", "labour_nonfinite_count", "lambda_zero_count",
    "lambda_negative_count", "lambda_nonfinite_count"
  )
  if (
    !is.data.frame(diagnostics) || !identical(names(diagnostics), columns) ||
    !nrow(diagnostics) || anyNA(diagnostics) ||
    any(!vapply(diagnostics[character_columns], is.character, logical(1L))) ||
    any(!vapply(diagnostics[numeric_columns], is.numeric, logical(1L))) ||
    any(!vapply(diagnostics, function(value) {
      is.atomic(value) && !is.list(value)
    }, logical(1L))) ||
    any(!is.finite(as.matrix(diagnostics[numeric_columns])))
  ) {
    stop("Published Leontief diagnostics have an invalid schema.", call. = FALSE)
  }
  count_matrix <- as.matrix(diagnostics[count_columns])
  if (
    any(count_matrix < 0) || any(count_matrix != floor(count_matrix)) ||
    any(diagnostics$productive_dimension < 1) ||
    any(diagnostics$productive_dimension > .Machine$integer.max) ||
    any(diagnostics$total_dimension < diagnostics$productive_dimension)
  ) {
    stop("Published Leontief diagnostics violate their numerical contract.", call. = FALSE)
  }
  relative_matches <- function(observed, expected) {
    abs(observed - expected) <=
      128 * .Machine$double.eps *
      pmax(abs(expected), .Machine$double.xmin)
  }
  relative_match <- function(observed, expected) {
    all(relative_matches(observed, expected))
  }
  canonical_policies <- lapply(
    diagnostics$productive_dimension,
    wlv_leontief_policy
  )
  policy_columns <- c(
    "machine_epsilon", "gamma_n", "forward_error_budget", "rcond_min",
    "max_backward_error", "refinement_trigger"
  )
  canonical_policy_values <- lapply(policy_columns, function(name) {
    vapply(
      canonical_policies,
      function(policy) as.double(policy[[name]]),
      numeric(1L)
    )
  })
  names(canonical_policy_values) <- policy_columns
  mismatched_policy_fields <- policy_columns[!vapply(
    policy_columns,
    function(name) {
      relative_match(diagnostics[[name]], canonical_policy_values[[name]])
    },
    logical(1L)
  )]
  canonical_max_refinements <- vapply(
    canonical_policies,
    function(policy) policy$max_refinements,
    integer(1L)
  )
  excessive_refinement <-
    diagnostics$refinement_count > canonical_max_refinements
  if (length(mismatched_policy_fields) || any(excessive_refinement)) {
    details <- character()
    if (length(mismatched_policy_fields)) {
      details <- c(
        details,
        sprintf(
          "noncanonical field(s): %s",
          paste(mismatched_policy_fields, collapse = ", ")
        )
      )
    }
    if (any(excessive_refinement)) {
      affected <- paste(
        diagnostics$method[excessive_refinement],
        diagnostics$year[excessive_refinement],
        sep = "/"
      )
      details <- c(
        details,
        sprintf(
          "refinement_count exceeds max_refinements for %s",
          paste(affected, collapse = ", ")
        )
      )
    }
    stop(
      sprintf(
        paste0(
          "Published Leontief diagnostics violate the canonical numerical ",
          "policy in their numerical contract (%s)."
        ),
        paste(details, collapse = "; ")
      ),
      call. = FALSE
    )
  }
  if (
    any(!nzchar(diagnostics$method)) || any(!nzchar(diagnostics$year)) ||
    any(!grepl("^[0-9a-f]{32}$", diagnostics$lambda_fingerprint)) ||
    any(diagnostics$system_orientation !=
      "t(I - C)[productive, productive] %*% lambda = direct_labour") ||
    any(diagnostics$matrix_scope != "productive_block") ||
    any(diagnostics$rcond_norm != "infinity") ||
    any(!diagnostics$certificate_type %in% c(
      "productivity_nonnegative", "absolute_convergence_signed"
    )) ||
    any(diagnostics$coefficient_count != diagnostics$total_dimension^2) ||
    any(diagnostics$gross_output_count != diagnostics$total_dimension) ||
    any(diagnostics$coefficient_zero_count +
      diagnostics$coefficient_negative_count >
      diagnostics$coefficient_count) ||
    any(diagnostics$gross_output_zero_count > diagnostics$gross_output_count) ||
    any(diagnostics$labour_zero_count > diagnostics$total_dimension) ||
    any(diagnostics$labour_negative_count > diagnostics$total_dimension) ||
    any(diagnostics$lambda_zero_count > diagnostics$total_dimension) ||
    any(diagnostics$lambda_negative_count > diagnostics$total_dimension) ||
    any(diagnostics$coefficient_nonfinite_count != 0) ||
    any(diagnostics$gross_output_nonfinite_count != 0) ||
    any(diagnostics$labour_nonfinite_count != 0) ||
    any(diagnostics$lambda_nonfinite_count != 0) ||
    any(diagnostics$rcond <= 0 | diagnostics$rcond > 1) ||
    any(diagnostics$certificate_rcond <= 0 |
      diagnostics$certificate_rcond > 1) ||
    any(diagnostics$rcond < diagnostics$rcond_min) ||
    any(diagnostics$forward_error_budget <= 0 |
      diagnostics$forward_error_budget > 1) ||
    any(diagnostics$rcond_min <= 0 | diagnostics$rcond_min > 1) ||
    any(diagnostics$max_backward_error <= 0 |
      diagnostics$max_backward_error > 1) ||
    any(diagnostics$refinement_trigger <= 0 |
      diagnostics$refinement_trigger > 1) ||
    any(diagnostics$eta_normwise < 0) ||
    any(diagnostics$berr_componentwise < 0) ||
    any(diagnostics$absolute_residual_max < 0) ||
    any(diagnostics$sensitivity_estimate < 0) ||
    any(diagnostics$forward_error_bound < 0) ||
    any(pmax(
      diagnostics$eta_normwise,
      diagnostics$berr_componentwise
    ) > diagnostics$max_backward_error) ||
    any(diagnostics$forward_error_bound >
      diagnostics$forward_error_budget) ||
    !relative_match(
      diagnostics$sensitivity_estimate,
      diagnostics$eta_normwise / diagnostics$rcond
    ) ||
    !relative_match(
      diagnostics$forward_error_bound,
      diagnostics$sensitivity_estimate
    ) ||
    any(diagnostics$certificate_margin <= 0) ||
    any(diagnostics$certificate_ratio_upper < 0 |
      diagnostics$certificate_ratio_upper >= 1) ||
    any(diagnostics$certificate_roundoff_bound_max < 0) ||
    any(diagnostics$coefficient_negative_count == 0 &
      diagnostics$certificate_type != "productivity_nonnegative") ||
    any(diagnostics$coefficient_negative_count > 0 &
      diagnostics$certificate_type != "absolute_convergence_signed")
  ) {
    stop("Published Leontief diagnostics violate their numerical contract.", call. = FALSE)
  }

  key <- paste(diagnostics$method, diagnostics$year, sep = "\r")
  if (anyDuplicated(key)) {
    stop("Published Leontief diagnostics contain duplicate method-years.", call. = FALSE)
  }
  expected_order <- order(
    diagnostics$method,
    diagnostics$year,
    method = "radix"
  )
  if (!identical(expected_order, seq_len(nrow(diagnostics)))) {
    stop("Published Leontief diagnostics are not deterministically ordered.", call. = FALSE)
  }
  if (!is.null(method)) {
    if (
      !is.character(method) || length(method) != 1L || is.na(method) ||
      !nzchar(method) || any(diagnostics$method != method)
    ) {
      stop("Published Leontief diagnostics do not match the method.", call. = FALSE)
    }
  }
  if (!is.null(expected_years)) {
    expected_years <- as.character(expected_years)
    if (
      anyNA(expected_years) || any(!nzchar(expected_years)) ||
      anyDuplicated(expected_years) ||
      !setequal(diagnostics$year, expected_years)
    ) {
      stop(
        "Published Leontief diagnostics do not cover the expected years.",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

wlv_append_leontief_diagnostics <- function(existing, diagnostics) {
  artifact_name <- "_leontief_diagnostics.csv"
  if (is.null(existing)) {
    existing <- list()
  }
  if (
    !is.list(existing) ||
    (length(existing) &&
      (is.null(names(existing)) || anyNA(names(existing)) ||
        any(!nzchar(names(existing))) || anyDuplicated(names(existing))))
  ) {
    stop("Scientific diagnostics must be a uniquely named list.", call. = FALSE)
  }
  wlv_validate_leontief_diagnostic_artifact(diagnostics)
  if (artifact_name %in% names(existing)) {
    current <- existing[[artifact_name]]
    wlv_validate_leontief_diagnostic_artifact(current)
    diagnostics <- rbind(current, diagnostics)
  }
  diagnostics <- diagnostics[
    order(diagnostics$method, diagnostics$year, method = "radix"),
    ,
    drop = FALSE
  ]
  row.names(diagnostics) <- NULL
  wlv_validate_leontief_diagnostic_artifact(diagnostics)
  existing[[artifact_name]] <- diagnostics
  existing
}

wlv_load_leontief_diagnostic_artifact <- function(
    result_dir,
    method,
    expected_years = NULL) {
  name <- "_leontief_diagnostics.csv"
  path <- file.path(result_dir, name)
  if (!file.exists(path)) {
    stop(
      sprintf(
        paste0(
          "Cannot recalculate `%s`: published scientific sidecar `%s` is ",
          "missing. Run a full calculation first."
        ),
        method,
        name
      ),
      call. = FALSE
    )
  }
  diagnostics <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8",
    colClasses = c(
      method = "character", year = "character",
      system_orientation = "character", matrix_scope = "character",
      rcond_norm = "character", certificate_type = "character",
      lambda_fingerprint = "character"
    )
  )
  wlv_validate_leontief_diagnostic_artifact(
    diagnostics,
    method = method,
    expected_years = expected_years
  )
  diagnostics
}
