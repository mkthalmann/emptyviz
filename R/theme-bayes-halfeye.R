# Plot builders for posterior draws, built on ggdist's halfeye layers
# (stat_slab() + stat_pointinterval()). The shared layer bundle is
# layer_halfeye_hdi(); plot_ridge_hdi() stacks categories as rows of one
# shared-scale panel (for comparing the categories themselves), and
# plot_coef_grid_hdi() gives each coefficient a free-scale panel (because
# coefficients differ widely in magnitude).

# stat_pointinterval() under position_dodge() lands on the slab's baseline,
# so slab and interval touch. This position shifts the interval by `gap` as a
# fraction of panel height. A shift in axis units would shrink with the
# number of categories sharing a panel (8 rows in a ridge plot, 1 in a
# coefficient grid), so the shift is multiplied by each panel's category
# count. Categories are recovered by rounding x: dodging moves the groups of
# one category by less than 0.5.
position_dodge_gap <- function(dodge_width, gap, preserve = "single") {
  dodge <- position_dodge(width = dodge_width, preserve = preserve)
  ggproto(
    NULL,
    dodge,
    compute_layer = function(self, data, params, layout) {
      data <- ggproto_parent(dodge, self)$compute_layer(
        data,
        params,
        layout
      )
      category <- round(data$x)
      n_per_panel <- stats::ave(
        category,
        data$PANEL,
        FUN = function(x) length(unique(x))
      )
      shift <- gap * n_per_panel
      data$x <- data$x - shift
      if (!is.null(data$xmin)) data$xmin <- data$xmin - shift
      if (!is.null(data$xmax)) data$xmax <- data$xmax - shift
      data
    }
  )
}

# The dashed reference line of plot_ridge_hdi()/plot_coef_grid_hdi(), drawn
# from its own data so that its default colour can follow the theme
# (geom_hline()'s `yintercept` argument would overwrite the mapping).
.reference_hline <- function(yintercept, colour) {
  spec <- .colour_spec(colour, "colour", mt_colors[2], dark_mt_colors[2])
  .annotation_layer(
    GeomHline,
    data = data.frame(yintercept = yintercept),
    mapping = .merge_aes(aes(yintercept = .data$yintercept), spec$mapping),
    params = c(list(linetype = "dashed", alpha = .5), spec$params)
  )
}

