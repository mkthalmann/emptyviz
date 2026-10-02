# Drops the `...` arguments the sub-layers (aura, SD fill, SD outline) set
# themselves, with a warning rather than a duplicate-argument error. Names
# are compared after ggplot2's alias standardisation, so `col`, `lwd` or `bg`
# are caught like `colour`, `linewidth` or `fill`. alpha/colour/linewidth/
# stat are set per sub-layer; `fill` is a formal of every geom, so it can
# only arrive here through an alias. Quantile lines cannot be drawn: the
# aura is transparent-outlined and the SD-band layers only hold the part of
# the density inside the band, so a quantile outside it has nothing to be
# drawn on.
warn_reserved_dots <- function(dots, geom_name) {
  styling <- c("alpha", "colour", "fill", "linewidth", "stat")
  quantile_args <- c(
    "draw_quantiles", "quantile.colour", "quantile.color",
    "quantile.linetype", "quantile.linewidth"
  )
  given <- names(dots) %||% character(0)
  standard <- standardise_aes_names(given)
  ignored_styling <- given[standard %in% styling]
  if (length(ignored_styling) > 0) {
    warning(
      geom_name,
      "() ignores ",
      paste(sprintf("`%s`", ignored_styling), collapse = ", "),
      " passed via `...` (these are controlled by fill/base_alpha/sd_alpha/",
      "outline_color/sd_linewidth, or hardcoded to the SD-band stat).",
      call. = FALSE
    )
  }
  ignored_quantiles <- given[given %in% quantile_args]
  if (length(ignored_quantiles) > 0) {
    warning(
      geom_name,
      "() ignores ",
      paste(sprintf("`%s`", ignored_quantiles), collapse = ", "),
      ": quantile lines are not supported by the SD-band geoms.",
      call. = FALSE
    )
  }
  dots[!(standard %in% styling | given %in% quantile_args)]
}

# Mean +/- 1 SD per group, for StatYdensitySD and StatHalfYdensitySD. Groups
# with fewer than 2 values are dropped, as the density stat drops them.
# `data` must be in canonical orientation (y continuous).
.sd_bounds <- function(data, na.rm) {
  data |>
    group_by(.data$group) |>
    summarise(
      n = sum(!is.na(.data$y)),
      lo = mean(.data$y, na.rm = na.rm) - sd(.data$y, na.rm = na.rm),
      hi = mean(.data$y, na.rm = na.rm) + sd(.data$y, na.rm = na.rm),
      .groups = "drop"
    ) |>
    filter(.data$n >= 2)
}

# Truncates a density-stat `result` (canonical orientation, as for
# .sd_bounds()) to each group's mean +/- 1 SD. Groups without bounds are
# dropped: with `drop = FALSE` the density stat keeps groups of fewer than
# 2 points, which .sd_bounds() excludes, and matching them would yield rows
# of NA.
.truncate_to_sd_bounds <- function(result, bounds) {
  keep <- unique(result$group[result$group %in% bounds$group])
  lapply(keep, function(g) {
    grp <- result[result$group == g, ]
    i <- match(g, bounds$group)
    grp[grp$y >= bounds$lo[i] & grp$y <= bounds$hi[i], ]
  }) |>
    bind_rows()
}

# Subclasses gghalves:::StatHalfYdensity, which gghalves does not export.
# test-upstream-internals.R checks that it still exists.
StatHalfYdensitySD <- ggproto(
  "StatHalfYdensitySD",
  gghalves:::StatHalfYdensity,

  # See StatYdensitySD$parameters() for why this override exists: without
  # it, the panel-level `scale` would be rejected as an unknown parameter.
  parameters = function(self, extra = FALSE) {
    args <- names(ggplot2:::ggproto_formals(gghalves:::StatHalfYdensity$compute_panel))
    args <- setdiff(args, c("self", "data", "scales"))
    if (extra) args <- union(args, self$extra_params)
    args
  },

  # `na.rm` is used here; every other parameter flows through `...` to
  # StatHalfYdensity, so parameters gghalves adds later reach it unchanged.
  compute_panel = function(self, data, scales, na.rm = FALSE, ...) {
    bounds <- .sd_bounds(data, na.rm)

    result <- gghalves:::StatHalfYdensity$compute_panel(
      data,
      scales,
      na.rm = na.rm,
      ...
    )

    .truncate_to_sd_bounds(result, bounds)
  }
)

