singularity_profile_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "leontief_diagnostics.R"),
  envir = singularity_profile_environment
)

exchange_coefficients <- function() {
  matrix(
    c(
      0, 1, 0, 0,
      1, 0, 0, 0,
      0, 0, 0.3, 0.2,
      0, 0, 0.1, 0.4
    ),
    nrow = 4L,
    byrow = TRUE,
    dimnames = list(
      c("A.S1", "A.S2", "A.S3", "A.S4"),
      c("A.S1", "A.S2", "A.S3", "A.S4")
    )
  )
}

test_that("invertible systems profile as invertible and compatible", {
  coefficients <- matrix(
    0.2,
    nrow = 3L,
    ncol = 3L,
    dimnames = list(c("A.S1", "A.S2", "A.S3"), c("A.S1", "A.S2", "A.S3"))
  )
  labour <- stats::setNames(c(1, 2, 3), c("A.S1", "A.S2", "A.S3"))
  result <- singularity_profile_environment$wlv_leontief_singularity_profile(
    coefficients,
    labour_requirements = labour,
    method = "invertible",
    year = "2000"
  )
  profile <- result$profile
  expect_identical(
    names(profile),
    singularity_profile_environment$wlv_leontief_singularity_profile_columns()
  )
  expect_identical(profile$classification, "invertible")
  expect_identical(profile$dimension, 3L)
  expect_identical(profile$qr_rank, 3L)
  expect_identical(profile$nullity, 0L)
  expect_identical(profile$dependent_column_count, 0L)
  expect_identical(result$dependent_columns, character(0L))
  expect_identical(length(result$dependent_indices), 0L)
  expect_gt(profile$rcond, profile$rcond_min)
  expect_true(profile$compatible)
  expect_lt(profile$eta_normwise_min_norm, 1e-12)
  expect_true(profile$spectral_radius_converged)
  expect_lt(profile$spectral_radius_estimate, 1)
  expect_equal(
    profile$spectral_radius_estimate,
    0.6,
    tolerance = 1e-9
  )
})