#' The recurring halfeye (HDI slab + ETI point-interval) layer bundle
#'
#' The `stat_slab()`+`stat_pointinterval()` block that recurs, nearly
#' verbatim, across posterior-summary plots: an HDI-shaded density
#' ([ggdist::stat_slab()]) plus a multi-width ETI point-interval
#' ([ggdist::stat_pointinterval()]). Returns a list of layers/scales to add
#' to a `ggplot()` that already has a discrete category on one axis and a
#' continuous draws column on the other - orientation (vertical vs.
#' flipped) is the caller's job via `coord_flip()`, not this function's.
#' Used internally by [plot_ridge_hdi()] and [plot_coef_grid_hdi()]; exposed
#' standalone for building a custom layout around the same visual grammar.
#'
#' `scale` (slab height) and `dodge_width` have no single correct default -
#' pass whatever fits your panel count and coefficient spread.
#'
#' `gap` is how far the point-interval is shifted away from the slab's
#' baseline, as a fraction of panel height, so the same value suits a panel
#' of many categories and a grid of one category per panel. The default
#' `.02` is about 2% of panel height; `0` lets slab and interval touch.
#'
#' @param slab_widths HDI width(s) for the slab shading, passed to
#'   `stat_slab()`'s `.width`.
#' @param interval_widths ETI width(s) for the point-interval, passed to
#'   `stat_pointinterval()`'s `.width`.
#' @param slab_limits,pointinterval_limits Passed through to `stat_slab()`'s/
#'   `stat_pointinterval()`'s own `limits` argument (`NULL` by default, i.e.
#'   ggdist's own auto behavior). Not the same as `value_limits` in
#'   [plot_ridge_hdi()]/[plot_coef_grid_hdi()], which is a real axis-scale
#'   limit.
#' @param scale Slab height, passed to `stat_slab()`.
#' @param dodge_width Dodge width shared by the slab and point-interval.
#' @param gap Point-interval offset from the slab baseline, as a fraction of
#'   panel height (see Details).
#' @param n Passed to `stat_slab()`'s `n` (density resolution), if given.
#' @param point_size Size of the point-interval's point.
#' @param fill Base slab color, ramped by HDI width (see `fill_range`).
#'   `NULL` (default) uses `mt_colors[1]`, or `dark_mt_colors[1]` when the
#'   plot is drawn with a dark theme such as `theme_mt(dark = TRUE)`.
#' @param fill_range Two-value alpha/lightness range (passed to
#'   [ggdist::scale_fill_ramp_discrete()]'s `range`) the slab's HDI widths
#'   are shaded across, from the widest (most faded, closer to white) to
#'   the narrowest (most saturated, `fill` at full strength). Default
#'   `c(.4, 1)`.
#' @param interval_color Color of the point-interval. `NULL` (default)
#'   follows the theme in the same way as `fill`.
#' @return A list of `ggplot2`/`ggdist` layers, scales, and guides.
#' @examples
#' library(ggplot2)
#' set.seed(1)
#' draws <- data.frame(
#'   cond = rep(c("a", "b"), each = 500),
#'   value = c(rnorm(500), rnorm(500, 1))
#' )
#' ggplot(draws, aes(x = cond, y = value)) +
#'   layer_halfeye_hdi() +
#'   coord_flip()
#' @export
layer_halfeye_hdi <- function(
  slab_widths = c(.95, .999),
  interval_widths = c(.5, .9, .95),
  slab_limits = NULL,
  pointinterval_limits = NULL,
  scale = 1,
  dodge_width = .4,
  gap = .02,
  n = NULL,
  point_size = 1.5,
  fill = NULL,
  fill_range = c(.4, 1),
  interval_color = NULL
) {
  slab_fill <- .colour_spec(fill, "fill", mt_colors[1], dark_mt_colors[1])
  interval_colour <- .colour_spec(
    interval_color, "colour", mt_colors[1], dark_mt_colors[1]
  )

  # HDI width is mapped to `fill_ramp`, ggdist's aesthetic for ramping one
  # base colour across discrete levels, rather than to `fill`: a fill scale
  # would be plot-global and collide with any other fill-mapped layer. The
  # slab outline and the interval point's fill take the theme's page colour.
  slab_args <- c(
    list(
      mapping = .merge_aes(
        aes(fill_ramp = after_stat(level)),
        slab_fill$mapping,
        .paper_aes("colour")
      ),
      position = "dodgejust",
      point_interval = ggdist::mean_hdi,
      .width = slab_widths,
      scale = scale,
      linewidth = .1
    ),
    slab_fill$params
  )
  if (!is.null(slab_limits)) slab_args$limits <- slab_limits
  if (!is.null(n)) slab_args$n <- n

  interval_args <- c(
    list(
      mapping = .merge_aes(interval_colour$mapping, .paper_aes("fill")),
      position = position_dodge_gap(dodge_width = dodge_width, gap = gap),
      .width = interval_widths,
      point_size = point_size,
      shape = 22,
      stroke = .1,
      point_interval = ggdist::mean_qi
    ),
    interval_colour$params
  )
  if (!is.null(pointinterval_limits)) {
    interval_args$limits <- pointinterval_limits
  }

  list(
    do.call(ggdist::stat_slab, slab_args),
    do.call(ggdist::stat_pointinterval, interval_args),
    ggdist::scale_fill_ramp_discrete(range = fill_range),
    # guides() is plot-global, so only `fill_ramp`, the one aesthetic this
    # bundle maps to a scale of its own, is hidden. Hiding anything else
    # would remove the legends of other layers in the same plot.
    guides(fill_ramp = "none")
  )
}