# The SD-band outline sub-layer: a violin drawn without fill. `fill` is set
# to NA only at draw time. As a literal `fill = NA` parameter it would drop
# out of the layer's grouping, so dodged groups would collapse and the
# outline would no longer line up with the aura and SD fill. Keeping the
# real fill until drawing also lets `aes(colour = after_scale(fill))` give
# each outline its group's colour.
#
# The formals match the parent's draw_group(), because Geom$draw_layer()
# passes on only the parameters named there; a `...`-only signature would
# drop `side`/`nudge` (gghalves) and `quantile_gp`/`flipped_aes` (ggplot2).
GeomViolinOutline <- ggproto(
  "GeomViolinOutline",
  GeomViolin,
  draw_group = function(self, data, ..., quantile_gp = list(), flipped_aes = FALSE) {
    data$fill <- NA
    ggproto_parent(GeomViolin, self)$draw_group(
      data,
      ...,
      quantile_gp = quantile_gp,
      flipped_aes = flipped_aes
    )
  }
)

# gghalves 0.1.4's GeomHalfViolin$setup_params() recycles `side` to the
# number of groups that survive the density stat. When a thin group (fewer
# than 2 points) is dropped, later groups keep their original, higher ids,
# so draw_group()'s `side[data$group[1]]` reads past the end and fails with
# "missing value where TRUE/FALSE needed". Recycling to the highest group id
# keeps every id in range. The "split" branch is gghalves' own split-violin
# feature, which geom_split_violin_sd() does not use; it is kept unchanged.
GeomHalfViolinSD <- ggproto(
  "GeomHalfViolinSD",
  gghalves::GeomHalfViolin,
  setup_params = function(data, params) {
    if ("split" %in% colnames(data)) {
      stopifnot(length(unique(data$split)) == 2)
      params$side <- rep(c("l", "r"), max(data$group) / 2)
    } else {
      params$side <- rep_len(params$side, max(1L, max(data$group)))
    }
    params
  }
)

GeomHalfViolinOutline <- ggproto(
  "GeomHalfViolinOutline",
  GeomHalfViolinSD,
  draw_group = function(self, data, side = "l", nudge = 0, ..., draw_quantiles = NULL) {
    data$fill <- NA
    ggproto_parent(GeomHalfViolinSD, self)$draw_group(
      data,
      side = side,
      nudge = nudge,
      ...,
      draw_quantiles = draw_quantiles
    )
  }
)

