# Fixture with 3 x-levels deliberately not in alphabetical first-appearance
# order (same trick as sd_fixture in helper-theme.R), AND a 2-level split
# column also not in alphabetical first-appearance order ("ungrammatical"
# appears before "grammatical" in every group) - so a bug that assigned
# sides by first-appearance order instead of sorted-level order would be
# caught for `split` specifically, not just for x.
split_fixture <- (function() {
  set.seed(2)
  bind_rows(
    data.frame(grp = "c", split = "ungrammatical", y = rnorm(20)),
    data.frame(grp = "c", split = "grammatical", y = rnorm(20)),
    data.frame(grp = "a", split = "ungrammatical", y = rnorm(20)),
    data.frame(grp = "a", split = "grammatical", y = rnorm(20)),
    data.frame(grp = "b", split = "ungrammatical", y = rnorm(20)),
    data.frame(grp = "b", split = "grammatical", y = rnorm(20))
  )
})()

test_that("returns 9 components for style = 'both' (default): 6 violin layers, 1 scale, 1 legend layer, 1 guides", {
  res <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  expect_length(res, 9)

  is_layer <- vapply(res, inherits, logical(1), "LayerInstance")
  expect_equal(which(is_layer), c(1, 2, 3, 4, 5, 6, 8))
  expect_s3_class(res[[7]], "ScaleDiscrete")
  expect_s3_class(res[[9]], "Guides")
})

test_that("style = 'fill' / 'outline' return 7 components (4 violin layers instead of 6)", {
  res_fill <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, style = "fill")
  expect_length(res_fill, 7)
  res_outline <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, style = "outline")
  expect_length(res_outline, 7)
  expect_error(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, style = "nonsense")
  )
})

test_that("only the dedicated legend layer has show.legend = TRUE - the real violin layers never do", {
  # Regression test: an earlier version set show.legend = TRUE directly on
  # the outline sub-layer of each side. Since both sides map fill to the
  # same scale, ggplot2 overlaid both layers' key glyphs at every legend
  # break, so both keys rendered with whichever layer drew last, not their
  # own color. Confirmed visually before this fix.
  res <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  show_legend <- vapply(res[c(1, 2, 3, 4, 5, 6, 8)], function(l) isTRUE(l$show.legend), logical(1))
  expect_equal(show_legend, c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
})

test_that("left gets the sorted-first split level, right the second, regardless of first-appearance order in data", {
  res <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  # "grammatical" < "ungrammatical" alphabetically, even though
  # "ungrammatical" appears first in split_fixture's row order.
  expect_true(all(res[[1]]$data$split == "grammatical")) # left aura
  expect_true(all(res[[4]]$data$split == "ungrammatical")) # right aura
})

test_that("flip = TRUE swaps which level goes left vs. right", {
  res <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, flip = TRUE)
  expect_true(all(res[[1]]$data$split == "ungrammatical"))
  expect_true(all(res[[4]]$data$split == "grammatical"))
})

test_that("side is actually threaded through to gghalves as l/r, not just reflected in each layer's data", {
  # style = "outline" still includes the base aura layer (style only picks
  # which *extra* SD sub-layer is added on top) - so 2 sub-layers x 3
  # x-groups = 6 draw_group() calls per side, 12 total. All of one side's
  # calls render (added to plot$layers, and drawn) before the other's, so
  # the first 6/last 6 split cleanly by side regardless of sub-layer order.
  applied <- capture_applied_sides(
    ggplot() + geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, style = "outline")
  )
  expect_length(applied$side, 12)
  expect_true(all(applied$side[1:6] == "l"))
  expect_true(all(applied$side[7:12] == "r"))
})

test_that("outline_color defaults to the resolved fill per side, and can be overridden", {
  res <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  expect_equal(res[[3]]$aes_params$colour, colors[1]) # left outline
  expect_equal(res[[6]]$aes_params$colour, colors[2]) # right outline

  res2 <- geom_split_violin_sd(
    aes(x = grp, y = y),
    data = split_fixture, split = split, outline_color = c("black", "white")
  )
  expect_equal(res2[[3]]$aes_params$colour, "black")
  expect_equal(res2[[6]]$aes_params$colour, "white")
})

test_that("fill defaults to the file's `colors` palette and renders as the actual built fill color per side", {
  p <- ggplot(split_fixture, aes(x = grp, y = y)) +
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  b <- ggplot_build(p)
  expect_true(all(b$data[[1]]$fill == colors[1])) # left aura
  expect_true(all(b$data[[4]]$fill == colors[2])) # right aura
})

test_that("an explicit length-2 fill overrides the default palette", {
  p <- ggplot(split_fixture, aes(x = grp, y = y)) +
    geom_split_violin_sd(
      aes(x = grp, y = y),
      data = split_fixture, split = split, fill = c("orange", "purple")
    )
  b <- ggplot_build(p)
  expect_true(all(b$data[[1]]$fill == "orange"))
  expect_true(all(b$data[[4]]$fill == "purple"))
})

