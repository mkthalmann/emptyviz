test_that("plot_location_scale() builds without error and returns shaded ellipse (polygon) layers + a point layer by default", {
  p <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
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
  p <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
  th <- p$theme
  expect_true(inherits(th$axis.title.x, "element_markdown"))
  expect_true(inherits(th$axis.title.x.top, "element_markdown"))
  expect_true(inherits(th$axis.title.y, "element_markdown"))
  expect_true(inherits(th$axis.title.y.right, "element_markdown"))
})

test_that("every default ellipse layer has no outline (a literal colour = NA override, not mapped)", {
  p <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  expect_length(ellipse_layers, 2)
  for (l in ellipse_layers) expect_equal(l$aes_params$colour, NA)
})

test_that("default ellipse_level = c(.5, .95) draws widest-first with the narrowest level at the highest alpha", {
  p <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  levels <- unname(sapply(ellipse_layers, function(l) l$stat_params$level))
  alphas <- unname(sapply(ellipse_layers, function(l) l$aes_params$alpha))
  expect_equal(levels, c(.95, .5)) # widest drawn first
  expect_equal(alphas, c(.12, .3)) # narrowest (last-drawn) gets the higher alpha
})

test_that("a single ellipse_level reproduces the old one-ellipse behavior with flat alpha = .25", {
  p <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma, ellipse_level = .95)
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  expect_length(ellipse_layers, 1)
  expect_equal(ellipse_layers[[1]]$aes_params$alpha, .25)
})

test_that("ellipse_alpha errors on a length mismatched with the deduped ellipse_level", {
  expect_error(
    plot_location_scale(
      location_scale_fixture,
      category = category, location = location, sigma = sigma,
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
      category = category, location = location, sigma = sigma,
      ellipse_level = .95,
      ellipse_alpha = 1.5
    ),
    "1.5"
  )
  expect_error(
    plot_location_scale(
      location_scale_fixture,
      category = category, location = location, sigma = sigma,
      ellipse_level = c(.5, .95),
      ellipse_alpha = c(.2, -.1)
    ),
    "-0.1|-.1"
  )
})

test_that("a scalar ellipse_alpha applies to every level", {
  p <- plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma,
    ellipse_level = c(.5, .95),
    ellipse_alpha = .3
  )
  ellipse_layers <- Filter(function(l) inherits(l$geom, "GeomPolygon"), p$layers)
  alphas <- unname(sapply(ellipse_layers, function(l) l$aes_params$alpha))
  expect_equal(alphas, c(.3, .3))
})

test_that("the default xlab/ylab name every ellipse_level shown, pluralizing only when there's more than one", {
  p_multi <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
  expect_match(p_multi$labels$x, "50%/95% credible ellipses", fixed = TRUE)

  p_single <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma, ellipse_level = .95)
  expect_match(p_single$labels$x, "95% credible ellipse)", fixed = TRUE)
  expect_no_match(p_single$labels$x, "ellipses")
})

test_that("`bounds` adds a sigma_max reference curve layer with the right shape", {
  p_no_bounds <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
  p_bounds <- plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma,
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
    category = category, location = location, sigma = sigma,
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
  p <- plot_location_scale(d, category = category, location = location, sigma = sigma, shape = negation)
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
  p_poly <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
  p_path <- plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma,
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
    category = category, location = location, sigma = sigma,
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
  p <- plot_location_scale(location_scale_fixture, category = category, location = location, sigma = sigma)
  expect_false(any(sapply(p$layers, function(l) inherits(l$geom, "GeomLine"))))
})

