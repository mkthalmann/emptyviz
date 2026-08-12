# include a way to visualize SDs in the half-violin plots I like so much; based on the results in @zhang2023inferentialuncertainty;@hofmann2025anaphoric; see also @hoekstra2014confidenceintervals

# alpha/color/colour/fill/linewidth are always set internally by the three
# sub-layers (base "aura", SD fill, SD outline) of geom_violin_sd() /
# geom_half_violin_sd(); `stat` is hardcoded on the SD-fill/SD-outline
# sub-layers specifically. Warn instead of silently dropping or erroring
# (duplicate-argument) if the caller also passes them via `...`. (`trim` was
# reserved/hardcoded here too until it became a real parameter - see
# geom_violin_sd()/geom_half_violin_sd()'s own `trim` argument instead.)
#
# Each sub-layer independently validates/warns on the same underlying data,
# so a caller who triggers one of these (or an na.rm-removed-rows warning)
# will see it repeated 2-3 times, once per sub-layer - not a new bug if you
# see a warning here more than once.
warn_reserved_dots <- function(dots, geom_name) {
  reserved <- c("alpha", "color", "colour", "linewidth", "stat")
  ignored <- intersect(names(dots), reserved)
  if (length(ignored) > 0) {
    warning(
      geom_name,
      "() ignores ",
      paste(sprintf("`%s`", ignored), collapse = ", "),
      " passed via `...` (these are controlled by base_alpha/sd_alpha/",
      "outline_color/sd_linewidth, or hardcoded to the SD-band stat).",
      call. = FALSE
    )
  }
  dots[!names(dots) %in% reserved]
}

# Shared by StatYdensitySD/StatHalfYdensitySD's compute_panel() (below): the
# mean +/- 1 SD bounds per group, dropping groups with fewer than 2 raw
# (non-NA) y values - the same n>=2 floor the underlying density stat itself
# already requires to estimate anything. `data` must already be
# canonicalized (StatYdensitySD flips it via flip_data() first;
# StatHalfYdensitySD never needs to - gghalves has no flipped_aes concept),
# so this helper itself stays orientation-agnostic. Previously duplicated
# near-verbatim in both compute_panel()s - not pure copy-paste even then
# (one operated on flip_data()-canonicalized data, one on raw), which made a
# future "just keep them in sync by hand" edit its own drift risk; factored
# out once both call sites agreed on "already-canonicalized data in, bounds
# table out" as the shared contract.
.sd_bounds <- function(data, na.rm) {
  data |>
    group_by(group) |>
    summarise(
      n = sum(!is.na(y)),
      lo = mean(y, na.rm = na.rm) - sd(y, na.rm = na.rm),
      hi = mean(y, na.rm = na.rm) + sd(y, na.rm = na.rm),
      .groups = "drop"
    ) |>
    filter(n >= 2)
}

# Truncates a density-stat `result` (already canonicalized, same convention
# as .sd_bounds()'s own `data` argument) to each group's own mean +/- 1 SD
# band. `bounds` and `result` are guaranteed consistent here - the
# underlying density stat (gghalves:::StatHalfYdensity$compute_panel() /
# ggplot2::StatYdensity$compute_panel()) already drops any group with fewer
# than 2 points before this ever runs, the identical n>=2 floor
# .sd_bounds() itself applies - so every group iterated over below is
# guaranteed present in `bounds`, and lo/hi are never NA in practice.
.truncate_to_sd_bounds <- function(result, bounds) {
  lapply(unique(result$group), function(g) {
    grp <- result[result$group == g, ]
    lo <- bounds$lo[match(g, bounds$group)]
    hi <- bounds$hi[match(g, bounds$group)]
    grp[grp$y >= lo & grp$y <= hi, ]
  }) |>
    bind_rows()
}

