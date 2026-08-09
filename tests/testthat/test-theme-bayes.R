test_that("layer_halfeye_hdi() returns the expected 4-element layer/scale/guide list", {
  layers <- layer_halfeye_hdi()
  expect_type(layers, "list")
  expect_length(layers, 4)
  expect_true(inherits(layers[[1]], "LayerInstance")) # stat_slab
  expect_true(inherits(layers[[2]], "LayerInstance")) # stat_pointinterval
  expect_true(inherits(layers[[3]], "ScaleDiscrete")) # scale_fill_manual
  expect_true(inherits(layers[[4]], "Guides")) # guides()
})

test_that("layer_halfeye_hdi() omits `limits` from the stats unless explicitly given", {
  layers_default <- layer_halfeye_hdi()
  expect_null(layers_default[[1]]$stat_params$limits)
  expect_null(layers_default[[2]]$stat_params$limits)

  layers_explicit <- layer_halfeye_hdi(
    slab_limits = c(.15, .85),
    pointinterval_limits = c(0, 1)
  )
  expect_equal(layers_explicit[[1]]$stat_params$limits, c(.15, .85))
  expect_equal(layers_explicit[[2]]$stat_params$limits, c(0, 1))
})

test_that("layer_halfeye_hdi() scale/dodge_width/n/fill_colors/interval_color take effect", {
  layers <- layer_halfeye_hdi(
    scale = 1.4,
    dodge_width = .2,
    n = 777,
    fill_colors = c("red", "blue"),
    interval_color = "green"
  )
  expect_equal(layers[[1]]$aes_params$scale, 1.4)
  expect_equal(layers[[1]]$stat_params$n, 777)
  expect_equal(layers[[2]]$aes_params$colour, "green")
  expect_equal(layers[[3]]$palette(2), c("red", "blue"))
})

test_that("layer_halfeye_hdi()'s `gap` shifts the point-interval away from the slab baseline", {
  d <- data.frame(cond = "true", .value = rnorm(50, 1.5, .3))

  build_x <- function(gap) {
    p <- ggplot(d, aes(x = cond, y = .value)) +
      layer_halfeye_hdi(gap = gap, n = 50)
    b <- ggplot_build(p)
    list(slab_baseline = unique(b$data[[1]]$xmin), interval_x = unique(b$data[[2]]$x))
  }

  no_gap <- build_x(0)
  expect_equal(no_gap$interval_x, no_gap$slab_baseline)

  with_gap <- build_x(.15)
  expect_equal(with_gap$slab_baseline, no_gap$slab_baseline) # baseline unmoved
  expect_equal(with_gap$interval_x, with_gap$slab_baseline - .15)
})

test_that("layer_halfeye_hdi()'s `gap` composes with real dodging (2 groups sharing one x)", {
  d <- data.frame(
    cond = "x",
    grp = rep(c("a", "b"), each = 50),
    .value = c(rnorm(50, -1, .3), rnorm(50, 1, .3))
  )
  p <- ggplot(d, aes(x = cond, y = .value, group = grp)) +
    layer_halfeye_hdi(dodge_width = .4, gap = .15, n = 50)
  b <- ggplot_build(p)
  interval_x <- sort(unique(b$data[[2]]$x))
  expect_length(interval_x, 2) # dodge still separates the two groups
  expect_true(all(interval_x < 1)) # both shifted below the undodged baseline (1) by the gap
})

