test_that("plot_location_scale() builds without error and returns shaded ellipse (polygon) layers + a point layer by default", {
  p <- plot_location_scale(location_scale_fixture, category = category)
  expect_true(inherits(p, "ggplot"))
  expect_no_error(ggplot_build(p))
  layer_geoms <- unname(sapply(p$layers, function(l) class(l$geom)[1]))
  # default ellipse_level = c(.5, .95) -> two nested ellipse layers (widest
  # drawn first, so it ends up underneath), then the point layer
  expect_equal(layer_geoms, c("GeomPolygon", "GeomPolygon", "GeomPoint"))
})

test_that("plot_location_scale() forces both axis titles to element_markdown() (base + position-suffixed)", {
  # unlike plot_ridge_hdi()/plot_coef_grid_hdi(), there's no coord_flip()
  # here, so a custom xlab AND a custom ylab can each land on their own
  # axis directly - both need guarding against ggplot2's theme engine
  # dropping markdown when only the base (not position-suffixed) element
  # is set explicitly.
  p <- plot_location_scale(location_scale_fixture, category = category)
  th <- p$theme
  expect_true(inherits(th$axis.title.x, "element_markdown"))
  expect_true(inherits(th$axis.title.x.top, "element_markdown"))
  expect_true(inherits(th$axis.title.y, "element_markdown"))
  expect_true(inherits(th$axis.title.y.right, "element_markdown"))
})

test_that("every default ellipse layer has no outline (a literal colour = NA override, not mapped)", {
  p <- plot_location_scale(location_scale_fixture, category = category)
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  expect_length(ellipse_layers, 2)
  for (l in ellipse_layers) expect_equal(l$aes_params$colour, NA)
})

test_that("default ellipse_level = c(.5, .95) draws widest-first with the narrowest level at the highest alpha", {
  p <- plot_location_scale(location_scale_fixture, category = category)
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  levels <- unname(sapply(ellipse_layers, function(l) l$stat_params$level))
  alphas <- unname(sapply(ellipse_layers, function(l) l$aes_params$alpha))
  expect_equal(levels, c(.95, .5)) # widest drawn first
  expect_equal(alphas, c(.12, .3)) # narrowest (last-drawn) gets the higher alpha
})

test_that("a single ellipse_level reproduces the old one-ellipse behavior with flat alpha = .25", {
  p <- plot_location_scale(location_scale_fixture, category = category, ellipse_level = .95)
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  expect_length(ellipse_layers, 1)
  expect_equal(ellipse_layers[[1]]$aes_params$alpha, .25)
})

test_that("ellipse_alpha errors on a length mismatched with the deduped ellipse_level", {
  expect_error(
    plot_location_scale(
      location_scale_fixture,
      category = category,
      ellipse_level = c(.5, .8, .95),
      ellipse_alpha = c(.1, .2)
    ),
    "length"
  )
})

test_that("ellipse_alpha errors clearly on out-of-range values, naming the offender(s)", {
  expect_error(
    plot_location_scale(
      location_scale_fixture,
      category = category,
      ellipse_level = .95,
      ellipse_alpha = 1.5
    ),
    "1.5"
  )
  expect_error(
    plot_location_scale(
      location_scale_fixture,
      category = category,
      ellipse_level = c(.5, .95),
      ellipse_alpha = c(.2, -.1)
    ),
    "-0.1|-.1"
  )
})

test_that("a scalar ellipse_alpha applies to every level", {
  p <- plot_location_scale(
    location_scale_fixture,
    category = category,
    ellipse_level = c(.5, .95),
    ellipse_alpha = .3
  )
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  alphas <- unname(sapply(ellipse_layers, function(l) l$aes_params$alpha))
  expect_equal(alphas, c(.3, .3))
})

test_that("the default xlab/ylab name every ellipse_level shown, pluralizing only when there's more than one", {
  p_multi <- plot_location_scale(location_scale_fixture, category = category)
  expect_match(p_multi$labels$x, "50%/95% credible ellipses", fixed = TRUE)

  p_single <- plot_location_scale(location_scale_fixture, category = category, ellipse_level = .95)
  expect_match(p_single$labels$x, "95% credible ellipse)", fixed = TRUE)
  expect_no_match(p_single$labels$x, "ellipses")
})