# Reaches into gghalves:::StatHalfYdensity, an unexported ggproto of the
# gghalves package, since gghalves doesn't export a Stat subclassing hook
# for its half-violin density computation the way ggplot2 does for
# StatYdensity (see StatYdensitySD below). Verified against gghalves 0.1.4;
# if a future gghalves release restructures or renames this internal
# object, geom_half_violin_sd()/geom_split_violin_sd() will need updating.
StatHalfYdensitySD <- ggproto(
  "StatHalfYdensitySD",
  gghalves:::StatHalfYdensity,

  # ggplot2's own `Stat$parameters()` (which layer construction uses to
  # decide whether a `...` argument is "known" or should warn "Ignoring
  # unknown parameters") normally introspects `compute_panel`'s own
  # formals - or, when `compute_panel` uses a bare `...` (as below),
  # falls back to `compute_group`'s formals instead. That fallback isn't
  # enough here: `scale` is an inherently panel-level concept (a group's
  # width relative to every *other* group sharing its panel), so it's
  # never one of `compute_group`'s formals for ANY density stat, ggplot2's
  # own StatYdensity included - the fallback would silently make `scale`
  # look "unknown" for this stat specifically, even though it's still
  # correctly forwarded to the parent below (confirmed empirically: the
  # aura sub-layer, built on plain stat_ydensity()/half_ydensity(), keeps
  # honoring `scale` throughout; only the SD-band sub-layers using this
  # stat would silently start ignoring it). Overriding `parameters()`
  # directly - reading gghalves:::StatHalfYdensity's OWN compute_panel
  # formals, not this override's `...`-based one - sidesteps that gap
  # without re-introducing the hardcoded-parameter-list problem the `...`
  # forwarding below exists to avoid in the first place. `ggproto_formals`
  # is itself an unexported ggplot2 helper (verified present and behaving
  # this way in ggplot2 4.0.3) - if a future release renames/removes it,
  # this errors loudly at package-load/first-call time rather than
  # silently misbehaving, so a break here should be easy to spot.
  parameters = function(self, extra = FALSE) {
    args <- names(ggplot2:::ggproto_formals(gghalves:::StatHalfYdensity$compute_panel))
    args <- setdiff(args, c("self", "data", "scales"))
    if (extra) args <- union(args, self$extra_params)
    args
  },

  # `na.rm` is pulled out as its own formal (used directly in the bounds
  # computation below, not just forwarded); everything else - width, bw,
  # adjust, kernel, trim, scale, and any parameter gghalves' own
  # StatHalfYdensity adds in a future release - flows through `...`
  # untouched. This is deliberate, not laziness: an earlier version of this
  # function re-declared a fixed formal list matching StatHalfYdensity's
  # signature at the time, which meant any parameter added upstream later
  # would silently fail to reach this stat (a real bug, once found for the
  # ggplot2/StatYdensity side - see StatYdensitySD below).
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

# Draws a violin-family geom's SD-band OUTLINE sub-layer with no fill, while
# keeping `fill` a genuinely resolved aesthetic (mapped or inherited) right
# up until the moment of drawing - unlike passing a literal `fill = NA`
# geom *parameter* (the original approach here), which empirically
# (confirmed via ggplot_build() comparisons) makes ggplot2 drop `fill` from
# that layer's own aesthetic-derived `group` computation entirely, silently
# collapsing dodge groups and breaking per-group outline coloring. Deferring
# the NA-out to draw time, after grouping/dodging have already run
# correctly off the real fill values, avoids that:
#   - grouping/dodging are computed identically to the aura/SD-fill
#     sub-layers (which never touch `fill` this way), so the outline stays
#     aligned with them even when multiple fill-mapped groups share one x.
#   - `aes(colour = after_scale(fill))` (added by the geom_*_sd() wrapper
#     when no explicit outline_color/fill override is given) can read the
#     real resolved fill value at that same late stage, so the border
#     tracks each group's color instead of falling back to a flat default.
#
# The formal parameter list below deliberately matches the parent method's
# own signature exactly (rather than collapsing into a bare `...`), because
# ggplot2's `Geom$draw_layer()` filters the params it forwards down to
# `draw_group()` against `self$parameters()`, which - for geoms, unlike
# stats - is read directly off `draw_group`'s own formals with no
# `compute_group`-style fallback; a `...`-only signature here would make
# gghalves' `side`/`nudge` (and ggplot2's `quantile_gp`/`flipped_aes`) look
# unrecognized and get silently dropped.
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

# Fixes a crash in gghalves 0.1.4's own GeomHalfViolin$setup_params():
# `params$side <- rep(params$side, ceiling(length(unique(data$group)) /
# length(params$side)))` recycles `side` against the *count* of groups
# surviving the density stat's own n>=2 drop, not against the highest
# *original* (pre-drop, ggplot2-assigned) group id still present. When
# stat_half_ydensity() drops an early-numbered thin group (fewer than 2
# raw points on one side), later groups keep their original higher ids,
# so draw_group()'s `side[data$group[1]]` indexes past the end of the
# (too-short) recycled vector -> NA -> `if (NA)` crash ("missing value
# where TRUE/FALSE needed"). Confirmed to reproduce with plain,
# unmodified gghalves::geom_half_violin() alone on thin data - not
# specific to this package's own Stat wrapper, and not specific to a
# vector `side` (the scalar default reproduces it too). The fix below
# recycles against max(data$group) instead, so an original id is always
# in range regardless of which earlier groups got dropped. Verified
# against gghalves 0.1.4; if a future release restructures
# setup_params()/draw_group(), this will need revisiting (same caveat as
# StatHalfYdensitySD above).
#
# The "split" branch is gghalves' own unrelated split-violin feature (a
# literal `split` column in `data`) - geom_split_violin_sd() never uses
# it (it builds two independent geom_half_violin_sd() calls instead), so
# it's left verbatim/unfixed here, out of scope.
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
#' swapping it out isn't meaningful for this geom's own identity).
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
#' plot), the SD-band outline's colour tracks each group's resolved fill
#' automatically - it no longer falls back to one flat default color for
#' every group.
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
  if (!is.null(data)) data <- ungroup(data) |> droplevels()

  # `side` is passed through as-is (scalar or vector); gghalves'
  # GeomHalfViolin$setup_params() recycles it against the real, fully
  # resolved internal group order at build time. Pre-recycling it here
  # against unique(data[[x]]) would go stale the moment data isn't already
  # sorted to match factor-level order, silently mirroring violins onto the
  # wrong side.
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
  # LayerInstance objects are ordinary mutable objects, and Geom$setup_params()
  # runs at ggplot_build() time - well after construction - so reassigning
  # $geom here is equivalent to constructing with geom = GeomHalfViolinSD
  # directly (verified empirically), far less invasive than reimplementing
  # geom_half_violin()'s own construction/defaulting logic via a raw
  # layer() call. See GeomHalfViolinSD's own comment for what this fixes.
  base_layer$geom <- GeomHalfViolinSD

  # Only the aura (this layer) ever carries the legend - see the roxygen
  # Details above and GeomViolinOutline's own comment for why the SD-band
  # sub-layers below are always show.legend = FALSE instead.
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

  # Built directly via layer() rather than geom_half_violin() (which
  # constructs a plain GeomHalfViolin at the layer() call site) so this
  # sub-layer can use GeomHalfViolinOutline instead - see that ggproto's
  # own comment for why: a literal `fill = NA` geom *parameter* (the
  # previous approach here) makes ggplot2 drop `fill` from this layer's own
  # `group` computation entirely, breaking dodge alignment and per-group
  # outline coloring alike. (base_layer/fill_layer above get the same
  # GeomHalfViolinSD thin-cell fix via the post-hoc $geom reassignment
  # instead, since they don't also need a different draw_group().)
  # `position` is threaded through explicitly since layer() (unlike
  # geom_half_violin()) doesn't default it to "dodge" on its own;
  # `show.legend` is always FALSE regardless of what's in `...`, for the
  # same reason as fill_layer above.
  outline_mapping <- mapping %||% aes()
  if (length(outline_color_args) == 0) {
    # aes()$colour, not a literal quote()/bquote() call, so this is a
    # properly quosured expression exactly like aes() itself would produce -
    # see geom_split_violin_sd()'s own mapping-splicing code below for the
    # same "why not modifyList()" reasoning.
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
    # Crisp, full-opacity legend swatch (matching the aura's actual color,
    # just not its low in-panel alpha) even though the aura itself renders
    # translucent - a no-op guides() call when fill isn't mapped to
    # anything at all.
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

  if (is.null(data)) {
    stop(
      "geom_split_violin_sd() requires `data` to be supplied directly ",
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

  # best-effort diagnostic: flag x-levels missing one side entirely, or
  # below the SD-band stat's own n >= 2 minimum. Skipped silently when x
  # isn't resolvable from this layer's own `mapping` (e.g. it's inherited
  # from the plot instead).
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
  # geom_half_violin_sd()'s own outline_color %||% fill fallback can't help
  # here - fill is passed as a mapped aesthetic below, not a literal value,
  # so this wrapper has to resolve the "outline defaults to fill" fallback
  # itself.
  outline_args_left <- list(
    outline_color = if (!is.null(outline_color)) outline_color[1] else fill[1]
  )
  outline_args_right <- list(
    outline_color = if (!is.null(outline_color)) outline_color[2] else fill[2]
  )

  # fill has to be a genuinely *mapped* aesthetic (not a literal per-side
  # override, the way geom_half_violin_sd() usually takes it), or there's
  # no Scale for a legend to key off of at all.
  # NOTE: modifyList() would strip the "uneval" class aes() relies on and
  # ggplot2::layer() validates for - assign into the list directly instead
  # so the merged mapping is still recognized as built by aes().
  mapping_with_split_fill <- mapping %||% aes()
  mapping_with_split_fill$fill <- rlang::inject(aes(fill = !!split_sym))$fill

  # All 6 (or fewer) real violin sub-layers are hidden from the legend.
  # Reason: both sides map fill to the *same* scale, and when two layers
  # both have show.legend = TRUE for one scale, ggplot2 overlays every
  # contributing layer's key glyph at *every* break - so both keys end up
  # showing whichever layer's literal color/fill params were drawn last,
  # not their own. A single dedicated dummy layer below (one row per
  # level, size = 0 so invisible in-panel) avoids that entirely and is the
  # only thing that contributes to the legend.
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

  # geom_half_violin_sd() now returns its own guides() call alongside its
  # layers (see its own Details on the legend key fix), tuned for ITS
  # legend design (a single show.legend = NA aura layer with a full-opacity
  # override). That doesn't apply here - every real violin sub-layer above
  # is show.legend = FALSE, and the legend is instead carried entirely by
  # legend_layer/legend_guide below - so drop anything left_layers/
  # right_layers contributed that isn't an actual geom layer, rather than
  # stacking a second, conflicting fill guide on top of legend_guide's own.
  left_layers <- Filter(function(x) inherits(x, "LayerInstance"), left_layers)
  right_layers <- Filter(function(x) inherits(x, "LayerInstance"), right_layers)

  c(left_layers, right_layers, list(split_scale, legend_layer, legend_guide))
}

# NOTE: the mean/SD bounds below are always the *unweighted* sample
# mean/sd of the raw `y` values. If a plot maps aes(weight = ...), the
# underlying density curve respects it (inherited from StatYdensity) but
# the SD truncation band does not - it's computed from the raw data, not
# the weighted distribution. Not currently an issue in practice, but worth
# knowing if weighted data ever needs a strictly-consistent SD band.
StatYdensitySD <- ggproto(
  "StatYdensitySD",
  StatYdensity,

  # ggplot2's own `Stat$parameters()` (which layer construction uses to
  # decide whether a `...` argument is "known" or should warn "Ignoring
  # unknown parameters") normally introspects `compute_panel`'s own
  # formals - or, when `compute_panel` uses a bare `...` (as below), falls
  # back to `compute_group`'s formals instead. That fallback isn't enough
  # here: `scale` is an inherently panel-level concept (a group's width
  # relative to every *other* group sharing its panel), so it's never one
  # of `compute_group`'s formals for StatYdensity itself either - the
  # fallback would silently make `scale` look "unknown" for this stat
  # specifically (confirmed empirically), even though it's still correctly
  # forwarded to the parent below (the aura sub-layer, built on plain
  # stat_ydensity(), keeps honoring `scale` throughout regardless; only the
  # SD-band sub-layers using this stat would silently start ignoring it).
  # Overriding `parameters()` directly - reading StatYdensity's OWN
  # compute_panel formals, not this override's `...`-based one - sidesteps
  # that gap. `ggproto_formals` is itself an unexported ggplot2 helper
  # (verified present and behaving this way in ggplot2 4.0.3, same as the
  # StatHalfYdensitySD usage above) - if a future release renames/removes
  # it, this errors loudly rather than silently misbehaving.
  parameters = function(self, extra = FALSE) {
    args <- names(ggplot2:::ggproto_formals(StatYdensity$compute_panel))
    args <- setdiff(args, c("self", "data", "scales"))
    if (extra) args <- union(args, self$extra_params)
    args
  },

  # `na.rm`/`flipped_aes` are pulled out as their own formals (both used
  # directly in the bounds computation below, not just forwarded);
  # everything else - width, bw, adjust, kernel, trim, scale, bounds, and
  # any parameter ggplot2 adds to stat_ydensity() in a future release -
  # flows through `...` untouched, rather than being re-declared here.
  # This isn't just style: an earlier version of this function *did*
  # re-declare a fixed formal list (matching StatYdensity's signature at
  # the time), and by the time this was checked, ggplot2 had since added
  # `drop` and `quantiles` to StatYdensity$compute_panel() - both were
  # silently unsupported here (`geom_violin_sd(drop = FALSE)` warned
  # "Ignoring unknown parameters" from this stat while the aura layer,
  # using plain stat_ydensity(), honored it fine). `...`-forwarding fixes
  # that and stays correct going forward, backed by the `parameters()`
  # override above.
  compute_panel = function(self, data, scales, na.rm = FALSE, flipped_aes = FALSE, ...) {
    # ggplot2::StatYdensity$compute_panel() itself does data <-
    # flip_data(data, flipped_aes) as its first step, so that "y" is always
    # the continuous variable internally, then flips the *output* back to
    # the user's original orientation before returning (e.g. for
    # aes(x = value, y = group), the raw `data` we're handed still has y =
    # the discrete group and x = the continuous values - only the parent's
    # *internal* computation is canonicalized). Both our bounds computation
    # and our post-hoc truncation of its result need the same flip/unflip
    # around them, or SD bounds silently come out wrong (computed on group
    # ids, not values) for any horizontal/flipped violin.
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
#' swapping it out isn't meaningful for this geom's own identity).
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
  if (!is.null(data)) data <- ungroup(data) |> droplevels()

  dots_clean <- warn_reserved_dots(list(...), "geom_violin_sd")

  # Build fixed-aesthetic overrides only when fill is specified
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

  # Only the aura (this layer) ever carries the legend - see the roxygen
  # Details above and GeomViolinOutline's own comment for why the SD-band
  # sub-layers below are always show.legend = FALSE instead.
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

  # Built directly via layer() rather than geom_violin() (which hardcodes
  # geom = GeomViolin, with no way to swap it) so this sub-layer can use
  # GeomViolinOutline instead - see that ggproto's own comment for why: a
  # literal `fill = NA` geom *parameter* (the previous approach here) makes
  # ggplot2 drop `fill` from this layer's own `group` computation entirely,
  # breaking dodge alignment and per-group outline coloring alike.
  # `position` is threaded through explicitly since layer() (unlike
  # geom_violin()) doesn't default it to "dodge" on its own; `show.legend`
  # is always FALSE regardless of what's in `...`, for the same reason as
  # fill_layer above.
  outline_mapping <- mapping %||% aes()
  if (length(outline_color_args) == 0) {
    # aes()$colour, not a literal quote()/bquote() call, so this is a
    # properly quosured expression exactly like aes() itself would produce -
    # see geom_split_violin_sd()'s own mapping-splicing code below for the
    # same "why not modifyList()" reasoning.
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
    # Crisp, full-opacity legend swatch (matching the aura's actual color,
    # just not its low in-panel alpha) even though the aura itself renders
    # translucent - a no-op guides() call when fill isn't mapped to
    # anything at all.
    list(guides(fill = guide_legend(override.aes = list(alpha = 1))))
  )
}