test_that("`gap` scales with how many categories share a panel, so rendered gap stays a constant fraction of panel height", {
  # Regression test for the actual bug reported: a fixed row-unit gap
  # renders as a comically large fraction of a 1-category-per-panel layout
  # (plot_coef_grid_hdi()) but a barely-visible sliver of an 8-categories-
  # in-one-panel layout (plot_ridge_hdi()) - both structurally normal for
  # those two callers, not a tuning mistake. `gap` should instead be a
  # constant fraction of *panel height*, achieved by scaling the row-unit
  # shift by each panel's own category count.
  make_draws <- function(n_cats) {
    purrr::map_dfr(seq_len(n_cats), function(i) {
      data.frame(cond = paste0("c", i), .value = rnorm(50, i, .2))
    })
  }

  shift_for <- function(n_cats, gap = .02) {
    d <- make_draws(n_cats)
    p <- ggplot(d, aes(x = cond, y = .value)) +
      layer_halfeye_hdi(gap = gap, n = 50)
    b <- ggplot_build(p)
    baseline <- unique(b$data[[1]]$xmin)[1]
    interval_x <- unique(b$data[[2]]$x)[1]
    baseline - interval_x
  }

  shift_n1 <- shift_for(1)
  shift_n8 <- shift_for(8)
  # a fixed row-unit shift (the old behavior) would give shift_n1 ==
  # shift_n8 == gap regardless of category count - the fix requires the
  # shift to scale with N instead
  expect_equal(shift_n1, .02 * 1)
  expect_equal(shift_n8, .02 * 8)
  # as a *fraction of panel height* (shift / n_cats, since panel height is
  # divided evenly across n_cats rows), both should now match
  expect_equal(shift_n1 / 1, shift_n8 / 8)
})

test_that("plot_ridge_hdi() builds without error and honors category_reorder", {
  p_sorted <- plot_ridge_hdi(bayes_draws_fixture, category = cond)
  expect_true(inherits(p_sorted, "ggplot"))
  expect_no_error(ggplot_build(p_sorted))

  p_unsorted <- plot_ridge_hdi(
    bayes_draws_fixture,
    category = cond,
    category_reorder = FALSE
  )
  expect_no_error(ggplot_build(p_unsorted))

  # sorted (descending by mean .value) should NOT reproduce the fixture's
  # original first-appearance order, since the fixture is deliberately not
  # already sorted that way (true-without/false-with have mu = 1.5, the
  # other two mu = 0). The category axis is `x` pre-coord_flip(), so the
  # rendered order lives in the built plot's x (not y) discrete scale.
  labels_sorted <- ggplot_build(p_sorted)$layout$panel_scales_x[[1]]$get_labels()
  labels_unsorted <- ggplot_build(p_unsorted)$layout$panel_scales_x[[1]]$get_labels()
  expect_equal(
    labels_sorted,
    c("false-with", "true-without", "undefined-without", "critical-with")
  )
  expect_equal(
    labels_unsorted,
    c("critical-with", "false-with", "true-without", "undefined-without")
  )
})

test_that("plot_ridge_hdi() adds a facet only when `facet` is supplied", {
  p_no_facet <- plot_ridge_hdi(bayes_draws_fixture, category = cond)
  p_facet <- plot_ridge_hdi(
    bayes_draws_fixture,
    category = cond,
    facet = facet_grp
  )
  expect_true(inherits(p_no_facet$facet, "FacetNull"))
  expect_true(inherits(p_facet$facet, "FacetWrap"))
})

test_that("plot_ridge_hdi() applies value_transform before plotting", {
  p_identity <- plot_ridge_hdi(bayes_draws_fixture, category = cond)
  p_exp <- plot_ridge_hdi(
    bayes_draws_fixture,
    category = cond,
    value_transform = exp
  )
  b_identity <- ggplot_build(p_identity)
  b_exp <- ggplot_build(p_exp)
  # stat_slab's own layer (index 1) computes over the transformed values;
  # `y` holds the continuous draws column pre-coord_flip() (`x` is the
  # discrete category), so it should differ predictably under exp()
  rng_identity <- range(b_identity$data[[1]]$y)
  rng_exp <- range(b_exp$data[[1]]$y)
  expect_false(isTRUE(all.equal(rng_identity, rng_exp)))
  expect_true(all(rng_exp > 0)) # exp() is always positive
})

