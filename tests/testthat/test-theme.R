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

test_that("use_theme_mt() leaves geom_density()'s bandwidth alone and injects no phantom aesthetic", {
  # use_theme_mt() used to call update_geom_defaults("density",
  # list(adjust = 5)) and the docs claimed it set a heavier smoothing
  # bandwidth. It never did: `adjust` is a StatDensity parameter, not a geom
  # aesthetic, so the call only wrote an `adjust` entry into
  # GeomDensity$default_aes where nothing reads it - permanently, session-wide,
  # with no way to undo it short of restarting R. Byte-identical output to
  # adjust = 1 was what users actually got.
  old_theme <- theme_get()
  on.exit(theme_set(old_theme), add = TRUE)

  use_theme_mt()
  expect_false("adjust" %in% names(GeomDensity$default_aes))

  built <- function(p) ggplot_build(p)$data[[1]]$y
  after_use_theme_mt <- built(ggplot(mtcars, aes(mpg)) + geom_density())
  expect_equal(after_use_theme_mt, built(ggplot(mtcars, aes(mpg)) + geom_density(adjust = 1)))
  expect_false(isTRUE(all.equal(
    after_use_theme_mt,
    built(ggplot(mtcars, aes(mpg)) + geom_density(adjust = 5))
  )))
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

test_that("theme_mt(dark = FALSE)'s complete output matches its recorded snapshot", {
  # NEWS.md claims theme_mt(dark = FALSE) has stayed "pixel-identical" since
  # 0.1.0, but every other test here only checks individual fields - a
  # change to, say, plot.margin or panel.spacing would pass all of them
  # silently. This pins the FULL theme object (all 153-ish elements),
  # confirmed deterministic across calls (identical(theme_mt(), theme_mt())
  # is TRUE - no environment/pointer noise), so any future accidental
  # change shows up as a snapshot diff instead of nothing at all. Run
  # `testthat::snapshot_review()`/`snapshot_accept()` if a change here is
  # deliberate, not a regression.
  expect_snapshot(print(theme_mt()))
})

test_that("theme_mt(dark = TRUE) resolves default geom colors to the dark ink, not black", {
  # The bug this pins: theme_minimal()'s own `ink` argument colors text/line
  # theme elements only, NOT the `geom` element's own `ink` slot that geom
  # default colors are resolved from - so dark mode used to draw points,
  # lines and text in ggplot2's factory "black" on a dark page.
  dark_ink <- emptyviz:::.dark_ink

  p <- ggplot(mtcars, aes(wt, mpg)) +
    geom_point() +
    geom_line() +
    theme_mt(dark = TRUE, base_family = "")
  built <- ggplot_build(p)

  expect_identical(unique(built$data[[1]]$colour), dark_ink)
  expect_identical(unique(built$data[[2]]$colour), dark_ink)

  # light mode is unaffected
  light <- ggplot_build(
    ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_mt(base_family = "")
  )
  expect_identical(unique(light$data[[1]]$colour), "black")
})

test_that("the palette constants are exactly what they claim to be", {
  # The palette constants had zero test coverage, so an accidental edit to a
  # hex digit would go unnoticed - and every plot built on theme_mt()'s
  # defaults inherits them. This pins the values rather than asserting a
  # contrast threshold: the palettes separate categories by hue and are
  # deliberately NOT being re-spaced by lightness (see theme_mt()'s Details
  # and the accompanying contrast test below, which records where they
  # actually stand).
  expect_identical(mt_colors, c("#066b8a", "#8a064a"))
  expect_identical(mt_colors3, c("#066b8a", "#8a064a", "#d56f09"))
  expect_identical(mt_colors4, c("#066b8a", "#8a064a", "#d56f09", "#9109d5"))
  expect_identical(mt_colors5, c("#066b8a", "#8a064a", "#d56f09", "#9109d5", "#142f8f"))

  expect_identical(dark_mt_colors, c("#70ceeb", "#eb70af"))
  expect_identical(dark_mt_colors3, c("#70ceeb", "#eb70af", "#ebad70"))
  expect_identical(dark_mt_colors4, c("#70ceeb", "#eb70af", "#ebad70", "#c270eb"))
  expect_identical(
    dark_mt_colors5,
    c("#70ceeb", "#eb70af", "#ebad70", "#c270eb", "#7b91e0")
  )

  # each extension appends to the previous one rather than redefining it
  expect_identical(mt_colors5[seq_along(mt_colors4)], mt_colors4)
  expect_identical(dark_mt_colors5[seq_along(dark_mt_colors4)], dark_mt_colors4)

  # the continuous ramp still runs between the two base hues
  ramp <- mt_colors_many(3)
  expect_length(ramp, 3)
  expect_identical(toupper(ramp[c(1, 3)]), toupper(mt_colors))
})

test_that("the dark axis line clears 3:1 against the page background it's designed for, and the grid stays decorative", {
  # WCAG 1.4.11 relative-luminance contrast. The axis line is documented as
  # "a real boundary", i.e. a meaningful graphical object, so 3:1 is its
  # floor; it used to sit at 2.655:1. The grid is genuinely decorative and
  # is deliberately left far below that - raising it would fight the design.
  # #151515 is the page background the dark constants are tuned against
  # (see theme_mt()'s Details); theme_mt(dark = TRUE) sets paper = NA, so
  # the real background is whatever the host page uses.
  page_bg <- "#151515"

  expect_gte(wcag_contrast(emptyviz:::.dark_axis_line, page_bg), 3)
  expect_lt(wcag_contrast(emptyviz:::.dark_grid, page_bg), 1.5)
  # text tints are well clear of the 4.5:1 body-text threshold
  expect_gte(wcag_contrast(emptyviz:::.dark_ink, page_bg), 4.5)
  expect_gte(wcag_contrast(emptyviz:::.dark_axis_text, page_bg), 4.5)
})

test_that("the discrete palettes separate categories by hue, not lightness - recorded, not asserted away", {
  # This does NOT assert the >= 3:1 pairwise separation WCAG 1.4.11 wants
  # between graphical objects: the palettes are deliberately unchanged, and
  # they don't meet it. It pins the current state so a future palette edit
  # shows up as a diff here, and so the number in theme_mt()'s Details
  # can't drift away from reality.
  worst <- function(pal) {
    pairs <- utils::combn(pal, 2)
    min(apply(pairs, 2, function(p) wcag_contrast(p[1], p[2])))
  }

  expect_equal(worst(mt_colors5), 1.09, tolerance = 0.01)
  expect_lt(worst(dark_mt_colors5), 3)

  # against a white page every hue is legible on its own - the limitation is
  # strictly category-vs-category, which is what theme_mt()'s Details says
  for (col in mt_colors5) expect_gte(wcag_contrast(col, "#ffffff"), 3)
})
