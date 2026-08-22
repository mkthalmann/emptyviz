# Visualization helpers for Bayesian distributional models (location + scale
# submodels fit via brms), built on top of ggdist's halfeye machinery
# (stat_slab() + stat_pointinterval()) and styled to match theme.R's
# theme_mt()/`mt_colors` palette.
#
# Motivated by believe-projection/scripts/belproj-paper.R, which builds the
# same stat_slab()+stat_pointinterval() "halfeye ridgeline" block four times
# by hand: once for posterior marginal means (location), once for posterior
# marginal SDs (scale, modeled on the log scale), and twice more for two
# grids of raw brms coefficients. All four share one visual grammar (an
# HDI-shaded density plus a multi-width ETI point-interval per category) but
# split into two different *layouts*: the marginal-means/SDs plots stack
# every category as rows in one shared-scale panel, because the categories
# themselves are what's being compared and a shared axis matters for that;
# the coefficient grids give each coefficient its own free-scale panel,
# because coefficients differ wildly in natural magnitude and a shared axis
# would flatten the small ones. Rather than force both into one geom, the
# shared block is factored into layer_halfeye_hdi() and each layout gets its
# own thin wrapper (plot_ridge_hdi(), plot_coef_grid_hdi()).

# stat_slab()'s density is drawn from a baseline (its own dodge slot's edge)
# growing outward by `thickness * scale`; stat_pointinterval(), positioned
# via plain position_dodge(), lands exactly on that same baseline - hence
# the slab and the point-interval visually touch with zero gap between them
# (verified via ggplot_build(): both layers' x sit at the identical dodge
# position). position_dodge() alone can't add a gap - dodge only spreads
# *sibling* groups sharing one x apart from each other, it has no concept of
# "push this glyph away from that one".
#
# A *fixed* row-unit shift is the wrong invariant to hold, though: a panel's
# rendered height is divided among however many categories share it, so "1
# row-unit" is panel_height/N of the actual rendered space - tiny for
# plot_ridge_hdi()'s typical N=8 categories stacked in one panel, but the
# *entire* panel for plot_coef_grid_hdi()'s free-scale grid, which puts
# exactly one category (one glyph) per panel. A single fixed `gap` in
# row-units therefore renders as a barely-there sliver in the first case and
# a comically large gap in the second (confirmed both ways via
# ggplot_build() + rendering: N is 8 vs. 1 in those two callers'
# PANEL-grouped x values). `gap` here is instead a target fraction of *panel
# height*, made constant regardless of N by counting each panel's own
# category count (via its rows' rounded, pre-shift x - dodge sub-spreads a
# shared category's groups by less than 0.5, so rounding safely recovers
# "which category" without conflating dodged siblings with separate rows)
# and scaling the shift up by that count, canceling the 1/N dilution.
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
#' baseline, as a target fraction of *panel height* (see
#' `position_dodge_gap()`'s own comment for why this - not a row-unit
#' fraction - is the right invariant to hold constant across callers with
#' different category counts per panel). Default `.02` (~2% of panel
#' height) looks right both for many-categories-sharing-one-panel layouts
#' and one-category-per-panel grids; `0` reproduces a touching layout with
#' no gap at all.
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
#' @param fill Base slab color, ramped by HDI width (see `fill_range`);
#'   defaults to `mt_colors[1]`.
#' @param fill_range Two-value alpha/lightness range (passed to
#'   [ggdist::scale_fill_ramp_discrete()]'s `range`) the slab's HDI widths
#'   are shaded across, from the widest (most faded, closer to white) to
#'   the narrowest (most saturated, `fill` at full strength). Default
#'   `c(.4, 1)`.
#' @param interval_color Color of the point-interval; defaults to
#'   `mt_colors[1]`.
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
  fill <- fill %||% mt_colors[1]
  interval_color <- interval_color %||% mt_colors[1]

  # HDI-width shading is mapped to `fill_ramp` (a dedicated ggdist
  # aesthetic for exactly this - ramping a single base color's
  # alpha/lightness across discrete levels), not `fill` directly. An
  # earlier version mapped `aes(fill = after_stat(level))` plus a
  # plot-global `scale_fill_manual()` - since ggplot2 scales are per-
  # aesthetic and global to the whole plot, that silently claimed the
  # entire `fill` aesthetic: adding ANY other fill-mapped layer to a plot
  # built on this (directly, or via plot_ridge_hdi()/plot_coef_grid_hdi())
  # crashed with "Insufficient values in manual scale" (confirmed
  # empirically). `fill_ramp` is its own aesthetic slot, so it can't
  # collide with a caller's own `fill` mapping - verified working
  # standalone and with an extra fill-mapped layer added.
  slab_args <- list(
    mapping = aes(fill_ramp = after_stat(level)),
    position = "dodgejust",
    point_interval = ggdist::mean_hdi,
    .width = slab_widths,
    fill = fill,
    color = "white",
    scale = scale,
    linewidth = .1
  )
  if (!is.null(slab_limits)) slab_args$limits <- slab_limits
  if (!is.null(n)) slab_args$n <- n

  interval_args <- list(
    position = position_dodge_gap(dodge_width = dodge_width, gap = gap),
    .width = interval_widths,
    point_size = point_size,
    fill = "white",
    color = interval_color,
    pch = 22,
    stroke = .1,
    point_interval = ggdist::mean_qi
  )
  if (!is.null(pointinterval_limits)) {
    interval_args$limits <- pointinterval_limits
  }

  list(
    do.call(ggdist::stat_slab, slab_args),
    do.call(ggdist::stat_pointinterval, interval_args),
    ggdist::scale_fill_ramp_discrete(range = fill_range),
    guides(fill_ramp = "none", pch = "none", color = "none")
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
#' @param hline_color Color of the reference line.
#' @param value_transform Applied to `value` before plotting (e.g. `exp` for
#'   a sigma submodel estimated on the log scale).
#' @param value_limits,value_breaks Passed to `scale_y_continuous()`.
#' @param category_reorder `TRUE` (default) sorts categories by their mean
#'   transformed `value` (descending) via [forcats::fct_reorder()]; `FALSE`
#'   keeps whatever factor-level order `category` already has.
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
  hline_color = mt_colors[2],
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
    # forcats::fct_reorder() fails deep inside ggplot2's own aesthetic
    # evaluation (a cryptic "`idx` must contain one integer for each level
    # of `f`" from forcats:::lvls_reorder(), not this function) whenever a
    # category has no non-NA `value` left to order by - checked eagerly
    # here, rather than left to fail lazily at build/print time, since
    # forcats' own error gives no hint this function or its
    # category_reorder argument is involved at all. See
    # .check_reorder_values() for the exact condition; note it's per
    # category, so an entirely-NA `value` is only its most extreme case.
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
        .desc = TRUE
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
      geom_hline(
        yintercept = hline,
        color = hline_color,
        lty = "dashed",
        alpha = .5
      )
  }

  p <- p +
    layer_halfeye_hdi(...) +
    scale_x_discrete(expand = c(0, 0)) +
    coord_flip(clip = "off") +
    labs(x = xlab, y = ylab) +
    # axis.text.y/.x and axis.title.x are set both in their base form and in
    # their position-suffixed form (.left/.right/.bottom/.top) for the same
    # reason theme_mt() itself does (see theme.R): ggplot2 >= 4.0 resolves
    # axis labels through the position-suffixed elements, which theme_mt()
    # (the active default theme) has already set explicitly - so a later
    # plain axis.text.y here would silently lose to theme_mt()'s own
    # axis.text.y.left otherwise.
    theme(
      panel.grid.minor.y = element_blank(),
      axis.text.y = element_markdown(hjust = 1),
      axis.text.y.left = element_markdown(hjust = 1),
      axis.text.y.right = element_markdown(hjust = 1),
      axis.title.x = element_markdown(),
      axis.title.x.top = element_markdown(),
      axis.text.x = element_markdown(),
      axis.text.x.bottom = element_markdown(),
      axis.text.x.top = element_markdown()
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
#' @param hline_color Color of the reference line.
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
  hline_color = mt_colors[2],
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
      geom_hline(
        yintercept = hline,
        color = hline_color,
        lty = "dashed",
        alpha = .5
      )
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
    # see plot_ridge_hdi()'s comment on why both the base and
    # position-suffixed axis elements are set here.
    theme(
      axis.text.y = element_blank(),
      axis.text.y.left = element_blank(),
      axis.text.y.right = element_blank(),
      axis.title.x = element_markdown(),
      axis.title.x.top = element_markdown(),
      axis.title.y = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.minor.y = element_blank()
    )
}