test_that("fill/outline_color of the wrong length error clearly", {
  expect_error(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, fill = "steelblue"),
    "length-2"
  )
  expect_error(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, fill = c("a", "b", "c")),
    "length-2"
  )
  expect_error(
    geom_split_violin_sd(
      aes(x = grp, y = y),
      data = split_fixture, split = split, outline_color = "black"
    ),
    "length-2"
  )
})

test_that("the legend dummy layer carries exactly one row per level, in left/right order", {
  res <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  expect_equal(res[[8]]$data$split, c("grammatical", "ungrammatical"))

  res_flip <- geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, flip = TRUE)
  expect_equal(res_flip[[8]]$data$split, c("ungrammatical", "grammatical"))
})

test_that("data = NULL errors clearly instead of failing later inside gghalves", {
  expect_error(
    geom_split_violin_sd(aes(x = grp, y = y), split = split),
    "data"
  )
})

test_that("a split column not present in data errors clearly", {
  expect_error(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = nonexistent_column),
    "nonexistent_column"
  )
})

test_that("a split column with 1 or 3+ levels errors instead of silently picking two", {
  one_level <- split_fixture[split_fixture$split == "grammatical", ]
  expect_error(
    geom_split_violin_sd(aes(x = grp, y = y), data = one_level, split = split),
    "2 levels"
  )

  three_levels <- split_fixture
  three_levels$split[1] <- "other"
  expect_error(
    geom_split_violin_sd(aes(x = grp, y = y), data = three_levels, split = split),
    "2 levels"
  )
})

test_that("NA rows in split are dropped with a warning, not silently or with an error", {
  df <- split_fixture
  df$split[1:3] <- NA
  expect_warning(
    res <- geom_split_violin_sd(aes(x = grp, y = y), data = df, split = split),
    "3 row"
  )
  expect_false(anyNA(res[[1]]$data$split))
  expect_false(anyNA(res[[4]]$data$split))
})

test_that("side/show.legend passed via ... are ignored with a warning, not a duplicate-argument error", {
  expect_warning(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, side = "r"),
    "side"
  )
  expect_warning(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, show.legend = TRUE),
    "show.legend"
  )
})

test_that("alpha/color/linewidth/trim passed via ... still warn, same as the sibling geoms", {
  expect_warning(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, alpha = 0.9),
    "alpha"
  )
  expect_warning(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split, trim = TRUE),
    "trim"
  )
})

test_that("non-reserved stat/geom params (scale, bw, adjust, kernel, na.rm) pass through without warning", {
  expect_no_warning(
    geom_split_violin_sd(
      aes(x = grp, y = y),
      data = split_fixture, split = split,
      scale = "area", bw = "SJ", adjust = 2, kernel = "epanechnikov", na.rm = TRUE
    )
  )
})

test_that("thin/one-sided (x, split) cells warn, balanced cells don't", {
  missing_one_side <- split_fixture[!(split_fixture$grp == "a" & split_fixture$split == "ungrammatical"), ]
  expect_warning(
    geom_split_violin_sd(aes(x = grp, y = y), data = missing_one_side, split = split),
    "missing one side entirely"
  )

  thin_but_present <- split_fixture
  thin_but_present <- thin_but_present[
    -which(thin_but_present$grp == "a" & thin_but_present$split == "ungrammatical")[-1],
  ]
  expect_warning(
    geom_split_violin_sd(aes(x = grp, y = y), data = thin_but_present, split = split),
    "below SD-band minimum"
  )

  expect_no_warning(
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  )
})

test_that("the diagnostic is skipped silently (no error) when x isn't resolvable from this layer's own mapping", {
  # mapping = NULL here - x would only be resolvable via inherit.aes at
  # ggplot_build() time, which this wrapper can't see at construction time.
  expect_no_error(
    geom_split_violin_sd(data = split_fixture, split = split)
  )
})

test_that("builds and renders without error, and facets correctly", {
  p <- ggplot(split_fixture, aes(x = grp, y = y)) +
    geom_split_violin_sd(aes(x = grp, y = y), data = split_fixture, split = split)
  expect_no_error(ggplot_build(p))
  expect_no_error(render_plot(p))

  df <- split_fixture
  df$panel <- rep(c("p1", "p2"), 60)
  p2 <- ggplot(df, aes(x = grp, y = y)) +
    geom_split_violin_sd(aes(x = grp, y = y), data = df, split = split) +
    facet_wrap(~panel)
  expect_no_error(ggplot_build(p2))
})

test_that("a lone half-violin (one side missing entirely for an x-level) still renders without error", {
  df <- split_fixture[!(split_fixture$grp == "a" & split_fixture$split == "ungrammatical"), ]
  p <- suppressWarnings(
    ggplot(df, aes(x = grp, y = y)) +
      geom_split_violin_sd(aes(x = grp, y = y), data = df, split = split)
  )
  expect_no_error(suppressWarnings(ggplot_build(p)))
  expect_no_error(suppressWarnings(render_plot(p)))
})
