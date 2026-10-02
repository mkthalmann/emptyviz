# Discrete shape palette used when plot_location_scale() maps `category` to
# the point glyph itself and there are more categories than ggplot2's own
# default shape scale can handle (6). Solid glyphs first, then open and
# cross forms; see the call site for why this is needed at all.
.mt_shapes <- c(16, 17, 15, 18, 8, 4, 3, 7, 10, 12, 13, 9)

#' Joint (location, scale) scatter with credible ellipses
#'
#' Joint (location, scale) plot: one point + bivariate credible ellipse per
#' condition, for visualizing a hypothesis where location and scale move
#' together, without forcing the reader to cross-reference two separate
#' [plot_ridge_hdi()] calls (one on the location submodel, one on sigma).
#' Optionally overlays a sigma_max ceiling-effect reference curve
#' (`y = sqrt((x - lower)(upper - x))`) so a condition's actual scale can be
#' read directly against the maximum a bounded response scale permits at
#' that location.
#'
#' No custom `Stat` here - the bivariate region is
#' [ggplot2::stat_ellipse()], already in ggplot2 core.
#'
#' `data` must contain PAIRED per-draw location and scale values (one row
#' per category, optionally per `shape`, and per `.draw` - i.e. from the
#' *same* posterior iteration, not two independently-summarized submodels),
#' e.g.:
#' ```r
#' loc <- mod |> emmeans(~condition) |> gather_emmeans_draws()
#' sig <- mod |> emmeans(~condition, dpar = "sigma") |> gather_emmeans_draws()
#' data <- inner_join(loc, sig, by = c(<grouping cols>, ".draw"),
#'                     suffix = c("_location", "_sigma"))
#' ```
#' Paired (not independently-summarized) draws matter here specifically so
#' the ellipse reflects the *joint* uncertainty in a condition's (location,
#' scale) pair, not two unrelated marginal intervals mashed into a fake
#' cross.
#'
#' @param data A data frame of paired per-draw (location, scale) values.
#' @param category Unquoted column identifying each condition - drives color
#'   and (together with `shape`, if given) the ellipse/point grouping.
#' @param location,sigma Unquoted columns holding the per-draw location and
#'   scale values. They have no default because, unlike tidybayes' `.value`,
#'   there is no conventional column name for paired location and scale
#'   draws.
#' @param shape Optional unquoted column (or expression) for a second
#'   crossed factor (e.g. negation) - mapped to the point glyph only
#'   (ellipses have no shape aesthetic); grouping becomes the interaction of
#'   `category` and `shape` when both are given. Supplying this overrides the
#'   `category_shape` default described below.
#' @param category_shape Whether to map `category` to the point glyph as
#'   well as to color when no `shape` column is given (default `TRUE`).
#'   Color, fill and shape then all encode the same variable and merge into
#'   a single legend. The point of the redundancy is that this plot's whole
#'   job is telling conditions apart, and the discrete palette separates
#'   them by hue with very little lightness difference - so hue alone is not
#'   enough under grayscale printing, a monochrome projector, or reduced
#'   color discrimination. Set `FALSE` for color-only points.
#' @param category_linetype Whether to map `category` to the ellipse outline
#'   style as well (default `TRUE`). Only applies when `ellipse_geom =
#'   "path"` - the default `"polygon"` draws no outline at all, so there is
#'   nothing for a linetype to affect.
#' @param facet Optional unquoted column (or expression) to facet by.
#' @param facet_nrow,facet_ncol,facet_scales Passed to `facet_wrap()` when
#'   `facet` is given.
#' @param bounds `c(lower, upper)` - if given, draws the sigma_max reference
#'   curve; `NULL` (default) omits it for a plain joint location-scale plot.
#'   Must be two finite numbers with `lower < upper`; anything else errors
#'   rather than silently producing an all-`NaN` (i.e. invisible) curve.
#' @param bounds_n Number of points used to draw the sigma_max curve.
#' @param location_transform,sigma_transform Applied once, before
#'   aggregation/plotting (e.g. `exp` for a sigma submodel estimated on the
#'   log scale) - the point estimate is `mean(transform(draws))`, not
#'   `transform(mean(draws))`.
#' @param ellipse_level One or more credible levels, each drawn as its own
#'   `stat_ellipse()` layer - default `c(.5, .95)`, a narrow "core" ellipse
#'   plus a wide outer one. Levels are told apart by `ellipse_alpha` alone
#'   (same per-category hue throughout), drawn widest-first so the narrowest
#'   ends up nested visibly on top.
#' @param ellipse_type Passed to `stat_ellipse()`'s `type`.
#' @param ellipse_geom `"polygon"` (default - a shaded region with no
#'   outline) or `"path"` (outline only, no fill; stays legible when many
#'   conditions' ellipses overlap heavily, at the cost of the shaded look).
#' @param ellipse_alpha `NULL` (default) fades from a solid-ish core at the
#'   narrowest level out to a faint band at the widest (flat `.25` if only
#'   one level is requested); pass a single number to use that alpha for
#'   every level, or a vector the same length as the deduped `ellipse_level`
#'   for full manual control.
#' @param point_size Size of the per-condition point.
#' @param curve_color Color of the sigma_max reference curve. `NULL`
#'   (default) uses `mt_colors[2]`, or `dark_mt_colors[2]` under a dark theme
#'   such as `theme_mt(dark = TRUE)`.
#' @param xlab,ylab `NULL` (default) builds a label naming both the
#'   quantity and the uncertainty measure(s) shown; pass a string to
#'   override either.
#' @return A `ggplot` object.
#' @examples
#' set.seed(1)
#' n_draw <- 500
#' # paired per-draw (location, scale) values - see Details for why the
#' # pairing (same .draw per condition) matters
#' paired <- data.frame(
#'   cond = rep(c("a", "b"), each = n_draw),
#'   location = c(rnorm(n_draw), rnorm(n_draw, 1)),
#'   sigma = c(rgamma(n_draw, 10), rgamma(n_draw, 14))
#' )
#' plot_location_scale(paired, category = cond, location = location, sigma = sigma)
#' @export
plot_location_scale <- function(
  data,
  category,
  location,
  sigma,
  shape = NULL,
  category_shape = TRUE,
  category_linetype = TRUE,
  facet = NULL,
  facet_nrow = NULL,
  facet_ncol = NULL,
  facet_scales = "fixed",
  bounds = NULL,
  bounds_n = 512,
  location_transform = identity,
  sigma_transform = identity,
  ellipse_level = c(.5, .95),
  ellipse_type = "norm",
  ellipse_geom = c("polygon", "path"),
  ellipse_alpha = NULL,
  point_size = 2.5,
  curve_color = NULL,
  xlab = NULL,
  ylab = NULL
) {
  if (missing(category)) {
    stop("plot_location_scale(): `category` is required.", call. = FALSE)
  }
  if (missing(location)) {
    stop("plot_location_scale(): `location` is required.", call. = FALSE)
  }
  if (missing(sigma)) {
    stop("plot_location_scale(): `sigma` is required.", call. = FALSE)
  }
  ellipse_geom <- match.arg(ellipse_geom)
  # Reversed or non-finite bounds would produce an all-NaN, invisible
  # sigma_max curve; a reader relies on that curve, so this errors instead.
  if (!is.null(bounds)) {
    if (!is.numeric(bounds) || length(bounds) != 2 ||
          any(!is.finite(bounds)) || bounds[1] >= bounds[2]) {
      stop(
        "plot_location_scale(): `bounds` must be c(lower, upper), two ",
        "finite numbers with lower < upper.",
        call. = FALSE
      )
    }
  }
  if (!is.numeric(ellipse_level) || length(ellipse_level) == 0 ||
        any(!is.finite(ellipse_level)) ||
        any(ellipse_level <= 0 | ellipse_level >= 1)) {
    stop(
      "plot_location_scale(): `ellipse_level` must be one or more ",
      "probabilities between 0 and 1 (e.g. c(.5, .95)), not percentages.",
      call. = FALSE
    )
  }
  if (!is.numeric(bounds_n) || length(bounds_n) != 1 || !is.finite(bounds_n) ||
        bounds_n < 2) {
    stop(
      "plot_location_scale(): `bounds_n` must be a single number of at ",
      "least 2.",
      call. = FALSE
    )
  }
  # Sorted ascending for the axis labels; drawn widest-first (below).
  ellipse_level <- sort(unique(ellipse_level))
  n_levels <- length(ellipse_level)

  # Levels differ by alpha alone: by default from .3 at the narrowest to .12
  # at the widest, or .25 for a single level.
  ellipse_alpha <- ellipse_alpha %||%
    (if (n_levels == 1) .25 else seq(.3, .12, length.out = n_levels))
  if (length(ellipse_alpha) == 1) {
    ellipse_alpha <- rep(ellipse_alpha, n_levels)
  } else if (length(ellipse_alpha) != n_levels) {
    stop(
      "plot_location_scale(): `ellipse_alpha` must have length 1 or the ",
      "same length as the deduped `ellipse_level` (", n_levels, "), not ",
      length(ellipse_alpha), ".",
      call. = FALSE
    )
  }
  if (any(ellipse_alpha < 0 | ellipse_alpha > 1)) {
    stop(
      "plot_location_scale(): `ellipse_alpha` must be between 0 and 1, ",
      "got ", paste(ellipse_alpha[ellipse_alpha < 0 | ellipse_alpha > 1], collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  ellipse_pct <- round(ellipse_level * 100, 1)
  ellipse_pct_str <- paste0(ellipse_pct, "%", collapse = "/")
  ellipse_noun <- if (n_levels > 1) "credible ellipses" else "credible ellipse"
  xlab <- xlab %||%
    sprintf("Posterior marginal mean (\u00b1%s %s)", ellipse_pct_str, ellipse_noun)
  ylab <- ylab %||%
    sprintf(
      "Posterior marginal standard deviation (\u00b1%s %s)",
      ellipse_pct_str,
      ellipse_noun
    )
  category_sym <- rlang::ensym(category)
  location_sym <- rlang::ensym(location)
  sigma_sym <- rlang::ensym(sigma)
  shape_quo <- rlang::enquo(shape)
  has_shape <- !rlang::quo_is_null(shape_quo)
  facet_quo <- rlang::enquo(facet)
  has_facet <- !rlang::quo_is_null(facet_quo)

  # `shape` and `facet` are evaluated once into columns, so that inline
  # expressions (`shape = factor(neg)`) work for the grouping, the point
  # mapping and facet_wrap() alike; as_label() names them in legend and strip.
  plot_data <- data
  plot_data$.location <- location_transform(rlang::eval_tidy(location_sym, data))
  plot_data$.sigma <- sigma_transform(rlang::eval_tidy(sigma_sym, data))
  if (has_shape) {
    plot_data$.shape <- rlang::eval_tidy(shape_quo, data)
  }
  if (has_facet) {
    plot_data$.facet <- rlang::eval_tidy(facet_quo, data)
  }
  shape_label <- if (has_shape) {
    rlang::as_label(rlang::quo_get_expr(shape_quo))
  }

  group_expr <- if (has_shape) {
    rlang::expr(interaction(!!category_sym, .data$.shape, drop = TRUE))
  } else {
    category_sym
  }

  # Also grouped by the facet variable: point_data is separate layer data,
  # and without its facet column each point would be averaged across facets
  # and repeated in every panel.
  group_cols <- c(
    rlang::as_name(category_sym),
    if (has_shape) ".shape",
    if (has_facet) ".facet"
  )
  point_data <- plot_data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::summarise(
      .location = mean(.data$.location),
      .sigma = mean(.data$.sigma),
      .n = dplyr::n(),
      .groups = "drop"
    )

  # stat_ellipse() draws nothing for a group of fewer than 4 points, and its
  # warning names neither the group nor this function.
  thin <- point_data[point_data$.n < 4, , drop = FALSE]
  if (nrow(thin) > 0) {
    ids <- apply(thin[group_cols], 1, paste, collapse = "/")
    warning(
      "plot_location_scale(): ",
      paste0(sQuote(ids, q = FALSE), " (n=", thin$.n, ")", collapse = ", "),
      if (nrow(thin) == 1) " has " else " have ",
      "fewer than 4 paired draws - stat_ellipse() needs 4 to fit an ",
      "ellipse, so no credible region is drawn for ",
      if (nrow(thin) == 1) "it" else "them",
      " (the point still is).",
      call. = FALSE
    )
  }

  mapping <- aes(
    x = .data$.location,
    y = .data$.sigma,
    color = !!category_sym,
    fill = !!category_sym,
    group = !!group_expr
  )
  point_mapping <- mapping
  # An explicit `shape` column wins; otherwise category drives the glyph as
  # well (see `category_shape`). Colour, fill and shape mapped to the same
  # variable with the same title merge into one legend.
  if (has_shape) {
    point_mapping$shape <- rlang::expr(.data$.shape)
  } else if (category_shape) {
    point_mapping$shape <- category_sym
  }

  p <- ggplot(plot_data, mapping)

  if (!is.null(bounds)) {
    curve_x <- seq(bounds[1], bounds[2], length.out = bounds_n)
    curve_data <- data.frame(
      x = curve_x,
      y = sqrt((curve_x - bounds[1]) * (bounds[2] - curve_x))
    )
    curve_colour <- .colour_spec(
      curve_color, "colour", mt_colors[2], dark_mt_colors[2]
    )
    p <- p +
      .annotation_layer(
        GeomLine,
        data = curve_data,
        mapping = .merge_aes(aes(x = .data$x, y = .data$y), curve_colour$mapping),
        params = c(list(linewidth = .7, linetype = "dashed"), curve_colour$params)
      )
  }

  # Widest level first, so the narrowest (most opaque) ellipse is on top.
  draw_order <- order(ellipse_level, decreasing = TRUE)
  for (i in draw_order) {
    ellipse_args <- list(
      geom = ellipse_geom,
      level = ellipse_level[i],
      type = ellipse_type,
      linewidth = .6,
      alpha = ellipse_alpha[i]
    )
    if (ellipse_geom == "polygon") {
      # No outline; the fill stays mapped to category.
      ellipse_args$colour <- NA
    } else if (category_linetype) {
      # Outline-only ellipses get linetype as a second non-colour channel,
      # mapped on this layer so it does not reach other layers; with the same
      # variable and title it joins the single legend.
      ellipse_args$mapping <- aes(linetype = !!category_sym)
    }
    p <- p + do.call(stat_ellipse, ellipse_args)
  }

  # ggplot2's default shape scale stops at 6 values (further levels get no
  # point) and puts an open `+` fourth. `.mt_shapes` has twelve, filled forms
  # first, and cycles beyond that. A caller's own shape scale replaces it.
  if (!has_shape && category_shape) {
    n_categories <- length(unique(stats::na.omit(
      plot_data[[rlang::as_name(category_sym)]]
    )))
    p <- p + scale_shape_manual(values = rep_len(.mt_shapes, n_categories))
  }

  p <- p +
    geom_point(data = point_data, mapping = point_mapping, size = point_size) +
    labs(
      x = xlab,
      y = ylab,
      color = rlang::as_name(category_sym),
      fill = rlang::as_name(category_sym),
      # NULL for an aesthetic nothing maps, or ggplot2 prints "Ignoring
      # unknown labels" for it on every build.
      linetype = if (ellipse_geom == "path" && category_linetype) {
        rlang::as_name(category_sym)
      },
      shape = if (has_shape) {
        shape_label
      } else if (category_shape) {
        rlang::as_name(category_sym)
      }
    ) +
    # Both axis titles carry user-settable labels, so both are made
    # markdown-aware (base and position-specific elements, as in
    # plot_ridge_hdi()), as are the facet strips.
    theme(
      axis.title.x = element_markdown(),
      axis.title.x.top = element_markdown(),
      axis.title.y = element_markdown(),
      axis.title.y.right = element_markdown(),
      strip.text.x = element_markdown(),
      strip.text.x.top = element_markdown()
    )

  if (has_facet) {
    p <- p +
      facet_wrap(
        vars(.data$.facet),
        nrow = facet_nrow,
        ncol = facet_ncol,
        scales = facet_scales
      )
  }

  p
}