#' Ridgeline plot of posterior marginal means/SDs, one row per category
#'
#' Every category stacked as a row in one shared-scale panel (optionally
#' faceted, but with a common axis across facets by default via
#' `facet_scales = "fixed"`) - for when the categories themselves are what's
#' being compared.
#'
#' `category`/`value` are unquoted columns, as in the usual ggplot2 idiom.
#' `value` should be long-format posterior draws (one row per draw per
#' category), e.g. from `tidybayes::gather_emmeans_draws()`.
#'
#' @param data A data frame of long-format posterior draws.
#' @param category Unquoted column identifying each category (one row per
#'   panel/facet row).
#' @param value Unquoted column of posterior draws (default `.value`,
#'   matching `tidybayes::gather_emmeans_draws()`'s own column name).
#' @param facet Optional unquoted column to facet by.
#' @param facet_nrow,facet_ncol,facet_scales Passed to `facet_wrap()` when
#'   `facet` is given.
#' @param hline Optional y-intercept for a dashed reference line (`NULL`
#'   omits it).
#' @param hline_color Color of the reference line. `NULL` (default) uses
#'   `mt_colors[2]`, or `dark_mt_colors[2]` under a dark theme.
#' @param value_transform Applied to `value` before plotting (e.g. `exp` for
#'   a sigma submodel estimated on the log scale).
#' @param value_limits,value_breaks Passed to `scale_y_continuous()`.
#' @param category_reorder `TRUE` (default) sorts categories by the mean of
#'   their transformed `value`, the same mean the point-interval marks, with
#'   the highest mean at the top (as in [plot_bf_forest()]). `FALSE` keeps
#'   the factor-level order `category` already has, with the first level at
#'   the bottom.
#' @param xlab,ylab Axis labels.
#' @param ... Passed through to [layer_halfeye_hdi()].
#' @return A `ggplot` object.
#' @examples
#' ridge_draws <- subset(believe_projection_draws, dpar == "mu")
#' plot_ridge_hdi(ridge_draws, category = scenario)
#' @export
plot_ridge_hdi <- function(
  data,
  category,
  value = .value,
  facet = NULL,
  facet_nrow = NULL,
  facet_ncol = NULL,
  facet_scales = "fixed",
  hline = NULL,
  hline_color = NULL,
  value_transform = identity,
  value_limits = NULL,
  value_breaks = waiver(),
  category_reorder = TRUE,
  xlab = "Parameter",
  ylab = "Posterior marginal means \u00b1HDI<sub>95</sub> \u00b1ETI<sub>50;90;95</sub>",
  ...
) {
  if (missing(category)) {
    stop("plot_ridge_hdi(): `category` is required.", call. = FALSE)
  }
  category_sym <- rlang::ensym(category)
  value_sym <- rlang::ensym(value)
  facet_quo <- rlang::enquo(facet)
  has_facet <- !rlang::quo_is_null(facet_quo)

  x_expr <- if (category_reorder) {
    # Checked now, so that a category without a non-NA value fails with an
    # error naming this function rather than inside forcats at build time
    # (see .check_reorder_values()).
    resolved_value <- tryCatch(
      value_transform(rlang::eval_tidy(value_sym, data)),
      error = function(e) NULL
    )
    resolved_category <- tryCatch(
      rlang::eval_tidy(category_sym, data),
      error = function(e) NULL
    )
    .check_reorder_values(
      values = resolved_value,
      categories = resolved_category,
      fn = "plot_ridge_hdi",
      value_arg = "value",
      reorder_arg = "category_reorder",
      value_note = " (after `value_transform`)"
    )
    rlang::expr(
      forcats::fct_reorder(
        !!category_sym,
        value_transform(!!value_sym),
        .fun = mean
      )
    )
  } else {
    category_sym
  }

  p <- ggplot(
    data,
    aes(x = !!x_expr, y = value_transform(!!value_sym))
  )

  if (!is.null(hline)) {
    p <- p +
      .reference_hline(hline, hline_color)
  }

  p <- p +
    layer_halfeye_hdi(...) +
    scale_x_discrete(expand = c(0, 0)) +
    coord_flip(clip = "off") +
    labs(x = xlab, y = ylab) +
    # Both the base and the position-specific elements are set: ggplot2 4
    # draws axis labels through the position-specific ones, which theme_mt()
    # sets explicitly, so setting only the base element would have no
    # effect. Strips are made markdown-aware without styling them, so that
    # markdown facet labels render under any theme.
    theme(
      panel.grid.minor.y = element_blank(),
      axis.text.y = element_markdown(hjust = 1),
      axis.text.y.left = element_markdown(hjust = 1),
      axis.text.y.right = element_markdown(hjust = 1),
      axis.title.x = element_markdown(),
      axis.title.x.top = element_markdown(),
      axis.text.x = element_markdown(),
      axis.text.x.bottom = element_markdown(),
      axis.text.x.top = element_markdown(),
      strip.text.x = element_markdown(),
      strip.text.x.top = element_markdown()
    )

  if (!is.null(value_limits) || !identical(value_breaks, waiver())) {
    p <- p +
      scale_y_continuous(limits = value_limits, breaks = value_breaks)
  }

  if (has_facet) {
    p <- p +
      facet_wrap(
        vars(!!facet_quo),
        nrow = facet_nrow,
        ncol = facet_ncol,
        scales = facet_scales
      )
  }

  p
}