test_that("`bounds` adds a sigma_max reference curve layer with the right shape", {
  p_no_bounds <- plot_location_scale(location_scale_fixture, category = category)
  p_bounds <- plot_location_scale(
    location_scale_fixture,
    category = category,
    bounds = c(-2, 2)
  )
  expect_length(p_no_bounds$layers, 3)
  expect_length(p_bounds$layers, 4)
  expect_true(inherits(p_bounds$layers[[1]]$geom, "GeomLine"))

  curve_data <- p_bounds$layers[[1]]$data
  expect_equal(range(curve_data$x), c(-2, 2))
  # y = sqrt((x-lower)(upper-x)): 0 at both bounds, max (upper-lower)/2 at
  # the midpoint
  expect_equal(curve_data$y[curve_data$x == -2], 0)
  expect_equal(curve_data$y[curve_data$x == 2], 0)
  expect_equal(max(curve_data$y), 2, tolerance = 1e-2) # bounds_n grid, not exactly at 0
})

test_that("point_data respects faceting - a category's point differs correctly across facet levels", {
  # regression test for the actual bug found during development: without
  # grouping point_data by the facet variable too, both facets showed the
  # same (wrong, cross-facet-averaged) point for a given category.
  p <- plot_location_scale(
    location_scale_fixture,
    category = category,
    facet = trigger,
    bounds = c(-2, 2)
  )
  b <- ggplot_build(p)
  # curve, then 2 ellipse levels, then point - found by geom class rather
  # than a hardcoded index so this doesn't silently break again if the
  # ellipse layer count changes.
  point_idx <- which(sapply(p$layers, function(l) inherits(l$geom, "GeomPoint")))
  point_layer <- b$data[[point_idx]]
  by_panel <- split(point_layer$x, point_layer$PANEL)
  expect_false(isTRUE(all.equal(sort(by_panel[["1"]]), sort(by_panel[["2"]]))))
  # t1 means are negative, t2 means are positive (see fixture) - check the
  # sign lines up per panel, not just "differs"
  expect_true(all(by_panel[["1"]] < 0))
  expect_true(all(by_panel[["2"]] > 0))
})

test_that("`shape` maps a second factor onto the point layer and groups ellipses by the interaction", {
  d <- location_scale_fixture
  d$negation <- rep(c("with", "without"), length.out = nrow(d))
  p <- plot_location_scale(d, category = category, shape = negation)
  b <- ggplot_build(p)
  # 2 categories x 2 negation levels = 4 distinct ellipse groups
  ellipse_groups <- unique(b$data[[1]]$group)
  expect_length(ellipse_groups, 4)
  # shape aesthetic reached the point layer (found by geom class, not a
  # hardcoded index, since the default now draws 2 ellipse layers first)
  point_layer <- Find(function(l) inherits(l$geom, "GeomPoint"), p$layers)
  expect_true("shape" %in% names(rlang::get_expr(point_layer$mapping)))
})

test_that("`ellipse_geom` switches between polygon (default) and path", {
  p_poly <- plot_location_scale(location_scale_fixture, category = category)
  p_path <- plot_location_scale(
    location_scale_fixture,
    category = category,
    ellipse_geom = "path"
  )
  expect_true(inherits(p_poly$layers[[1]]$geom, "GeomPolygon"))
  expect_true(inherits(p_path$layers[[1]]$geom, "GeomPath"))
  # "path" has no fill, so it must NOT get the polygon-only colour = NA
  # override, or the outline would vanish along with the (nonexistent) fill
  expect_null(p_path$layers[[1]]$aes_params$colour)
})

test_that("location_transform/sigma_transform apply before aggregation (mean-of-transform, not transform-of-mean)", {
  # matches plot_ridge_hdi()'s established value_transform convention
  p <- plot_location_scale(
    location_scale_fixture,
    category = category,
    sigma_transform = exp
  )
  b <- ggplot_build(p)
  point_idx <- which(sapply(p$layers, function(l) inherits(l$geom, "GeomPoint")))
  point_layer <- b$data[[point_idx]]

  expected <- location_scale_fixture |>
    dplyr::group_by(category) |>
    dplyr::summarise(y = mean(exp(sigma)), .groups = "drop") |>
    dplyr::arrange(category)

  actual <- point_layer[order(point_layer$colour %||% point_layer$group), ] # order-agnostic compare below
  expect_equal(sort(round(point_layer$y, 6)), sort(round(expected$y, 6)))
})

test_that("bounds = NULL (default) omits the sigma_max curve", {
  p <- plot_location_scale(location_scale_fixture, category = category)
  expect_false(any(sapply(p$layers, function(l) inherits(l$geom, "GeomLine"))))
})