test_that("null coefficient rows alone do not singularize the system", {
  labels <- c("A.S1", "A.S2", "A.S3")
  coefficients <- matrix(
    c(
      0.10, 0.30, 0.20,
      0, 0, 0,
      0.05, 0.20, 0.10
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(labels, labels)
  )
  profile <- singularity_profile_environment$
    wlv_leontief_singularity_profile(
      coefficients,
      method = "null_rows",
      year = "2001"
    )$profile
  expect_identical(profile$classification, "invertible")
  expect_identical(profile$coefficient_null_row_count, 1L)
  expect_identical(profile$coefficient_null_column_count, 0L)
  expect_identical(profile$nullity, 0L)
})

test_that("duplicate coefficient columns alone do not singularize the system", {
  labels <- c("A.S1", "A.S2", "A.S3")
  coefficients <- matrix(
    c(
      0.10, 0.10, 0.20,
      0.30, 0.30, 0.05,
      0.05, 0.05, 0.10
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(labels, labels)
  )
  profile <- singularity_profile_environment$
    wlv_leontief_singularity_profile(
      coefficients,
      method = "duplicate_columns",
      year = "2002"
    )$profile
  expect_identical(profile$classification, "invertible")
  expect_identical(profile$duplicate_coefficient_column_count, 1L)
  expect_identical(profile$nullity, 0L)
})

test_that("zero value-added exchange loops are singular and classified", {
  coefficients <- exchange_coefficients()
  labour <- stats::setNames(
    c(1, 2, 3, 4),
    c("A.S1", "A.S2", "A.S3", "A.S4")
  )
  result <- singularity_profile_environment$wlv_leontief_singularity_profile(
    coefficients,
    labour_requirements = labour,
    method = "exchange",
    year = "2003"
  )
  profile <- result$profile
  expect_identical(profile$classification, "singular_null_structure")
  expect_identical(profile$qr_rank, 3L)
  expect_identical(profile$nullity, 1L)
  expect_identical(profile$dependent_column_count, 1L)
  expect_identical(result$dependent_columns, "A.S2")
  expect_identical(result$dependent_indices, 2L)
  expect_identical(profile$zero_value_added_candidate_count, 2L)
  expect_identical(profile$rcond, 0)
  expect_true(profile$spectral_radius_converged)
  expect_equal(profile$spectral_radius_estimate, 1, tolerance = 1e-12)
  expect_identical(profile$spectral_radius_bound, 1)
  expect_false(profile$compatible)
  expect_gt(profile$min_norm_residual_max, 0)
  expect_match(profile$dependent_column_sample, "A.S2")
  expect_true(nzchar(profile$dependent_column_fingerprint))
})

test_that("singular but consistent systems stay compatible", {
  coefficients <- exchange_coefficients()
  consistent_labour <- as.vector(
    t(diag(4L) - coefficients) %*% c(1, 1, 1, 1)
  )
  names(consistent_labour) <- c("A.S1", "A.S2", "A.S3", "A.S4")
  profile <- singularity_profile_environment$
    wlv_leontief_singularity_profile(
      coefficients,
      labour_requirements = consistent_labour,
      method = "exchange_consistent",
      year = "2004"
    )$profile
  expect_identical(profile$classification, "singular_null_structure")
  expect_identical(profile$nullity, 1L)
  expect_true(profile$compatible)
  expect_lt(profile$eta_normwise_min_norm, 1e-12)
})

test_that("near-productive systems profile as ill-conditioned", {
  # Loop de troca com folga diminuta: I - C é inversível, mas mal condicionado.
  coefficients <- matrix(
    c(0, 1 - 1e-9, 1 - 1e-9, 0),
    nrow = 2L,
    ncol = 2L,
    dimnames = list(c("A.S1", "A.S2"), c("A.S1", "A.S2"))
  )
  profile <- singularity_profile_environment$
    wlv_leontief_singularity_profile(
      coefficients,
      method = "ill_conditioned",
      year = "2005"
    )$profile
  expect_identical(profile$classification, "ill_conditioned")
  expect_identical(profile$nullity, 0L)
  expect_lt(profile$rcond, profile$rcond_min)
  expect_gt(profile$rcond, 0)
})

test_that("the singularity profile validates its inputs", {
  expect_error(
    singularity_profile_environment$wlv_leontief_singularity_profile(
      matrix(0.1, nrow = 2L, ncol = 3L),
      method = "invalid",
      year = "2000"
    ),
    "Invalid Leontief coefficients"
  )
  expect_error(
    singularity_profile_environment$wlv_leontief_singularity_profile(
      matrix(c(0.1, NA, 0.2, 0.3), nrow = 2L, ncol = 2L),
      method = "invalid",
      year = "2000"
    ),
    "Invalid Leontief coefficients"
  )
  expect_error(
    singularity_profile_environment$wlv_leontief_singularity_profile(
      diag(0.2, nrow = 2L, ncol = 2L),
      labour_requirements = c(1),
      method = "invalid",
      year = "2000"
    ),
    "Invalid direct labour"
  )
  labels <- c("A.S1", "A.S2")
  mismatched <- matrix(
    0.2,
    nrow = 2L,
    ncol = 2L,
    dimnames = list(labels, c("B.S1", "B.S2"))
  )
  expect_error(
    singularity_profile_environment$wlv_leontief_singularity_profile(
      mismatched,
      method = "invalid",
      year = "2000"
    ),
    "row and column labels differ"
  )
  expect_error(
    singularity_profile_environment$wlv_leontief_singularity_profile(
      diag(0),
      method = "",
      year = "2000"
    ),
    "nonempty method and year"
  )
})

test_that("profiles work without labels and on scalar systems", {
  profile <- singularity_profile_environment$
    wlv_leontief_singularity_profile(
      matrix(0.5, nrow = 1L, ncol = 1L),
      method = "scalar",
      year = "2006"
    )$profile
  expect_identical(profile$classification, "invertible")
  expect_identical(profile$dimension, 1L)
  expect_identical(profile$qr_rank, 1L)
  result <- singularity_profile_environment$wlv_leontief_singularity_profile(
    matrix(1, nrow = 1L, ncol = 1L),
    method = "scalar_singular",
    year = "2007"
  )
  expect_identical(result$profile$classification, "singular_null_structure")
  expect_identical(result$dependent_columns, "1")
})
