test_that("knit_print_ggplot_dual() falls through to a normal print when dual_render isn't set", {
  skip_if_not_installed("knitr")
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()

  out <- withVisible(emptyviz:::knit_print_ggplot_dual(p, options = list(label = "fig-x")))
  expect_null(out$value)
})

test_that("knit_print_ggplot_dual() saves two PNGs and emits light/dark-wrapped output when dual_render is TRUE", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  out <- emptyviz:::knit_print_ggplot_dual(
    p,
    options = list(dual_render = TRUE, label = "fig-x", fig.path = fig_path, fig.width = 4, fig.height = 3, dpi = 72)
  )

  expect_s3_class(out, "knit_asis")
  expect_true(file.exists(file.path(fig_path, "fig-x-light-1.png")))
  expect_true(file.exists(file.path(fig_path, "fig-x-dark-1.png")))
  expect_match(unclass(out), "light-content", fixed = TRUE)
  expect_match(unclass(out), "dark-content", fixed = TRUE)
})

test_that("knit_print_ggplot_dual()'s dark render applies the overlay to every sub-plot of a patchwork combo", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("patchwork")
  library(patchwork)

  tmp <- tempfile("dual-render-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  combo <- (ggplot(mtcars, aes(wt, mpg)) + geom_point()) +
    (ggplot(mtcars, aes(hp, mpg)) + geom_point())

  # patchwork's `+` only applies a theme addition to the last sub-plot; `&`
  # applies it to every sub-plot uniformly. Confirms the dark overlay lands
  # on all panels, not just the last one, before checking the full function.
  overlay <- emptyviz:::.dark_mode_overlay(combo[[1]])
  expect_identical(
    (combo & overlay)[[1]]$theme$axis.text$colour,
    (combo & overlay)[[2]]$theme$axis.text$colour
  )

  emptyviz:::knit_print_ggplot_dual(
    combo,
    options = list(dual_render = TRUE, label = "fig-combo", fig.path = fig_path, fig.width = 6, fig.height = 3, dpi = 72)
  )
  expect_true(file.exists(file.path(fig_path, "fig-combo-light-1.png")))
  expect_true(file.exists(file.path(fig_path, "fig-combo-dark-1.png")))
})

test_that(".dark_mode_overlay() doesn't un-blank elements a plot deliberately hid (e.g. via theme_void())", {
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_void()
  dark <- p + emptyviz:::.dark_mode_overlay(p)
  resolved <- ggplot2:::plot_theme(dark)

  expect_true(inherits(calc_element("panel.grid", resolved), "element_blank"))
  expect_true(inherits(calc_element("axis.text", resolved), "element_blank"))
  expect_true(inherits(calc_element("axis.line", resolved), "element_blank"))
})

test_that("use_theme_mt() registers a knit_print method for ggplot objects", {
  skip_if_not_installed("knitr")
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)

  use_theme_mt()
  m <- getS3method("knit_print", "ggplot", optional = TRUE, envir = asNamespace("knitr"))
  expect_true(is.function(m))
})
