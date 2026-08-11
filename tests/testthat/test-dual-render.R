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

  # Regression test: this used to emit markdown `![](path)` syntax inside
  # the light/dark-content divs. That only renders as an image on chunks
  # Quarto re-parses as markdown (labeled `fig-*` with a fig-cap, which
  # triggers its crossref/figure filter) - an ordinary chunk (no fig-cap,
  # like this book's plot-crit/plot-control/plot-subsamples) left the raw
  # "![](path)" text showing on the page instead of the image. Raw <img>
  # tags render correctly regardless of which path a chunk hits.
  expect_match(unclass(out), '<img src="', fixed = TRUE)
  expect_no_match(unclass(out), "![](", fixed = TRUE)
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

test_that(".dark_mode_overlay() correctly colors axis text even when the chunk has its own partial override on the same specific element", {
  # Regression test for the actual reported bug: a chunk that partially
  # overrides one specific axis text element (e.g. `axis.text.x.bottom =
  # element_markdown(family = "Cascadia Code")`, used in this book to render
  # condition-name tick labels in a monospace font) "poisons" ggplot2's
  # element merge for that exact name - it fills the missing `colour` field
  # from the *active default theme* (still light, since dark = FALSE is the
  # session default), not from a parent-level override in this overlay. A
  # plain `axis.text = element_markdown(colour = ...)` in the overlay isn't
  # enough; every position-suffixed element theme_mt() itself sets has to be
  # set explicitly here too.
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)
  use_theme_mt() # light, the actual book/template setup

  p <- ggplot(mtcars, aes(wt, mpg)) +
    geom_point() +
    theme(axis.text.x.bottom = element_markdown(family = "Cascadia Code"))

  dark <- p + emptyviz:::.dark_mode_overlay(p)
  resolved <- ggplot2:::plot_theme(dark)
  el <- calc_element("axis.text.x.bottom", resolved)

  expect_equal(el$family, "Cascadia Code") # the chunk's own override survives
  expect_equal(el$colour, emptyviz:::.dark_axis_text) # but color still flips
})

test_that("use_theme_mt() registers a knit_print method for ggplot objects", {
  skip_if_not_installed("knitr")
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)

  use_theme_mt()
  m <- getS3method("knit_print", "ggplot", optional = TRUE, envir = asNamespace("knitr"))
  expect_true(is.function(m))
})