#' Free-scale grid of posterior coefficients, one panel per category
#'
#' Each category gets its own free-scale panel in a grid - for coefficient
#' posteriors, which differ wildly in natural magnitude, so a shared axis
#' would flatten the small ones.
#'
#' Unlike [plot_ridge_hdi()], the category label is shown as the facet
#' strip, not an axis, so there's no `fct_reorder()` step - pass `category`
#' already in the order you want the facets to appear (e.g. via
#' `forcats::fct_inorder()` on however you built the long-format coefficient
#' draws).
#'
#' @param data A data frame of long-format posterior draws.
#' @param category Unquoted column identifying each coefficient (one facet
#'   panel per level).
#' @param value Unquoted column of posterior draws (default `.value`).
#' @param ncol,nrow Passed to `facet_wrap()`.
#' @param hline Y-intercept for a dashed reference line; defaults to `0`
#'   (the null-effect reference line), pass `NULL` to omit it.
#' @param hline_color Color of the reference line. `NULL` (default) uses
#'   `mt_colors[2]`, or `dark_mt_colors[2]` under a dark theme.
#' @param ylab Axis label.
#' @param ... Passed through to [layer_halfeye_hdi()].
#' @return A `ggplot` object.
#' @examples
#' mu_coef_draws <- subset(believe_projection_coef_draws, dpar == "mu")
#' plot_coef_grid_hdi(mu_coef_draws, category = coef, ncol = 4)
#' @export
plot_coef_grid_hdi <- function(
  data,
  category,
  value = .value,
  ncol = 4,
  nrow = NULL,
  hline = 0,
  hline_color = NULL,
  ylab = "Posterior coefficients \u00b1HDI<sub>95</sub> \u00b1ETI<sub>50;90;95</sub>",
  ...
) {
  if (missing(category)) {
    stop("plot_coef_grid_hdi(): `category` is required.", call. = FALSE)
  }
  category_sym <- rlang::ensym(category)
  value_sym <- rlang::ensym(value)

  p <- ggplot(data, aes(x = !!category_sym, y = !!value_sym))

  if (!is.null(hline)) {
    p <- p +
      .reference_hline(hline, hline_color)
  }

  p +
    layer_halfeye_hdi(...) +
    scale_x_discrete(expand = c(0, 0)) +
    facet_wrap(
      vars(!!category_sym),
      scales = "free",
      ncol = ncol,
      nrow = nrow
    ) +
    coord_flip(clip = "off") +
    labs(y = ylab) +
    # Base and position-specific elements, as in plot_ridge_hdi().
    theme(
      axis.text.y = element_blank(),
      axis.text.y.left = element_blank(),
      axis.text.y.right = element_blank(),
      axis.title.x = element_markdown(),
      axis.title.x.top = element_markdown(),
      axis.title.y = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.minor.y = element_blank(),
      strip.text.x = element_markdown(),
      strip.text.x.top = element_markdown()
    )
}
