# include a way to visualize SDs in the half-violin plots I like so much; based on the results in @zhang2023inferentialuncertainty;@hofmann2025anaphoric; see also @hoekstra2014confidenceintervals

# alpha/color/colour/fill/linewidth/trim are always set internally by the
# three sub-layers (base "aura", SD fill, SD outline) of geom_violin_sd() /
# geom_half_violin_sd(); warn instead of silently dropping or erroring
# (duplicate-argument) if the caller also passes them via `...`.
warn_reserved_dots <- function(dots, geom_name) {
  reserved <- c("alpha", "color", "colour", "linewidth", "trim")
  ignored <- intersect(names(dots), reserved)
  if (length(ignored) > 0) {
    warning(
      geom_name,
      "() ignores ",
      paste(sprintf("`%s`", ignored), collapse = ", "),
      " passed via `...` (these are controlled by base_alpha/sd_alpha/",
      "outline_color/sd_linewidth, and trim is always FALSE).",
      call. = FALSE
    )
  }
  dots[!names(dots) %in% reserved]
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

  compute_panel = function(
    self,
    data,
    scales,
    width = NULL,
    bw = "nrd0",
    adjust = 1,
    kernel = "gaussian",
    trim = FALSE,
    scale = "area",
    na.rm = FALSE
  ) {
    bounds <- data |>
      group_by(group) |>
      summarise(
        n = sum(!is.na(y)),
        lo = mean(y, na.rm = na.rm) - sd(y, na.rm = na.rm),
        hi = mean(y, na.rm = na.rm) + sd(y, na.rm = na.rm),
        .groups = "drop"
      ) |>
      filter(n >= 2)

    result <- gghalves:::StatHalfYdensity$compute_panel(
      data,
      scales,
      width = width,
      bw = bw,
      adjust = adjust,
      kernel = kernel,
      trim = trim,
      scale = scale,
      na.rm = na.rm
    )

    result <- lapply(unique(result$group), function(g) {
      grp <- result[result$group == g, ]
      lo <- bounds$lo[match(g, bounds$group)]
      hi <- bounds$hi[match(g, bounds$group)]
      grp[grp$y >= lo & grp$y <= hi, ]
    }) |>
      bind_rows()

    result
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
#' `alpha`/`color`/`colour`/`linewidth`/`trim` passed via `...` are reserved
#' (used internally by the aura/fill/outline sub-layers) and will warn, not
#' error or silently vanish - use `base_alpha`/`sd_alpha`/`outline_color`/
#' `sd_linewidth` instead.
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
#' @param mapping,data,...,inherit.aes As in [gghalves::geom_half_violin()].
#' @param fill A constant fill for all violins; omit it to map fill via
#'   `mapping` instead (`aes(fill = ...)`) the normal ggplot2 way.
#' @param side Which side to draw the half-violin on - `"l"` or `"r"`, or a
#'   vector thereof (see Details).
#' @param style One of `"both"` (default), `"fill"`, or `"outline"` - which
#'   SD-band sub-layer(s) to draw.
#' @param base_alpha,sd_alpha Alpha of the aura and SD-band sub-layers.
#' @param outline_color Color of the SD-band outline; defaults to `fill`
#'   when not given.
#' @param sd_linewidth Line width of the SD-band outline.
#' @return A list of `ggplot2` layers.
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
        trim = FALSE,
        side = side
      ),
      fill_args,
      dots_clean
    )
  )

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
        trim = FALSE,
        side = side
      ),
      fill_args,
      dots_clean
    )
  )

  outline_layer <- do.call(
    geom_half_violin,
    c(
      list(
        data = data,
        mapping = mapping,
        stat = StatHalfYdensitySD,
        inherit.aes = inherit.aes,
        alpha = 1,
        fill = NA,
        linewidth = sd_linewidth,
        trim = FALSE,
        side = side
      ),
      outline_color_args,
      dots_clean
    )
  )

  sd_layers <- switch(
    style,
    fill = list(fill_layer),
    outline = list(outline_layer),
    both = list(fill_layer, outline_layer)
  )

  c(list(base_layer), sd_layers)
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
#' Warns (does not silently drop) when an x-level has data on only one side
#' of the split, or when a side's cell count falls under the `n >= 2`
#' minimum the underlying SD-band stat already requires - splitting divides
#' already-thin repeated-measures cells a third way.
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
#' @param style,base_alpha,sd_alpha,sd_linewidth As in
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
        inherit.aes = inherit.aes,
        show.legend = FALSE
      ),
      outline_args_right,
      dots_clean
    )
  )

  split_scale <- scale_fill_manual(
    name = split_name,
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

  compute_panel = function(
    self,
    data,
    scales,
    width = NULL,
    bw = "nrd0",
    adjust = 1,
    kernel = "gaussian",
    trim = FALSE,
    scale = "area",
    na.rm = FALSE,
    flipped_aes = FALSE,
    bounds = c(-Inf, Inf) # absorb ggplot2's `bounds` param silently
  ) {
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
    grp_bounds <- canonical_data |>
      group_by(group) |>
      summarise(
        n = sum(!is.na(y)),
        lo = mean(y, na.rm = na.rm) - sd(y, na.rm = na.rm),
        hi = mean(y, na.rm = na.rm) + sd(y, na.rm = na.rm),
        .groups = "drop"
      ) |>
      filter(n >= 2)

    result <- StatYdensity$compute_panel(
      data,
      scales,
      width = width,
      bw = bw,
      adjust = adjust,
      kernel = kernel,
      trim = trim,
      scale = scale,
      na.rm = na.rm,
      flipped_aes = flipped_aes,
      bounds = bounds # pass it through to the parent
    )

    canonical_result <- flip_data(result, flipped_aes)
    canonical_result <- lapply(unique(canonical_result$group), function(g) {
      grp <- canonical_result[canonical_result$group == g, ]
      lo <- grp_bounds$lo[match(g, grp_bounds$group)]
      hi <- grp_bounds$hi[match(g, grp_bounds$group)]
      grp[grp$y >= lo & grp$y <= hi, ]
    }) |>
      bind_rows()

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
#' `alpha`/`color`/`colour`/`linewidth`/`trim` passed via `...` are reserved
#' (used internally by the aura/fill/outline sub-layers) and will warn, not
#' error or silently vanish - use `base_alpha`/`sd_alpha`/`outline_color`/
#' `sd_linewidth` instead.
#'
#' SD bounds are always the *unweighted* mean/sd of the raw y values, even
#' if `aes(weight = ...)` is mapped.
#'
#' @inheritParams geom_half_violin_sd
#' @return A list of `ggplot2` layers.
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
        trim = FALSE
      ),
      fill_args,
      dots_clean
    )
  )

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
        trim = FALSE
      ),
      fill_args,
      dots_clean
    )
  )

  outline_color_args <- if (!is.null(outline_color)) {
    list(color = outline_color)
  } else {
    list()
  }

  outline_layer <- do.call(
    geom_violin,
    c(
      list(
        data = data,
        mapping = mapping,
        stat = StatYdensitySD,
        inherit.aes = inherit.aes,
        alpha = 1,
        fill = NA,
        linewidth = sd_linewidth,
        trim = FALSE
      ),
      outline_color_args,
      dots_clean
    )
  )

  sd_layers <- switch(
    style,
    fill = list(fill_layer),
    outline = list(outline_layer),
    both = list(fill_layer, outline_layer)
  )

  c(list(base_layer), sd_layers)
}
