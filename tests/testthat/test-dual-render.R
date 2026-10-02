# Two path variables, deliberately: `fig.path` is a knitr *filename prefix*,
# not a directory, so it has to keep its trailing separator - that is what the
# code under test pastes the figure names onto. The assertions use `fig_dir`
# (no trailing separator) instead, because on Windows a path with a trailing
# separator is not a valid path at all and `file.path(fig_path, ...)` doubles
# the separator, which is only *usually* accepted there. Asserting through
# `fig_path` therefore reported missing files that had in fact been written -
# invisible on POSIX, which collapses both forms silently, until the CI matrix
# grew a Windows runner (2026-08-22).

test_that("knit_print_ggplot_dual() falls through to a normal print when dual_render isn't set", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()

  out <- withVisible(emptyviz:::knit_print_ggplot_dual(p, options = list(label = "fig-x")))
  expect_null(out$value)
})

test_that("knit_print_ggplot_dual() saves two PNGs and emits light/dark-wrapped output when dual_render is TRUE", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  tmp <- tempfile("dual-render-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

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
  expect_true(file.exists(file.path(fig_dir, "fig-x-light-1.png")))
  expect_true(file.exists(file.path(fig_dir, "fig-x-dark-1.png")))
  expect_match(unclass(out), "light-content", fixed = TRUE)
  expect_match(unclass(out), "dark-content", fixed = TRUE)

  # Regression test: this used to emit markdown `![](path)` syntax inside
  # the light/dark-content divs. That only renders as an image on chunks
  # Quarto re-parses as markdown (labeled `fig-*` with a fig-cap, which
  # triggers its crossref/figure filter) - an ordinary chunk (no fig-cap,
  # e.g. one without a `fig-` label) left the raw
  # "![](path)" text showing on the page instead of the image. Raw <img>
  # tags render correctly regardless of which path a chunk hits.
  expect_match(unclass(out), '<img src="', fixed = TRUE)
  expect_no_match(unclass(out), "![](", fixed = TRUE)
})

test_that("knit_print_ggplot_dual()'s dark render applies the overlay to every sub-plot of a patchwork combo", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  skip_if_not_installed("patchwork")
  library(patchwork)

  tmp <- tempfile("dual-render-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

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
  expect_true(file.exists(file.path(fig_dir, "fig-combo-light-1.png")))
  expect_true(file.exists(file.path(fig_dir, "fig-combo-dark-1.png")))
})

test_that(".dark_mode_overlay() doesn't un-blank elements a plot deliberately hid (e.g. via theme_void())", {
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_void()
  dark <- p + emptyviz:::.dark_mode_overlay(p)
  resolved <- complete_theme(dark$theme)

  expect_true(inherits(calc_element("panel.grid", resolved), "element_blank"))
  expect_true(inherits(calc_element("axis.text", resolved), "element_blank"))
  expect_true(inherits(calc_element("axis.line", resolved), "element_blank"))
})

test_that(".dark_mode_overlay() correctly colors axis text even when the chunk has its own partial override on the same specific element", {
  # A chunk that overrides one property of a position-specific element
  # (here the family of axis.text.x.bottom) gets that element's missing
  # colour from the active light theme, not from a parent set by the overlay.
  # The overlay therefore sets every position-specific element theme_mt()
  # sets.
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)
  use_theme_mt() # the light session default

  p <- ggplot(mtcars, aes(wt, mpg)) +
    geom_point() +
    theme(axis.text.x.bottom = element_markdown(family = "Cascadia Code"))

  dark <- p + emptyviz:::.dark_mode_overlay(p)
  resolved <- complete_theme(dark$theme)
  el <- calc_element("axis.text.x.bottom", resolved)

  expect_equal(el$family, "Cascadia Code") # the chunk's own override survives
  expect_equal(el$colour, emptyviz:::.dark_axis_text) # but color still flips
})