test_that("independently-summarized (unpaired) data still builds - the documented misuse case - but the ellipse genuinely differs from paired data", {
  # Backs the roxygen's own extensive warning (see plot_location_scale()'s
  # Details) that data must be paired per-draw, not independently
  # summarized, or the ellipse only reflects two unrelated marginals mashed
  # together - previously asserted only in prose, with no test confirming
  # (a) it doesn't error, since that's a real, deliberately-supported case,
  # and (b) the ellipse actually is different, not silently identical
  # regardless of pairing.
  set.seed(42)
  n <- 300
  paired <- data.frame(
    category = "a",
    location = rnorm(n),
    sigma = NA_real_
  )
  paired$sigma <- 0.6 * paired$location + rnorm(n, 0, .3) # genuine per-draw correlation
  unpaired <- paired
  unpaired$sigma <- sample(unpaired$sigma) # break the pairing; same marginal distribution

  p_paired <- plot_location_scale(paired, category = category, location = location, sigma = sigma, ellipse_level = .95)
  p_unpaired <- plot_location_scale(unpaired, category = category, location = location, sigma = sigma, ellipse_level = .95)

  expect_no_error(ggplot_build(p_paired))
  expect_no_error(ggplot_build(p_unpaired))

  ellipse_idx <- which(sapply(p_paired$layers, function(l) inherits(l$geom, "GeomPolygon")))
  b_paired <- ggplot_build(p_paired)$data[[ellipse_idx]]
  b_unpaired <- ggplot_build(p_unpaired)$data[[ellipse_idx]]
  # stat_ellipse()'s Cholesky-based parameterization makes the ellipse's
  # x-coordinates depend only on location's own variance (unchanged by the
  # shuffle) - y is where the correlation/covariance term (destroyed by
  # the shuffle) actually shows up, so that's the meaningful comparison.
  expect_false(isTRUE(all.equal(b_paired$y, b_unpaired$y)))
})

test_that("`bounds` is validated instead of silently producing an invisible curve", {
  base_args <- list(
    location_scale_fixture,
    category = rlang::sym("category"),
    location = rlang::sym("location"),
    sigma = rlang::sym("sigma")
  )
  build <- function(bounds) {
    rlang::inject(plot_location_scale(!!!base_args, bounds = bounds))
  }

  # Reversed bounds used to reach sqrt() of a negative product, i.e. an
  # all-NaN curve. It built with no error and no warning - the reference
  # curve simply wasn't there, and nothing said why.
  expect_error(build(c(100, 0)), "lower < upper", fixed = TRUE)
  expect_error(build(c(2, 2)), "lower < upper", fixed = TRUE)
  # a scalar used to surface as seq()'s "'to' must be a finite number",
  # naming an argument the caller never passed
  expect_error(build(5), "`bounds` must be c(lower, upper)", fixed = TRUE)
  expect_error(build(c(0, NA)), "finite", fixed = TRUE)
  expect_error(build(c(0, Inf)), "finite", fixed = TRUE)
  expect_error(build(c("a", "b")), "`bounds` must be c(lower, upper)", fixed = TRUE)

  # the valid case still draws a curve with no NaN in it
  p <- build(c(-2, 2))
  curve <- ggplot_build(p)$data[[1]]
  expect_false(anyNA(curve$y))
})

test_that("`shape` and `facet` accept an inline expression, not only a bare column", {
  # rlang::as_name() needs a symbol, so `shape = factor(neg)` used to die
  # with "Can't convert a call to a string" - naming neither this function
  # nor the argument, and inconsistent with every other tidyeval argument in
  # the package. as_label() handles arbitrary expressions.
  d <- location_scale_fixture
  d$negation <- rep(c("with", "without"), length.out = nrow(d))

  expect_no_error(ggplot_build(plot_location_scale(
    d,
    category = category, location = location, sigma = sigma,
    shape = factor(negation)
  )))
  expect_no_error(ggplot_build(plot_location_scale(
    d,
    category = category, location = location, sigma = sigma,
    facet = factor(negation)
  )))

  # and the expression becomes the legend title
  p <- plot_location_scale(
    d,
    category = category, location = location, sigma = sigma,
    shape = factor(negation)
  )
  expect_equal(p$labels$shape, "factor(negation)")
})

test_that("`shape` given as a local variable resolves against the caller, not the data", {
  # point_mapping$shape used to be assigned a bare expression rather than a
  # quosure, discarding the caller's environment - the sibling code in
  # geom-violin-sd.R documents why that's the wrong move. Materializing the
  # quosure up front sidesteps it entirely.
  d <- location_scale_fixture
  d$negation <- rep(c("with", "without"), length.out = nrow(d))
  local_shape <- rep(c("p", "q"), length.out = nrow(d))

  p <- plot_location_scale(
    d,
    category = category, location = location, sigma = sigma,
    shape = local_shape
  )
  b <- ggplot_build(p)
  point_layer <- Find(function(l) inherits(l$geom, "GeomPoint"), p$layers)
  # 2 categories x 2 local levels = 4 points, i.e. the local vector really
  # was used for grouping rather than a same-named column being looked up
  expect_equal(nrow(b$data[[length(b$data)]]), 4L)
  expect_true("shape" %in% names(rlang::get_expr(point_layer$mapping)))
})