#' A half-violin with a mean +/- 1 SD band
#'
#' A half-violin split into a low-alpha "aura" (the full density, drawn
#' first) plus a solid mean +/- 1 SD band on top (fill and/or outline,
#' controlled by `style`). Same calling convention as
#' [gghalves::geom_half_violin()] (mapping/data first, both default `NULL`,
#' `inherit.aes`-aware) - the only additions are `fill`/`style`/
#' `base_alpha`/`sd_alpha`/`outline_color`/`sd_linewidth`.
#'
#' `alpha`/`color`/`colour`/`linewidth`/`stat` passed via `...` are reserved
#' (used internally by the aura/fill/outline sub-layers) and will warn, not
#' error or silently vanish - use `base_alpha`/`sd_alpha`/`outline_color`/
#' `sd_linewidth` instead (there's no equivalent substitute for `stat` -
#' swapping it out isn't meaningful for this geom's own identity). Quantile
#' lines are not supported: `draw_quantiles` and the `quantile.*` arguments
#' are dropped with a warning.
#'
#' `side` follows gghalves' own convention: a scalar applies to every group,
#' a vector is indexed by sorted factor-level order of the discrete axis
#' (not data row order).
#'
#' `gghalves` has no concept of `orientation`/`flipped_aes` anywhere in its
#' source (unlike ggplot2's own `geom_violin()`) - half-violins are
#' vertical-only. Swapping x/y (e.g. `aes(x = value, y = group)`) or using
#' `coord_flip()` is not supported upstream and will silently misbehave
#' (e.g. `position_dodge()` warnings about non-overlapping x intervals);
#' this is a `gghalves` limitation, not something `geom_half_violin_sd()`
#' can fix.
#'
#' x-levels (or, when built through [geom_split_violin_sd()], one thin side
#' of an x-level) with fewer than 2 raw data points are silently dropped by
#' the underlying density stat - the same `stats::sd()`-needs-2-points floor
#' [geom_violin_sd()] has - and ggplot2's own "Groups with fewer than two
#' datapoints have been dropped" warning fires. The remaining groups still
#' render correctly around the gap.
#'
#' Only the aura sub-layer ever contributes a legend key (the SD-band
#' sub-layers are always `show.legend = FALSE`), so the legend shows one
#' clean, full-opacity swatch per group instead of the aura's and SD-fill's
#' low-alpha keys overlaid on top of each other.
#'
#' When `outline_color` isn't given and `fill` isn't passed as a literal
#' (i.e. it's mapped via `aes(fill = ...)`, locally or inherited from the
#' plot), the SD-band outline's colour tracks each group's resolved fill.
#'
#' @section Background:
#' The SD band shows how much the observations vary, not how precisely their
#' mean is estimated. Readers, experts included, readily take intervals of
#' inferential uncertainty for the spread of outcomes (Zhang et al. 2023; see
#' also Hoekstra et al. 2014). The geoms draw on these results and on
#' Hofmann (2025).
#'
#' @references
#' Hoekstra, R., Morey, R. D., Rouder, J. N., & Wagenmakers, E.-J. (2014).
#' Robust misinterpretation of confidence intervals. *Psychonomic Bulletin &
#' Review*, 21(5), 1157-1164. \doi{10.3758/s13423-013-0572-3}
#'
#' Hofmann, L. (2025). Anaphoric accessibility with flat update. *Semantics &
#' Pragmatics*, 18(3), 1-69. \doi{10.3765/sp.18.3}
#'
#' Zhang, S., Heck, P. R., Meyer, M. N., Chabris, C. F., Goldstein, D. G., &
#' Hofman, J. M. (2023). An illusion of predictability in scientific results:
#' Even experts confuse inferential uncertainty and outcome variability.
#' *Proceedings of the National Academy of Sciences*, 120(33).
#' \doi{10.1073/pnas.2302491120}
#'
#' @param mapping,data,...,inherit.aes As in [gghalves::geom_half_violin()].
#' @param fill A constant fill for all violins; omit it to map fill via
#'   `mapping` instead (`aes(fill = ...)`) the normal ggplot2 way.
#' @param side Which side to draw the half-violin on - `"l"` or `"r"`, or a
#'   vector thereof (see Details).
#' @param style One of `"both"` (default), `"fill"`, or `"outline"` - which
#'   SD-band sub-layer(s) to draw.
#' @param base_alpha,sd_alpha Alpha of the aura and SD-band *fill*
#'   sub-layers, respectively. The SD-band *outline* is always drawn at
#'   full opacity regardless of either - it's the one element meant to
#'   reliably mark the SD band even when `base_alpha`/`sd_alpha` are turned
#'   down or off entirely.
#' @param outline_color Color of the SD-band outline; defaults to `fill`
#'   when given as a literal, or otherwise tracks each group's resolved
#'   fill automatically (see Details).
#' @param sd_linewidth Line width of the SD-band outline.
#' @param trim Trim each violin to the range of the observed data (`TRUE`,
#'   the default, matching [gghalves::geom_half_violin()]'s own default) or
#'   let the density estimate extend past it for a softer, tapered edge
#'   (`FALSE`).
#' @return A list of `ggplot2` layers and a `guides()` call (tuned to keep
#'   the legend key at full opacity - see Details).
#' @examples
#' library(ggplot2)
#' set.seed(1)
#' df <- data.frame(
#'   grp = rep(c("a", "b"), each = 40),
#'   y = c(rnorm(40), rnorm(40, 1))
#' )
#' ggplot(df, aes(grp, y, fill = grp)) +
#'   geom_half_violin_sd()
#' @export
geom_half_violin_sd <- function(
  mapping = NULL,
  data = NULL,
  ...,
  fill = NULL,
  side = "l",
  style = c("both", "outline", "fill"),
  base_alpha = 0.25,
  sd_alpha = 0.25,
  outline_color = NULL,
  sd_linewidth = 0.3,
  trim = TRUE,
  inherit.aes = TRUE
) {
  style <- match.arg(style)
  if (is.data.frame(data)) data <- ungroup(data) |> droplevels()

  # `side` is passed through unchanged: GeomHalfViolinSD recycles it against
  # the group ids at build time, which follow factor-level order rather
  # than the order of rows in `data`.
  dots_clean <- warn_reserved_dots(list(...), "geom_half_violin_sd")

  fill_args <- if (!is.null(fill)) list(fill = fill) else list()
  outline_color <- outline_color %||% fill
  outline_color_args <- if (!is.null(outline_color)) {
    list(color = outline_color)
  } else {
    list()
  }

  base_layer <- do.call(
    geom_half_violin,
    c(
      list(
        data = data,
        mapping = mapping,
        inherit.aes = inherit.aes,
        alpha = base_alpha,
        color = "transparent",
        trim = trim,
        side = side
      ),
      fill_args,
      dots_clean
    )
  )
  # Swapping the geom after construction has the same effect as constructing
  # with GeomHalfViolinSD, because setup_params() only runs at build time,
  # and keeps geom_half_violin()'s own argument handling.
  base_layer$geom <- GeomHalfViolinSD

  # Only the aura carries the legend (see Details).
  fill_layer <- do.call(
    geom_half_violin,
    c(
      list(
        data = data,
        mapping = mapping,
        stat = StatHalfYdensitySD,
        inherit.aes = inherit.aes,
        alpha = sd_alpha,
        color = "transparent",
        trim = trim,
        side = side,
        show.legend = FALSE
      ),
      fill_args,
      dots_clean[setdiff(names(dots_clean), "show.legend")]
    )
  )
  fill_layer$geom <- GeomHalfViolinSD

  # Built with layer() because geom_half_violin() fixes the geom; see
  # GeomViolinOutline for why the outline needs its own. layer() does not
  # default `position` to "dodge", so it is passed explicitly, and
  # `show.legend` is always FALSE.
  outline_mapping <- mapping %||% aes()
  if (length(outline_color_args) == 0) {
    # Taken from aes() so it is a quosure, as layer() expects.
    outline_mapping$colour <- aes(colour = after_scale(fill))$colour
  }
  outline_position <- dots_clean$position %||% "dodge"
  dots_for_outline <- dots_clean[!names(dots_clean) %in% c("position", "show.legend")]
  outline_params <- utils::modifyList(
    list(alpha = 1, linewidth = sd_linewidth, trim = trim, side = side, nudge = 0),
    c(outline_color_args, dots_for_outline)
  )
  outline_layer <- layer(
    data = data,
    mapping = outline_mapping,
    stat = StatHalfYdensitySD,
    geom = GeomHalfViolinOutline,
    position = outline_position,
    show.legend = FALSE,
    inherit.aes = inherit.aes,
    params = outline_params
  )

  sd_layers <- switch(
    style,
    fill = list(fill_layer),
    outline = list(outline_layer),
    both = list(fill_layer, outline_layer)
  )

  c(
    list(base_layer),
    sd_layers,
    # Full-opacity legend key for the translucent aura; a no-op when fill
    # is not mapped.
    list(guides(fill = guide_legend(override.aes = list(alpha = 1))))
  )
}

