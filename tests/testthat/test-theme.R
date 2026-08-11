test_that("use_theme_mt() sets theme_mt() as the active theme and restores the previous one on exit", {
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)

  use_theme_mt(base_size = 12)
  active <- theme_get()
  expect_s3_class(active, "theme")
  expect_equal(active$text$size, 12)
})

test_that("use_theme_mt() forwards ... to theme_mt()", {
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)

  use_theme_mt(dark = TRUE)
  expect_identical(theme_get()$palette.colour.discrete, dark_mt_colors5)
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

test_that("theme_mt(dark = FALSE) is unchanged by the dark argument existing", {
  t <- theme_mt()
  expect_identical(t$palette.colour.discrete, mt_colors5)
  expect_identical(t$palette.fill.discrete, mt_colors5)
  expect_identical(t$plot.background$fill, alpha("white", .5))
})

test_that("theme_mt(dark = TRUE) swaps in the dark palette and a transparent background", {
  t <- theme_mt(dark = TRUE)
  expect_identical(t$palette.colour.discrete, dark_mt_colors5)
  expect_identical(t$palette.fill.discrete, dark_mt_colors5)
  expect_true(is.na(t$plot.background$fill))
})

test_that("theme_mt(dark = TRUE)'s grid_color/axis_text_color defaults differ from the light defaults but stay overridable", {
  expect_false(identical(theme_mt(dark = TRUE)$axis.text.x$colour, theme_mt()$axis.text.x$colour))
  t <- theme_mt(dark = TRUE, axis_text_color = "red")
  expect_equal(t$axis.text.x$colour, "red")
})

test_that("theme_mt(dark = TRUE)'s axis line is a distinct, brighter color than the grid, but light mode keeps sharing grid_color", {
  dark <- theme_mt(dark = TRUE)
  expect_false(identical(dark$axis.line$colour, dark$panel.grid$colour))

  light <- theme_mt()
  expect_identical(light$axis.line$colour, light$panel.grid$colour)

  t <- theme_mt(dark = TRUE, axis_line_color = "red")
  expect_equal(t$axis.line$colour, "red")
})

test_that("axis text has a non-zero margin from the axis, in both light and dark mode", {
  for (t in list(theme_mt(), theme_mt(dark = TRUE))) {
    expect_gt(as.numeric(t$axis.text.x$margin[1]), 0) # top
    expect_gt(as.numeric(t$axis.text.y$margin[2]), 0) # right
  }
})
