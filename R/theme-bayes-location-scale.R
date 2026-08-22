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
#'   scale values. No default - unlike [layer_halfeye_hdi()]'s `value =
#'   .value` (a real tidybayes convention), there's no equivalent
#'   widely-used column name for a paired location/sigma draw, so a
#'   same-named default (`location = location`) would only "work" by
#'   coincidence when the caller's data happens to have columns literally
#'   called `location`/`sigma` - and crash with a cryptic R-level
#'   "recursive default argument reference" error otherwise, since looking
#'   up the unmatched symbol falls through to the function's own unforced
#'   argument promise of the same name. Always pass both explicitly.
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
#' @param curve_color Color of the sigma_max reference curve; defaults to
#'   `mt_colors[2]`.
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
  # `bounds` used to flow straight into seq() and sqrt() unchecked. Reversed
  # bounds (c(100, 0)) made sqrt() of a negative product, i.e. an all-NaN
  # curve that built with no error and no warning - the reference curve just
  # wasn't there, with nothing to tell the reader why. A scalar produced
  # seq()'s "'to' must be a finite number", naming an argument the caller
  # never passed. The sigma_max curve is a ceiling reference a reader draws
  # real conclusions from, so silently omitting it is worse than erroring.
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
  # sorted ascending for the label text below, but drawn widest-first (see
  # the stat_ellipse() loop below) so the narrowest (highest-alpha) interval
  # ends up on top, nested visually inside the wider ones rather than any
  # random draw-order overlap.
  ellipse_level <- sort(unique(ellipse_level))
  n_levels <- length(ellipse_level)

  # multiple levels are told apart by alpha alone (same per-category hue for
  # all of them) - default fades from a solid-ish core at the narrowest
  # level out to a faint outer band at the widest, evenly spaced; a single
  # level keeps the old flat .25. Pass a scalar to apply one alpha to every
  # level, or a vector the same length as (the deduped, sorted)
  # `ellipse_level` for full manual control.
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

  curve_color <- curve_color %||% mt_colors[2]

  # `shape`/`facet` are materialized into their own columns rather than
  # referenced by name. rlang::as_name() (used below for the grouping) needs
  # a bare symbol, so an inline expression - `shape = factor(neg)`, which
  # every other tidyeval argument in this package accepts - died with
  # rlang's "Can't convert a call to a string", naming neither this function
  # nor the argument. Evaluating once here means the grouping, the point
  # mapping and facet_wrap() all refer to a real column, whatever the caller
  # passed; rlang::as_label() then builds the legend/strip title from
  # arbitrary expressions where as_name() throws.
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

  # must also group by the facet variable (when given), or the aggregated
  # point collapses across facet levels and then gets replicated
  # identically into every panel - ggplot2 facets a layer by whatever facet
  # column(s) exist in *that layer's own* data, and point_data is a
  # separate data set from the main (already-faceted-correctly) plot data.
  # Confirmed via ggplot_build(): without this, two facets with genuinely
  # different per-facet means for the same category both showed the same
  # (wrong, cross-facet-averaged) point.
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

  # stat_ellipse() needs at least 4 points per group; below that it warns
  # "Too few points to calculate an ellipse" - once per ellipse layer, so
  # 2-3 times by default - and quietly draws nothing for that group, naming
  # neither the offending condition nor this function. Say which condition
  # it is, once, before the build gets there.
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
  # An explicit `shape` column wins; otherwise category itself drives the
  # glyph, so the plot doesn't rest on hue alone (see `category_shape`).
  # Mapping color, fill and shape to the same variable with the same title
  # makes ggplot2 merge all three into one legend rather than adding a
  # second key block.
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
    p <- p +
      geom_line(
        data = curve_data,
        mapping = aes(x = .data$x, y = .data$y),
        inherit.aes = FALSE,
        color = curve_color,
        linewidth = .7,
        linetype = "dashed"
      )
  }

  # widest level first, narrowest last, so the narrowest (highest-alpha)
  # ellipse renders on top of the others instead of getting buried under a
  # wider one added afterward.
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
      # a literal (not mapped) colour = NA override drops the border
      # entirely, leaving a plain shaded region - fill stays mapped to
      # category via the inherited top-level aes(), so the shading itself
      # is still colored per condition.
      ellipse_args$colour <- NA
    } else if (category_linetype) {
      # "path" ellipses are outline-only, so the outline's dash pattern is
      # a second non-color channel available for free. Mapped on this layer
      # rather than in the top-level aes() so it reaches the ellipses
      # without leaking into any other inheriting layer. Same variable and
      # title as color/fill/shape, so it merges into the one legend.
      ellipse_args$mapping <- aes(linetype = !!category_sym)
    }
    p <- p + do.call(stat_ellipse, ellipse_args)
  }

  # An explicit shape scale rather than ggplot2's default, for two reasons.
  # First, the default stops at 6 values: past that it warns and hands back
  # NA for the extra levels, i.e. silently undrawn points - and since
  # category-to-shape is a default here rather than something the caller
  # asked for, it has to survive a 7+-category plot on its own. Second, the
  # default mixes solid and open glyphs early (its fourth value is a thin
  # `+`), which reads noticeably weaker next to the three filled ones at
  # this point size. `.mt_shapes` keeps the filled forms together at the
  # front. Past twelve it cycles, which is no worse than what the five-hue
  # palette already does at that many categories. A caller who adds their
  # own scale_shape_*() on top replaces this one, with ggplot2's usual
  # "Scale for shape is already present" message.
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
    # unlike plot_ridge_hdi()/plot_coef_grid_hdi(), there's no coord_flip()
    # here, so both axis titles (not just x) carry a user-settable label -
    # forced to element_markdown() (base + position-suffixed forms, see
    # plot_ridge_hdi()'s own comment on why both are needed) so a custom
    # xlab/ylab containing markdown/HTML doesn't silently render as literal
    # tags. Neither default label uses markdown today, so this is
    # future-proofing, not a fix for a currently-visible bug.
    theme(
      axis.title.x = element_markdown(),
      axis.title.x.top = element_markdown(),
      axis.title.y = element_markdown(),
      axis.title.y.right = element_markdown()
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