test_that("plot_ridge_hdi() draws a reference line only when `hline` is given", {
  p_no_line <- plot_ridge_hdi(bayes_draws_fixture, category = cond)
  p_line <- plot_ridge_hdi(bayes_draws_fixture, category = cond, hline = 0)
  expect_length(p_no_line$layers, 2) # slab + pointinterval only
  expect_length(p_line$layers, 3) # geom_hline + slab + pointinterval
  expect_true(inherits(p_line$layers[[1]]$geom, "GeomHline"))
})

test_that("plot_ridge_hdi() sets both base and position-suffixed axis-text elements", {
  # Regression test: theme_mt() (the package's active default theme once
  # theme.R is sourced) sets axis.text.y.left explicitly, which wins over a
  # plain axis.text.y in ggplot2 >= 4.0's theme engine unless this function
  # sets the position-suffixed element too. See the matching comment in
  # theme_bayes.R and theme.R's own note on this.
  p <- plot_ridge_hdi(bayes_draws_fixture, category = cond)
  th <- p$theme
  expect_true(inherits(th$axis.text.y, "element_markdown"))
  expect_true(inherits(th$axis.text.y.left, "element_markdown"))
  expect_equal(th$axis.text.y.left$hjust, 1)
})

test_that("plot_coef_grid_hdi() builds without error, free-scale facets by category", {
  p <- plot_coef_grid_hdi(bayes_coef_fixture, category = coef)
  expect_true(inherits(p, "ggplot"))
  expect_no_error(ggplot_build(p))
  expect_true(inherits(p$facet, "FacetWrap"))
  expect_equal(p$facet$params$free, list(x = TRUE, y = TRUE))
})

test_that("plot_coef_grid_hdi() defaults to hline = 0, overridable/omittable", {
  # geom_hline() stores yintercept in the layer's constant `data`
  # data.frame, not in aes_params/geom_params.
  p_default <- plot_coef_grid_hdi(bayes_coef_fixture, category = coef)
  expect_true(inherits(p_default$layers[[1]]$geom, "GeomHline"))
  expect_equal(p_default$layers[[1]]$data$yintercept, 0)

  p_custom <- plot_coef_grid_hdi(bayes_coef_fixture, category = coef, hline = -1)
  expect_equal(p_custom$layers[[1]]$data$yintercept, -1)

  p_none <- plot_coef_grid_hdi(bayes_coef_fixture, category = coef, hline = NULL)
  expect_false(inherits(p_none$layers[[1]]$geom, "GeomHline"))
})

test_that("plot_coef_grid_hdi() blanks both base and position-suffixed y-axis text", {
  p <- plot_coef_grid_hdi(bayes_coef_fixture, category = coef)
  th <- p$theme
  expect_true(inherits(th$axis.text.y, "element_blank"))
  expect_true(inherits(th$axis.text.y.left, "element_blank"))
  expect_true(inherits(th$axis.text.y.right, "element_blank"))
})

test_that("plot_coef_grid_hdi() doesn't override strip.text.x - falls back to theme_mt()'s own default", {
  # regression test: plot_coef_grid_hdi() used to force strip.text.x to a
  # hardcoded family/size, while plot_ridge_hdi()/plot_location_scale()
  # (which also facet) left it at theme_mt()'s default - confirmed desired
  # resolution was to drop the override here instead of spreading it to
  # the other two, so all faceted plots share one consistent strip look.
  p <- plot_coef_grid_hdi(bayes_coef_fixture, category = coef)
  expect_null(p$theme$strip.text.x)
})

test_that("plot_ridge_hdi()/plot_coef_grid_hdi() pass ... through to layer_halfeye_hdi()", {
  p_ridge <- plot_ridge_hdi(bayes_draws_fixture, category = cond, scale = 1.7)
  expect_equal(p_ridge$layers[[1]]$aes_params$scale, 1.7)

  p_grid <- plot_coef_grid_hdi(bayes_coef_fixture, category = coef, dodge_width = .13)
  # layer order in plot_coef_grid_hdi(): geom_hline (default), then the two
  # layer_halfeye_hdi() layers (stat_slab, stat_pointinterval)
  expect_equal(
    p_grid$layers[[3]]$position$width,
    .13
  )
})