#' Two half-violins back to back, split by a two-level column
#'
#' A "split violin": two [geom_half_violin_sd()] halves back-to-back at the
#' same x position, one per level of `split`, instead of the caller
#' pre-filtering `data` and calling `geom_half_violin_sd()` twice by hand
#' with `side = "l"`/`"r"`. `split` follows the same "sorted factor-level
#' order" convention gghalves itself uses for `side` (left gets the first
#' sorted level, right the second) - pass `flip = TRUE` to swap them.
#'
#' Unlike [geom_violin_sd()]/[geom_half_violin_sd()], `data` must be
#' supplied directly (not `NULL`/inherited from the plot) - the split has
#' to happen before the two side-specific layer sets are built, so the data
#' must exist at call time, not at `ggplot_build()` time.
#'
#' `scale` defaults to `"count"` (not gghalves'/ggplot2's own `"area"`
#' default), matching what `geom_violin()`'s own default would be. This does
#' NOT make the two sides' widths comparable to each other - left and right
#' are two independent `geom_half_violin_sd()` layers, each with its own
#' Stat computation, so `"count"` only normalizes a side's x-levels against
#' *that side's own* other x-levels, never against the other side's counts.
#'
#' The aura and SD-fill sub-layers are hidden from the legend
#' (`show.legend = FALSE`) on both sides; only a dedicated dummy layer
#' contributes a key, so `split` shows up as one clean legend entry per
#' level instead of 2-3 near-duplicate, differently-alpha'd swatches (two
#' layers both mapping fill to the same scale with `show.legend = TRUE`
#' would otherwise overlay every contributing layer's key glyph at every
#' break).
#'
#' The internal fill scale leaves its `name` as the ggplot2 default
#' (`waiver()`) rather than hardcoding it to the `split` column name, so
#' `labs(fill = ...)`/`guides(fill = guide_legend(title = ...))` control
#' the legend title the normal ggplot2 way and can merge with `color`/
#' `shape` legends mapped to the same column.
#'
#' Warns (does not silently drop) when an x-level has data on only one side
#' of the split, or when a side's cell count falls under the `n >= 2`
#' minimum the underlying SD-band stat already requires - splitting divides
#' already-thin repeated-measures cells a third way. Either way, the plot
#' still renders correctly around the thin/missing cell - a below-minimum
#' side is silently dropped by the underlying density stat (same as
#' [geom_half_violin_sd()]), it doesn't stop the rest of the plot from
#' drawing.
#'
#' @inheritSection geom_half_violin_sd Background
#' @inherit geom_half_violin_sd references
#' @param mapping,data,...,inherit.aes As in [geom_half_violin_sd()], except
#'   `data` is required (see Details).
#' @param split An unquoted column in `data` with exactly *two* levels (more
#'   or fewer is an error). Rows with `NA` in this column are dropped with a
#'   warning.
#' @param flip Swap which split level renders on the left vs. right.
#' @param fill Defaults to the package's own two-color [mt_colors] palette (one
#'   color per side); pass a length-2 vector to override, one color per
#'   sorted (or flipped) split level. Any `aes(fill = ...)` in `mapping` is
#'   ignored - fill is spoken for by `split` here.
#' @param style,base_alpha,sd_alpha,sd_linewidth,trim As in
#'   [geom_half_violin_sd()].
#' @param outline_color Length-2 or `NULL` (falls back to `fill` per side).
#' @param scale Passed to the underlying density stat; see Details.
#' @return A list of `ggplot2` layers, scales, and guides.
#' @examples
#' library(ggplot2)
#' set.seed(1)
#' df <- data.frame(
#'   grp = rep(c("a", "b", "c"), each = 40),
#'   cond = rep(c("x", "y"), 60),
#'   y = rnorm(120)
#' )
#' ggplot(df, aes(grp, y)) +
#'   geom_split_violin_sd(data = df, split = cond)
#' @export
geom_split_violin_sd <- function(
  mapping = NULL,
  data = NULL,
  ...,
  split,
  flip = FALSE,
  fill = NULL,
  style = c("both", "outline", "fill"),
  base_alpha = 0.25,
  sd_alpha = 0.25,
  outline_color = NULL,
  sd_linewidth = 0.3,
  scale = "count",
  trim = TRUE,
  inherit.aes = TRUE
) {
  style <- match.arg(style)

  if (!is.data.frame(data)) {
    stop(
      "geom_split_violin_sd() requires `data` to be a data frame supplied directly ",
      "(it can't inherit data from the plot the way geom_violin_sd()/",
      "geom_half_violin_sd() can) - it has to filter by `split` before ",
      "building each side's layers.",
      call. = FALSE
    )
  }

  split_sym <- rlang::ensym(split)
  split_name <- rlang::as_string(split_sym)
  if (!split_name %in% names(data)) {
    stop(
      "geom_split_violin_sd(): split column `", split_name,
      "` not found in `data`.",
      call. = FALSE
    )
  }

  data <- ungroup(data) |> droplevels()
  split_vals <- data[[split_name]]

  n_na <- sum(is.na(split_vals))
  if (n_na > 0) {
    warning(
      "geom_split_violin_sd() dropped ", n_na, " row(s) with NA `",
      split_name, "`.",
      call. = FALSE
    )
    data <- data[!is.na(split_vals), ]
    split_vals <- data[[split_name]]
  }

  split_levels <- if (is.factor(split_vals)) {
    levels(droplevels(factor(split_vals)))
  } else {
    as.character(sort(unique(split_vals)))
  }

  if (length(split_levels) != 2) {
    stop(
      "geom_split_violin_sd() requires `split` (`", split_name,
      "`) to have exactly 2 levels, got ", length(split_levels),
      if (length(split_levels) > 0) {
        paste0(" (", paste(split_levels, collapse = ", "), ")")
      } else {
        ""
      },
      ".",
      call. = FALSE
    )
  }

  if (flip) split_levels <- rev(split_levels)
  left_level <- split_levels[1]
  right_level <- split_levels[2]

  left_data <- data[as.character(split_vals) == left_level, ]
  right_data <- data[as.character(split_vals) == right_level, ]

  # Warn about x-levels that lack one side or fall below the n >= 2 minimum
  # of the SD-band stat. Skipped when x is not mapped in this layer's own
  # `mapping` (e.g. inherited from the plot).
  x_quo <- mapping$x
  if (!is.null(x_quo)) {
    x_vals <- tryCatch(rlang::eval_tidy(x_quo, data), error = function(e) NULL)
    if (!is.null(x_vals)) {
      tab <- table(as.character(x_vals), as.character(split_vals))
      thin <- character(0)
      for (xl in rownames(tab)) {
        l_n <- if (left_level %in% colnames(tab)) tab[xl, left_level] else 0
        r_n <- if (right_level %in% colnames(tab)) tab[xl, right_level] else 0
        if (l_n == 0 || r_n == 0) {
          thin <- c(thin, paste0(xl, " (missing one side entirely)"))
        } else if (l_n < 2 || r_n < 2) {
          thin <- c(
            thin,
            sprintf("%s (n=%d/%d, below SD-band minimum)", xl, l_n, r_n)
          )
        }
      }
      if (length(thin) > 0) {
        warning(
          "geom_split_violin_sd(): thin or one-sided x-levels - ",
          paste(thin, collapse = "; "),
          call. = FALSE
        )
      }
    }
  }

  dots <- list(...)
  reserved_here <- intersect(names(dots), c("side", "show.legend"))
  if (length(reserved_here) > 0) {
    warning(
      "geom_split_violin_sd() ignores ",
      paste(sprintf("`%s`", reserved_here), collapse = ", "),
      " passed via `...` (sides are controlled internally via `split`/",
      "`flip`, and the legend is drawn by a dedicated internal layer).",
      call. = FALSE
    )
    dots[reserved_here] <- NULL
  }
  dots_clean <- warn_reserved_dots(dots, "geom_split_violin_sd")

  fill <- fill %||% mt_colors
  if (length(fill) != 2) {
    stop(
      "geom_split_violin_sd(): `fill` must be a length-2 vector (one ",
      "color per split level) or NULL, got length ", length(fill), ".",
      call. = FALSE
    )
  }

  if (!is.null(outline_color) && length(outline_color) != 2) {
    stop(
      "geom_split_violin_sd(): `outline_color` must be a length-2 vector ",
      "or NULL, got length ", length(outline_color), ".",
      call. = FALSE
    )
  }
  # fill is mapped below rather than passed as a literal, so the outline's
  # fallback to the fill colour is resolved here, per side.
  outline_args_left <- list(
    outline_color = if (!is.null(outline_color)) outline_color[1] else fill[1]
  )
  outline_args_right <- list(
    outline_color = if (!is.null(outline_color)) outline_color[2] else fill[2]
  )

  # fill is mapped (not set per side) so that there is a scale for the
  # legend. The mapping is extended in place: modifyList() would drop the
  # "uneval" class that layer() checks for.
  mapping_with_split_fill <- mapping %||% aes()
  mapping_with_split_fill$fill <- rlang::inject(aes(fill = !!split_sym))$fill

  # The violin sub-layers are hidden from the legend: when several layers
  # contribute keys to one fill scale, ggplot2 draws all their glyphs on top
  # of each other at every break. A dummy layer (one invisible point per
  # level) carries the legend instead.
  left_layers <- do.call(
    geom_half_violin_sd,
    c(
      list(
        mapping = mapping_with_split_fill,
        data = left_data,
        side = "l",
        style = style,
        base_alpha = base_alpha,
        sd_alpha = sd_alpha,
        sd_linewidth = sd_linewidth,
        scale = scale,
        trim = trim,
        inherit.aes = inherit.aes,
        show.legend = FALSE
      ),
      outline_args_left,
      dots_clean
    )
  )

  right_layers <- do.call(
    geom_half_violin_sd,
    c(
      list(
        mapping = mapping_with_split_fill,
        data = right_data,
        side = "r",
        style = style,
        base_alpha = base_alpha,
        sd_alpha = sd_alpha,
        sd_linewidth = sd_linewidth,
        scale = scale,
        trim = trim,
        inherit.aes = inherit.aes,
        show.legend = FALSE
      ),
      outline_args_right,
      dots_clean
    )
  )

  split_scale <- scale_fill_manual(
    values = stats::setNames(fill, c(left_level, right_level))
  )

  legend_data <- data.frame(x = c(left_level, right_level))
  names(legend_data) <- split_name
  legend_layer <- geom_point(
    data = legend_data,
    mapping = rlang::inject(aes(x = -Inf, y = -Inf, fill = !!split_sym)),
    shape = 22,
    size = 0,
    colour = NA,
    inherit.aes = FALSE,
    show.legend = TRUE,
    na.rm = TRUE
  )
  legend_guide <- guides(
    fill = guide_legend(
      override.aes = list(size = 5, shape = 22, colour = NA)
    )
  )

  # Keep only the layers of each side: the guides() call that
  # geom_half_violin_sd() returns is meant for its own legend design and
  # would conflict with legend_guide.
  left_layers <- Filter(function(x) inherits(x, "LayerInstance"), left_layers)
  right_layers <- Filter(function(x) inherits(x, "LayerInstance"), right_layers)

  c(left_layers, right_layers, list(split_scale, legend_layer, legend_guide))
}

