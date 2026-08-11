test_that("use_theme_mt() sets theme_mt() as the active theme and restores the previous one on exit", {
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)

  use_theme_mt(base_size = 12)
  active <- theme_get()
  expect_s3_class(active, "theme")
  expect_equal(active$text$size, 12)
})

test_that("use_theme_mt() sets geom_density()'s default `adjust` to 5", {
  old_adjust <- GeomDensity$default_aes$adjust
  old_theme <- theme_get()
  on.exit({
    theme_set(old_theme)
    update_geom_defaults("density", list(adjust = old_adjust %||% 1))
  }, add = TRUE)

  use_theme_mt()
  expect_equal(GeomDensity$default_aes$adjust, 5)
})

test_that("use_theme_mt() returns invisible(NULL)", {
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)
  expect_null(withVisible(use_theme_mt())$value)
})