test_that("a group with fewer than 4 paired draws warns by name instead of only through stat_ellipse()", {
  set.seed(7)
  d <- rbind(
    location_scale_fixture,
    data.frame(
      category = "thin",
      trigger = "t1",
      .draw = 1:3,
      location = rnorm(3),
      sigma = rgamma(3, 10)
    )
  )
  expect_warning(
    plot_location_scale(d, category = category, location = location, sigma = sigma),
    "'thin' (n=3)",
    fixed = TRUE
  )
  expect_no_warning(
    plot_location_scale(
      location_scale_fixture,
      category = category, location = location, sigma = sigma
    )
  )
})

test_that("category drives the point shape by default, so the plot doesn't rest on hue alone", {
  # Finding #7 in the review: the discrete palette separates categories by
  # hue with almost no lightness difference (every pair in mt_colors5 is
  # under the 3:1 WCAG 1.4.11 threshold), and this plot maps category to
  # colour and fill and nothing else - so a reader who can't resolve hue
  # couldn't tell the ellipses apart at all. The palette is deliberately
  # unchanged; the redundant channel is the fix.
  p <- plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma
  )
  point_layer <- Find(function(l) inherits(l$geom, "GeomPoint"), p$layers)
  expect_true("shape" %in% names(rlang::get_expr(point_layer$mapping)))
  b <- ggplot_build(p)
  expect_gt(length(unique(b$data[[length(b$data)]]$shape)), 1L)

  # colour, fill and shape all name the same variable, so they merge into
  # one legend rather than adding a second key block
  expect_equal(n_legend_boxes(p), 1L)

  # and it stays opt-out
  off <- plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma,
    category_shape = FALSE
  )
  off_points <- Find(function(l) inherits(l$geom, "GeomPoint"), off$layers)
  expect_false("shape" %in% names(rlang::get_expr(off_points$mapping)))

  # an explicit `shape` column still wins over the default
  d <- location_scale_fixture
  d$negation <- rep(c("with", "without"), length.out = nrow(d))
  explicit <- plot_location_scale(
    d,
    category = category, location = location, sigma = sigma, shape = negation
  )
  expect_equal(explicit$labels$shape, "negation")
})

test_that("the default category-shape mapping survives more categories than ggplot2's 6-shape palette", {
  # ggplot2's default discrete shape scale warns past 6 values and hands
  # back NA for the rest - i.e. silently undrawn points. Since the mapping
  # is a default here rather than something the caller asked for, it has to
  # cope on its own.
  set.seed(3)
  k <- 8
  d <- data.frame(
    category = rep(letters[seq_len(k)], each = 40),
    location = rnorm(k * 40),
    sigma = rgamma(k * 40, 10)
  )
  expect_no_warning(
    b <- ggplot_build(plot_location_scale(
      d,
      category = category, location = location, sigma = sigma
    ))
  )
  point_data <- b$data[[length(b$data)]]
  expect_false(anyNA(point_data$shape))
  expect_equal(length(unique(point_data$shape)), k)
})

test_that("ellipse_geom = 'path' maps category to linetype as a second non-colour channel", {
  p <- plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma,
    ellipse_geom = "path"
  )
  b <- ggplot_build(p)
  expect_gt(length(unique(b$data[[1]]$linetype)), 1L)
  # still one merged legend, not a separate linetype key block
  expect_equal(n_legend_boxes(p), 1L)

  off <- plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma,
    ellipse_geom = "path", category_linetype = FALSE
  )
  expect_equal(length(unique(ggplot_build(off)$data[[1]]$linetype)), 1L)

  # the default polygon geom draws no outline at all, so nothing to style -
  # and no stray "Ignoring unknown labels" for an unmapped linetype
  expect_null(plot_location_scale(
    location_scale_fixture,
    category = category, location = location, sigma = sigma
  )$labels$linetype)
})