# The SD bounds are the unweighted mean and sd of the raw y values: a mapped
# `weight` affects the density curve but not the band.
StatYdensitySD <- ggproto(
  "StatYdensitySD",
  StatYdensity,

  # Stat$parameters() decides which `...` arguments a layer accepts. With a
  # `...`-only compute_panel() it falls back to compute_group()'s formals,
  # which lack the panel-level `scale`, so `scale` would be rejected as an
  # unknown parameter. Reading StatYdensity's own compute_panel() formals
  # avoids that. ggproto_formals() is internal to ggplot2;
  # test-upstream-internals.R checks that it still exists.
  parameters = function(self, extra = FALSE) {
    args <- names(ggplot2:::ggproto_formals(StatYdensity$compute_panel))
    args <- setdiff(args, c("self", "data", "scales"))
    if (extra) args <- union(args, self$extra_params)
    args
  },

  # `na.rm` and `flipped_aes` are used here; every other parameter flows
  # through `...` to StatYdensity, so parameters ggplot2 adds later reach it
  # without a change here.
  compute_panel = function(self, data, scales, na.rm = FALSE, flipped_aes = FALSE, ...) {
    # StatYdensity$compute_panel() works on data flipped so that y is the
    # continuous variable and flips its result back. The bounds and the
    # truncation need the same canonical orientation, or a horizontal violin
    # would get bounds computed from its group ids.
    canonical_data <- flip_data(data, flipped_aes)
    grp_bounds <- .sd_bounds(canonical_data, na.rm)

    result <- StatYdensity$compute_panel(
      data,
      scales,
      na.rm = na.rm,
      flipped_aes = flipped_aes,
      ...
    )

    canonical_result <- flip_data(result, flipped_aes)
    canonical_result <- .truncate_to_sd_bounds(canonical_result, grp_bounds)

    flip_data(canonical_result, flipped_aes)
  }
)