test_that("knit_print_ggplot_dual() called twice for the same chunk label doesn't collide on output filenames", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  tmp <- tempfile("dual-render-test-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

  p1 <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  p2 <- ggplot(mtcars, aes(hp, mpg)) + geom_point()
  opts <- list(
    dual_render = TRUE, label = "fig-multi", fig.path = fig_path,
    fig.width = 4, fig.height = 3, dpi = 72,
    fig.alt = "Scatter plot of car weight against fuel economy."
  )

  out1 <- emptyviz:::knit_print_ggplot_dual(p1, options = opts)
  out2 <- emptyviz:::knit_print_ggplot_dual(p2, options = opts)

  expect_true(file.exists(file.path(fig_dir, "fig-multi-light-1.png")))
  expect_true(file.exists(file.path(fig_dir, "fig-multi-dark-1.png")))
  expect_true(file.exists(file.path(fig_dir, "fig-multi-light-2.png")))
  expect_true(file.exists(file.path(fig_dir, "fig-multi-dark-2.png")))
  expect_match(unclass(out1), "fig-multi-light-1.png", fixed = TRUE)
  expect_match(unclass(out2), "fig-multi-light-2.png", fixed = TRUE)
})

test_that("use_theme_mt() registers a knit_print method for ggplot objects", {
  skip_if_not_installed("knitr")
  local_quarto_html()
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
  local_quarto_html()
  tmp <- tempfile("dual-render-alt-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

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
  # used to vanish silently. The label has no `fig-` prefix, so emptyviz
  # still owns the caption.
  with_cap <- render(label = "plot-cap", fig.cap = "Weight versus fuel economy.")
  expect_match(with_cap, 'alt="Weight versus fuel economy."', fixed = TRUE)
  expect_match(with_cap, "<figcaption", fixed = TRUE)
  expect_match(with_cap, ">Weight versus fuel economy.</figcaption>", fixed = TRUE)

  # fig.alt wins over fig.cap when both are given
  both <- render(label = "plot-both", fig.alt = "Alt text.", fig.cap = "Caption text.")
  expect_match(both, 'alt="Alt text."', fixed = TRUE)
  expect_match(both, ">Caption text.</figcaption>", fixed = TRUE)

  # no caption means no <figure> wrapper at all
  expect_no_match(with_alt, "<figure", fixed = TRUE)

  # A `fig-` label means Quarto's crossref filter adds its own numbered
  # caption; emitting ours too used to show the caption twice. The alt text
  # must survive, though.
  quarto_cap <- render(label = "fig-quarto", fig.cap = "Weight versus fuel economy.")
  expect_match(quarto_cap, 'alt="Weight versus fuel economy."', fixed = TRUE)
  expect_no_match(quarto_cap, "<figcaption", fixed = TRUE)
  expect_no_match(quarto_cap, "<figure", fixed = TRUE)

  # and the alt attribute is present even when nothing was supplied
  bare <- suppressWarnings(render(label = "fig-bare"))
  expect_match(bare, 'alt=""', fixed = TRUE)
})

test_that("knit_print_ggplot_dual() warns once per chunk when neither fig.alt nor fig.cap is set", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  tmp <- tempfile("dual-render-warn-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

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
  local_quarto_html()
  tmp <- tempfile("dual-render-esc-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  out <- unclass(emptyviz:::knit_print_ggplot_dual(
    p,
    options = list(
      dual_render = TRUE, label = "plot-esc", fig.path = fig_path,
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
  local_quarto_html()
  tmp <- tempfile("dual-render-vec-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

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
  local_quarto_html()
  tmp <- tempfile("dual-render-reset-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

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
  expect_equal(sort(list.files(fig_dir)), c("fig-x-dark-1.png", "fig-x-light-1.png"))
})

test_that("multiple plots within one chunk still get distinct filenames", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  tmp <- tempfile("dual-render-multi2-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  fig_dir <- file.path(tmp, "figure-html")
  fig_path <- paste0(fig_dir, "/")

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
    sort(list.files(fig_dir)),
    c("fig-two-dark-1.png", "fig-two-dark-2.png", "fig-two-light-1.png", "fig-two-light-2.png")
  )
})

test_that("knit_print_ggplot_dual() renders normally for output other than Quarto HTML", {
  skip_if_not_installed("knitr")
  old <- knitr::opts_knit$get(c("rmarkdown.pandoc.to", "quarto.version"))
  on.exit(knitr::opts_knit$set(old), add = TRUE)
  emptyviz:::.register_dual_render() # resets the once-per-render warning
  tmp <- tempfile("dual-render-fallback-")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  opts <- list(
    dual_render = TRUE, label = "fig-x", fig.path = paste0(tmp, "/"),
    fig.alt = "Scatter plot."
  )
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  # LaTeX/PDF output, e.g. the PDF build of a project that also renders HTML:
  # pandoc would drop the raw HTML, and the figure with it. This is expected
  # in a multi-format project, so it is silent.
  knitr::opts_knit$set(rmarkdown.pandoc.to = "latex", quarto.version = "1.6.0")
  expect_no_warning(out <- emptyviz:::knit_print_ggplot_dual(p, options = opts))
  expect_null(out)
  expect_false(dir.exists(tmp))

  # HTML without Quarto has no CSS for the light/dark classes: a
  # misconfiguration, warned about once per render
  knitr::opts_knit$set(rmarkdown.pandoc.to = "html", quarto.version = NULL)
  expect_warning(
    out <- emptyviz:::knit_print_ggplot_dual(p, options = opts),
    "needs HTML output rendered by Quarto"
  )
  expect_null(out)
  expect_false(dir.exists(tmp))
  expect_no_warning(emptyviz:::knit_print_ggplot_dual(p, options = opts))
})

test_that("dual-rendered figures keep knitr's retina sizing and honour the chunk's device", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  tmp <- tempfile("dual-render-device-")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  render <- function(label, ...) {
    emptyviz:::knit_print_ggplot_dual(p, options = list(
      dual_render = TRUE, label = label, fig.path = paste0(tmp, "/"),
      fig.width = 4, fig.height = 3, fig.alt = "Scatter plot.", ...
    ))
  }
  png_width <- function(path) {
    # IHDR: the width is the big-endian integer at bytes 17-20
    bytes <- readBin(path, "raw", 24)
    sum(as.integer(bytes[17:20]) * 256^(3:0))
  }

  # What knitr passes for an HTML figure with fig.retina = 2 and dpi = 72:
  # the dpi already doubled, out.width set to the nominal width in pixels.
  out <- render("fig-retina", dpi = 144, fig.retina = 2, out.width = 288L, dev = "png")
  expect_equal(png_width(file.path(tmp, "fig-retina-light-1.png")), 4 * 144)
  expect_match(unclass(out), 'style="width:288px"', fixed = TRUE)

  out <- render("fig-plain", dpi = 72, dev = "png")
  expect_equal(png_width(file.path(tmp, "fig-plain-light-1.png")), 4 * 72)
  expect_no_match(unclass(out), "style=", fixed = TRUE)

  # a width with a unit is used as given
  out <- render("fig-out", dpi = 72, out.width = "50%")
  expect_match(unclass(out), 'style="width:50%"', fixed = TRUE)

  # a vector device: browsers can show SVG (grDevices::svg() needs cairo)
  if (capabilities("cairo")) {
    render("fig-svg", dpi = 72, dev = "svg")
    expect_true(file.exists(file.path(tmp, "fig-svg-dark-1.svg")))
  }

  # a device a browser cannot display falls back to PNG
  render("fig-pdf", dpi = 72, dev = "pdf")
  expect_true(file.exists(file.path(tmp, "fig-pdf-light-1.png")))
})

test_that("use_theme_mt(dual_render = FALSE) leaves knitr's ggplot printing alone", {
  skip_if_not_installed("knitr")
  old <- theme_get()
  on.exit(theme_set(old), add = TRUE)
  registered <- function() {
    getS3method("knit_print", "ggplot", optional = TRUE, envir = asNamespace("knitr"))
  }
  use_theme_mt()
  expect_identical(registered(), emptyviz:::knit_print_ggplot_dual)
  use_theme_mt(dual_render = FALSE)
  expect_null(registered())
  # the theme is still set
  expect_identical(theme_get(), theme_mt())
  use_theme_mt() # restore the registration other tests expect
})

test_that("a vector out.width gives each plot of a chunk its own width", {
  skip_if_not_installed("knitr")
  local_quarto_html()
  tmp <- tempfile("dual-render-outwidth-")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  emptyviz:::.register_dual_render()
  opts <- list(
    dual_render = TRUE, label = "fig-w", fig.path = paste0(tmp, "/"),
    fig.width = 3, fig.height = 2, dpi = 36, fig.alt = "Plot.",
    out.width = c("40%", "60%")
  )
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  out1 <- unclass(emptyviz:::knit_print_ggplot_dual(p, options = opts))
  out2 <- unclass(emptyviz:::knit_print_ggplot_dual(p, options = opts))
  expect_length(out1, 1)
  expect_match(out1, "width:40%", fixed = TRUE)
  expect_no_match(out1, "width:60%", fixed = TRUE)
  expect_match(out2, "width:60%", fixed = TRUE)
})
