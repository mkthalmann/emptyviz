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
    options = list(
      dual_render = TRUE, label = "fig-x", fig.path = fig_path,
      fig.width = 4, fig.height = 3, dpi = 72,
      fig.alt = "Scatter plot of car weight against fuel economy."
    )
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
    options = list(
      dual_render = TRUE, label = "fig-combo", fig.path = fig_path,
      fig.width = 6, fig.height = 3, dpi = 72,
      fig.alt = "Two scatter plots of fuel economy, against weight and horsepower."
    )
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

test_that(".dark_mode_overlay() warns (rather than silently mis-rendering) if ggplot2:::plot_theme() fails", {
  # Regression test: the tryCatch() around ggplot2:::plot_theme() used to
  # fall back to theme_get() (the *global* active theme, not necessarily
  # this plot's own) with no signal at all - meaning a future ggplot2
  # release that renames/restructures plot_theme() would silently start
  # un-blanking elements a plot deliberately hid (e.g. via theme_void()),
  # confirmed by simulating the failure directly, with zero test coverage
  # before this. It should now warn instead.
  local_mocked_bindings(plot_theme = function(...) stop("simulated failure"), .package = "ggplot2")
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  expect_warning(emptyviz:::.dark_mode_overlay(p), "plot_theme")
})

test_that("knit_print_ggplot_dual() called twice for the same chunk label doesn't collide on output filenames", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  p1 <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  p2 <- ggplot(mtcars, aes(hp, mpg)) + geom_point()
  opts <- list(
    dual_render = TRUE, label = "fig-multi", fig.path = fig_path,
    fig.width = 4, fig.height = 3, dpi = 72,
    fig.alt = "Scatter plot of car weight against fuel economy."
  )

  out1 <- emptyviz:::knit_print_ggplot_dual(p1, options = opts)
  out2 <- emptyviz:::knit_print_ggplot_dual(p2, options = opts)

  expect_true(file.exists(file.path(fig_path, "fig-multi-light-1.png")))
  expect_true(file.exists(file.path(fig_path, "fig-multi-dark-1.png")))
  expect_true(file.exists(file.path(fig_path, "fig-multi-light-2.png")))
  expect_true(file.exists(file.path(fig_path, "fig-multi-dark-2.png")))
  expect_match(unclass(out1), "fig-multi-light-1.png", fixed = TRUE)
  expect_match(unclass(out2), "fig-multi-light-2.png", fixed = TRUE)
})

test_that("use_theme_mt() registers a knit_print method for ggplot objects", {
  skip_if_not_installed("knitr")
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)

  use_theme_mt()
  m <- getS3method("knit_print", "ggplot", optional = TRUE, envir = asNamespace("knitr"))
  expect_true(is.function(m))
})

test_that(".dark_mode_overlay() resolves default geom colors to the dark ink, not black", {
  # Same defect as the theme_mt(dark = TRUE) case (see test-theme.R) reaching
  # the dual-render path: the overlay sets the geom element's `paper` but used
  # to leave its `ink` at ggplot2's factory "black", so every dual-rendered
  # figure built from default-colored geoms shipped a dark half with
  # invisible data marks.
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)
  theme_set(theme_mt(base_family = ""))

  base <- ggplot(mtcars, aes(wt, mpg)) + geom_point() + geom_line()
  built <- ggplot_build(base + .dark_mode_overlay(base))

  expect_identical(unique(built$data[[1]]$colour), emptyviz:::.dark_ink)
  expect_identical(unique(built$data[[2]]$colour), emptyviz:::.dark_ink)
})

test_that("knit_print_ggplot_dual() honours fig.alt, falling back to fig.cap, and always emits an alt attribute", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-alt-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  base_opts <- list(
    dual_render = TRUE, fig.path = fig_path,
    fig.width = 4, fig.height = 3, dpi = 72
  )
  render <- function(...) {
    unclass(emptyviz:::knit_print_ggplot_dual(p, options = utils::modifyList(base_opts, list(...))))
  }

  # Regression test: the hand-built <img> tags used to read only out.width,
  # so an author's fig.alt was discarded and the tag carried no alt attribute
  # at all - worse than alt="", since screen readers then fall back to
  # announcing the file name.
  with_alt <- render(label = "fig-alt", fig.alt = "Scatter plot of weight against fuel economy.")
  expect_match(with_alt, 'alt="Scatter plot of weight against fuel economy."', fixed = TRUE)
  # both halves of the dual render, not just the light one
  expect_equal(length(gregexpr("alt=", with_alt, fixed = TRUE)[[1]]), 2L)

  # fig.cap fills in for a missing fig.alt, matching knitr's own default for
  # an ordinary chunk, and is also rendered as a visible caption - which
  # used to vanish silently.
  with_cap <- render(label = "fig-cap", fig.cap = "Weight versus fuel economy.")
  expect_match(with_cap, 'alt="Weight versus fuel economy."', fixed = TRUE)
  expect_match(with_cap, "<figcaption", fixed = TRUE)
  expect_match(with_cap, ">Weight versus fuel economy.</figcaption>", fixed = TRUE)

  # fig.alt wins over fig.cap when both are given
  both <- render(label = "fig-both", fig.alt = "Alt text.", fig.cap = "Caption text.")
  expect_match(both, 'alt="Alt text."', fixed = TRUE)
  expect_match(both, ">Caption text.</figcaption>", fixed = TRUE)

  # no caption means no <figure> wrapper at all
  expect_no_match(with_alt, "<figure", fixed = TRUE)

  # and the alt attribute is present even when nothing was supplied
  bare <- suppressWarnings(render(label = "fig-bare"))
  expect_match(bare, 'alt=""', fixed = TRUE)
})