#' A violin with a mean +/- 1 SD band
#'
#' A violin split into a low-alpha "aura" (the full density, drawn first)
#' plus a solid mean +/- 1 SD band on top (fill and/or outline, controlled
#' by `style`). Same calling convention as [ggplot2::geom_violin()]
#' (mapping/data first, both default `NULL`, `inherit.aes`-aware, supports
#' `coord_flip()` and horizontal orientation via `aes(x = value, y = group)`)
#' - the only additions are `fill`/`style`/`base_alpha`/`sd_alpha`/
#' `outline_color`/`sd_linewidth`.
#'
#' `alpha`/`color`/`colour`/`linewidth`/`stat` passed via `...` are reserved
#' (used internally by the aura/fill/outline sub-layers) and will warn, not
#' error or silently vanish - use `base_alpha`/`sd_alpha`/`outline_color`/
#' `sd_linewidth` instead (there's no equivalent substitute for `stat` -
#' swapping it out isn't meaningful for this geom's own identity). Quantile
#' lines are not supported: `draw_quantiles` and the `quantile.*` arguments
#' are dropped with a warning.
#'
#' SD bounds are always the *unweighted* mean/sd of the raw y values, even
#' if `aes(weight = ...)` is mapped.
#'
#' As with [geom_half_violin_sd()]: only the aura sub-layer ever
#' contributes a legend key, and the SD-band outline's colour tracks each
#' group's resolved fill automatically when `outline_color`/`fill` aren't
#' given as literals.
#'
#' @inheritParams geom_half_violin_sd
#' @inheritSection geom_half_violin_sd Background
#' @inherit geom_half_violin_sd references
#' @return A list of `ggplot2` layers and a `guides()` call (tuned to keep
#'   the legend key at full opacity - see Details).
#' @examples
#' library(ggplot2)
#' set.seed(1)
#' df <- data.frame(
#'   grp = rep(c("a", "b", "c"), each = 40),
#'   y = c(rnorm(40), rnorm(40, 1.5, 0.6), rnorm(40, -0.5, 1.8))
#' )
#' ggplot(df, aes(grp, y, fill = grp)) +
#'   geom_violin_sd() +
#'   guides(fill = "none")
#' @export
geom_violin_sd <- function(
  mapping = NULL,
  data = NULL,
  ...,
  fill = NULL,
  style = c("both", "outline", "fill"),
  base_alpha = 0.25,
  sd_alpha = 0.25,
  outline_color = NULL, # NULL means "inherit from fill or mapping"
  sd_linewidth = 0.3,
  trim = TRUE,
  inherit.aes = TRUE
) {
  style <- match.arg(style)
  if (is.data.frame(data)) data <- ungroup(data) |> droplevels()

  dots_clean <- warn_reserved_dots(list(...), "geom_violin_sd")

  fill_args <- if (!is.null(fill)) list(fill = fill) else list()
  outline_color <- outline_color %||% fill # still NULL if both are NULL

  base_layer <- do.call(
    geom_violin,
    c(
      list(
        data = data,
        mapping = mapping,
        inherit.aes = inherit.aes,
        alpha = base_alpha,
        color = "transparent",
        trim = trim
      ),
      fill_args,
      dots_clean
    )
  )

  # Only the aura carries the legend (see Details).
  fill_layer <- do.call(
    geom_violin,
    c(
      list(
        data = data,
        mapping = mapping,
        stat = StatYdensitySD,
        inherit.aes = inherit.aes,
        alpha = sd_alpha,
        color = "transparent",
        trim = trim,
        show.legend = FALSE
      ),
      fill_args,
      dots_clean[setdiff(names(dots_clean), "show.legend")]
    )
  )

  outline_color_args <- if (!is.null(outline_color)) {
    list(color = outline_color)
  } else {
    list()
  }

  # Built with layer() because geom_violin() fixes the geom to GeomViolin;
  # see GeomViolinOutline for why the outline needs its own. layer() does not
  # default `position` to "dodge", so it is passed explicitly.
  outline_mapping <- mapping %||% aes()
  if (length(outline_color_args) == 0) {
    # Taken from aes() so it is a quosure, as layer() expects.
    outline_mapping$colour <- aes(colour = after_scale(fill))$colour
  }
  outline_position <- dots_clean$position %||% "dodge"
  dots_for_outline <- dots_clean[!names(dots_clean) %in% c("position", "show.legend")]
  outline_params <- utils::modifyList(
    list(alpha = 1, linewidth = sd_linewidth, trim = trim),
    c(outline_color_args, dots_for_outline)
  )
  outline_layer <- layer(
    data = data,
    mapping = outline_mapping,
    stat = StatYdensitySD,
    geom = GeomViolinOutline,
    position = outline_position,
    show.legend = FALSE,
    inherit.aes = inherit.aes,
    params = outline_params
  )

  sd_layers <- switch(
    style,
    fill = list(fill_layer),
    outline = list(outline_layer),
    both = list(fill_layer, outline_layer)
  )

  c(
    list(base_layer),
    sd_layers,
    # Full-opacity legend key for the translucent aura; a no-op when fill
    # is not mapped.
    list(guides(fill = guide_legend(override.aes = list(alpha = 1))))
  )
}