test_that("knit_print_ggplot_dual() warns once per chunk when neither fig.alt nor fig.cap is set", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-warn-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  opts <- list(
    dual_render = TRUE, label = "fig-no-alt", fig.path = fig_path,
    fig.width = 4, fig.height = 3, dpi = 72
  )

  expect_warning(
    emptyviz:::knit_print_ggplot_dual(p, options = opts),
    "neither `fig.alt` nor `fig.cap`"
  )
  # a second plot in the same chunk doesn't repeat the warning
  expect_no_warning(emptyviz:::knit_print_ggplot_dual(p, options = opts))

  expect_no_warning(emptyviz:::knit_print_ggplot_dual(
    p,
    options = utils::modifyList(opts, list(label = "fig-has-alt", fig.alt = "Something."))
  ))
})

test_that("knit_print_ggplot_dual() escapes HTML-special characters in every interpolated attribute", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-esc-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  out <- unclass(emptyviz:::knit_print_ggplot_dual(
    p,
    options = list(
      dual_render = TRUE, label = "fig-esc", fig.path = fig_path,
      fig.width = 4, fig.height = 3, dpi = 72,
      fig.alt = 'Marks "scare quotes" & <angle brackets>.',
      fig.cap = 'A & B "C"'
    )
  ))

  expect_match(out, "&quot;scare quotes&quot; &amp; &lt;angle brackets&gt;.", fixed = TRUE)
  expect_match(out, "A &amp; B &quot;C&quot;", fixed = TRUE)
  # the raw quote never reaches the attribute and closes it early
  expect_no_match(out, 'alt="Marks "', fixed = TRUE)
})

test_that("knit_print_ggplot_dual() recycles vector fig.alt across plots in one chunk", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-vec-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  opts <- list(
    dual_render = TRUE, label = "fig-vec", fig.path = fig_path,
    fig.width = 4, fig.height = 3, dpi = 72,
    fig.alt = c("First figure.", "Second figure.")
  )

  first <- unclass(emptyviz:::knit_print_ggplot_dual(p, options = opts))
  second <- unclass(emptyviz:::knit_print_ggplot_dual(p, options = opts))
  expect_match(first, 'alt="First figure."', fixed = TRUE)
  expect_match(second, 'alt="Second figure."', fixed = TRUE)
})

test_that("repeat renders in one session reuse the same figure filenames instead of accumulating new ones", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-reset-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)

  # Regression test: .dual_render_counters was keyed by chunk label and
  # never cleared, so its lifetime was the R session rather than one render.
  # Repeated renders are the normal workflow (quarto preview, the Knit
  # button, build_vignettes()), and each one wrote a fresh pair of PNGs
  # under a new name - nothing overwritten, nothing cleaned up, and each
  # render's HTML pointing at different files.
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  opts <- list(
    dual_render = TRUE, label = "fig-x", fig.path = fig_path,
    fig.width = 4, fig.height = 3, dpi = 72, fig.alt = "A scatter plot."
  )

  emitted <- vapply(1:3, function(i) {
    use_theme_mt() # what a document's setup chunk does, once per render
    unclass(emptyviz:::knit_print_ggplot_dual(p, options = opts))
  }, character(1))

  expect_equal(length(unique(emitted)), 1L)
  expect_match(emitted[[1]], "fig-x-light-1.png", fixed = TRUE)
  expect_equal(sort(list.files(fig_path)), c("fig-x-dark-1.png", "fig-x-light-1.png"))
})

test_that("multiple plots within one chunk still get distinct filenames", {
  skip_if_not_installed("knitr")
  tmp <- tempfile("dual-render-multi2-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_path <- file.path(tmp, "figure-html/")

  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)
  use_theme_mt()

  # the counter's actual purpose, which the per-render reset must not break
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  opts <- list(
    dual_render = TRUE, label = "fig-two", fig.path = fig_path,
    fig.width = 4, fig.height = 3, dpi = 72, fig.alt = "A scatter plot."
  )
  emptyviz:::knit_print_ggplot_dual(p, options = opts)
  emptyviz:::knit_print_ggplot_dual(p, options = opts)

  expect_equal(
    sort(list.files(fig_path)),
    c("fig-two-dark-1.png", "fig-two-dark-2.png", "fig-two-light-1.png", "fig-two-light-2.png")
  )
})
