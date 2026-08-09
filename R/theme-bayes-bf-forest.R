#' Weak-evidence region + directional arrows for a log-BF axis
#'
#' A shaded "weak evidence" region + optional directional arrows/labels +
#' optional secondary linear-BF axis, for any plot with a log Bayes Factor
#' valued axis. Composable (a list of layers/annotations), not a full
#' plot-builder - add it to a ggplot you build yourself, the way
#' [layer_halfeye_hdi()] works.
#'
#' Both the arrows and their direction labels are Inf-anchored to the same
#' panel edge `weak_label` uses (top, for `orientation = "x"`; right, for
#' `"y"`), with the labels sitting right at each arrow's tip via
#' vjust/hjust nudges. Inf-anchoring costs no reserved space at all - no
#' scale expansion or `coord_cartesian(clip = "off")` is needed beyond what
#' `weak_label` already didn't need.
#'
#' @param orientation `"x"` (log-BF on the x-axis, e.g. a forest plot) or
#'   `"y"` (log-BF on the y-axis, e.g. a continuous-x sensitivity sweep).
#' @param weak_threshold Half-width of the shaded band, in log-BF units.
#'   Default `log(3)`, the Jeffreys/Lee "weak/anecdotal evidence" convention
#'   - the same convention `bayestestR::bayesfactor_rope()`'s BFs are on.
#' @param weak_label Text for the shaded band (`NULL` omits it). Anchored
#'   via `Inf` + hjust/vjust to the relevant panel edge rather than a
#'   data-dependent position.
#' @param weak_fill,weak_color Fill/text color for the shaded band and its
#'   label; default to `colors5[3]`.
#' @param direction_labels `c(positive, negative)` - text naming what a
#'   positive/negative log-BF supports (e.g. `c("supports a real
#'   difference", "supports practical equivalence")` for a ROPE comparison).
#'   `NULL` (default) omits the arrows and labels entirely.
#' @param direction_colors Length-2 colors for the positive/negative
#'   arrows/labels; defaults to `colors[1:2]`.
#' @param range `c(min, max)` the arrows should span along the BF axis.
#'   Only used when `direction_labels` is given; `NULL` falls back to a
#'   generic `c(-1, 1) * weak_threshold * 3`.
#' @param secondary_axis `FALSE` (default) or `TRUE` to add a linear-BF
#'   secondary axis via `sec.axis = dup_axis(...)` at `secondary_breaks`.
#' @param secondary_breaks Breaks for the secondary linear-BF axis.
#' @param secondary_name Axis title for the secondary linear-BF axis.
#' @return A list of `ggplot2`/`ggarrow` layers and annotations.
#' @export
layer_bf_evidence_scale <- function(
  orientation = c("x", "y"),
  weak_threshold = log(3),
  weak_label = "Weak evidence region",
  weak_fill = NULL,
  weak_color = NULL,
  direction_labels = NULL,
  direction_colors = NULL,
  range = NULL,
  secondary_axis = FALSE,
  secondary_breaks = c(1, 2, 5, 15, 50, 150),
  secondary_name = "Bayes factor (BF)"
) {
  orientation <- match.arg(orientation)
  weak_fill <- weak_fill %||% colors5[3]
  weak_color <- weak_color %||% colors5[3]
  direction_colors <- direction_colors %||% colors[1:2]

  layers <- list()

  rect_args <- if (orientation == "x") {
    list(xmin = -weak_threshold, xmax = weak_threshold, ymin = -Inf, ymax = Inf)
  } else {
    list(ymin = -weak_threshold, ymax = weak_threshold, xmin = -Inf, xmax = Inf)
  }
  layers[[length(layers) + 1]] <- do.call(
    annotate,
    c(list("rect", fill = weak_fill, alpha = .2), rect_args)
  )

  if (!is.null(weak_label)) {
    label_args <- if (orientation == "x") {
      list(x = 0, y = Inf, vjust = 1.3)
    } else {
      list(x = Inf, y = 0, hjust = 1.05, vjust = 0.5)
    }
    # annotate("richtext", ...) resolves the string "richtext" to
    # ggtext::GeomRichtext via ggplot2's validate_subclass()/find_global(),
    # which searches lexically from annotate()'s OWN enclosing environment
    # (ggplot2's namespace) - never the caller's. That's always ggtext-blind
    # from inside another package, regardless of what that package imports
    # (confirmed: still fails against a real installed build even with
    # `@importFrom ggtext GeomRichtext`, though it happens to work under
    # devtools::load_all()'s more permissive scoping - a trap). Passing the
    # actual GeomRichtext ggproto object instead of the string sidesteps the
    # lookup entirely: validate_subclass() returns an already-a-Geom object
    # as-is, no name resolution involved.
    layers[[length(layers) + 1]] <- do.call(
      annotate,
      c(
        list(
          ggtext::GeomRichtext,
          label = weak_label,
          label.color = NA,
          size = 3.2,
          label.padding = unit(rep(0.02, 4), "lines"),
          lineheight = .8,
          fill = NA,
          color = weak_color
        ),
        label_args
      )
    )
  }

  if (!is.null(direction_labels)) {
    range <- range %||% (c(-1, 1) * weak_threshold * 3)

    arrow_coords <- if (orientation == "x") {
      list(
        pos = list(x = c(0, range[2]), y = c(Inf, Inf)),
        neg = list(x = c(0, range[1]), y = c(Inf, Inf))
      )
    } else {
      list(
        pos = list(x = c(Inf, Inf), y = c(0, range[2])),
        neg = list(x = c(Inf, Inf), y = c(0, range[1]))
      )
    }

    layers[[length(layers) + 1]] <- ggarrow::annotate_arrow(
      x = arrow_coords$pos$x,
      y = arrow_coords$pos$y,
      linewidth = 1.2,
      color = direction_colors[1],
      arrow_head = ggarrow::arrow_head_wings(),
      length_head = unit(2.5, "mm")
    )
    layers[[length(layers) + 1]] <- ggarrow::annotate_arrow(
      x = arrow_coords$neg$x,
      y = arrow_coords$neg$y,
      linewidth = 1.2,
      color = direction_colors[2],
      arrow_head = ggarrow::arrow_head_wings(),
      length_head = unit(2.5, "mm")
    )

    # vjust/hjust > 1 push the label just past its Inf anchor, in text-size
    # (not data-unit) increments, so this stays proportionate across plot
    # sizes without needing a data-driven offset.
    if (orientation == "x") {
      pos_text <- list(x = range[2], y = Inf, hjust = 1, vjust = 2.6)
      neg_text <- list(x = range[1], y = Inf, hjust = 0, vjust = 2.6)
    } else {
      # vjust, not hjust, is the perpendicular-offset knob here: at angle =
      # 90 the text's own baseline runs vertically, so it's vjust that
      # pushes the label sideways, clear of the vertical arrow it's
      # labeling. hjust anchors the string's *end* (pos, hjust = 1) or
      # *start* (neg, hjust = 0) at the arrow tip, so each label reads
      # inward, back toward zero - not outward past the tip, which gets
      # clipped at the device edge regardless of plot.margin, since that
      # space isn't backed by any axis expansion.
      pos_text <- list(
        x = Inf,
        y = range[2],
        hjust = 1,
        vjust = 2.6,
        angle = 90
      )
      neg_text <- list(
        x = Inf,
        y = range[1],
        hjust = 0,
        vjust = 2.6,
        angle = 90
      )
    }
    layers[[length(layers) + 1]] <- do.call(
      annotate,
      c(
        list("text", label = direction_labels[1], color = direction_colors[1], size = 3),
        pos_text
      )
    )
    layers[[length(layers) + 1]] <- do.call(
      annotate,
      c(
        list("text", label = direction_labels[2], color = direction_colors[2], size = 3),
        neg_text
      )
    )
  }

  if (secondary_axis) {
    sec <- dup_axis(
      breaks = log(secondary_breaks),
      labels = secondary_breaks,
      name = secondary_name
    )
    layers[[length(layers) + 1]] <- if (orientation == "x") {
      scale_x_continuous(sec.axis = sec)
    } else {
      scale_y_continuous(sec.axis = sec)
    }
  }

  layers
}

#' Split a bayestestR-style contrast string into left/right columns
#'
#' Splits `bayestestR::bayesfactor_rope()`'s auto-generated `contrast`
#' column (format: `"<left> - <right>"`, reliably delimited by `" - "`
#' regardless of how many crossed factors make up each side) into separate
#' `.left`/`.right` columns, and optionally filters + reorders down to just
#' the pairs the caller actually wants to show.
#'
#' @param data `bayesfactor_rope()` output coerced to a data frame (or any
#'   data frame with a `contrast` column in that `"<left> - <right>"`
#'   format).
#' @param contrast Unquoted column holding that raw string (default
#'   `contrast`, matching bayestestR's own column name).
#' @param value Optional unquoted column - typically the log-BF/BF column
#'   itself - to sign-flip on any row matched via a swapped pair (see
#'   `pairs`), so a positive value still means whatever the caller's
#'   first-named condition supports. `NULL` (default) leaves every column
#'   as-is; if any pair needed swapping and no `value` is given, a warning
#'   names how many rows were affected.
#' @param strip A regular expression removed from each side after splitting
#'   (default `" NA$"`, since a reference grid that marginalizes over a
#'   grouping variable leaves a literal trailing "NA" token in emmeans'
#'   generated label). `NULL` disables this.
#' @param pairs Optional list of `c(left, right)` character pairs (matched,
#'   after trimming whitespace, against the split `.left`/`.right`
#'   columns). When given: keeps only matching rows, *in the order `pairs`
#'   lists them*, and errors - naming exactly which pair - if any requested
#'   pair isn't found. `NULL` (default) keeps every row, unfiltered and in
#'   `data`'s own order.
#'
#'   A pair's order does NOT have to match bayestestR's own `"<left> -
#'   <right>"` order for that contrast - a pair that only matches once
#'   `.left`/`.right` are swapped is accepted the same as a direct match;
#'   `.left`/`.right`/`.contrast_label` are then set to the *requested*
#'   order regardless of which way `data` actually had it.
#' @return `data`, with `.left`, `.right`, and `.contrast_label` columns
#'   added (and, if `pairs` was given, filtered/reordered/relabeled to
#'   match).
#' @export
prepare_bf_contrasts <- function(
  data,
  contrast = contrast,
  value = NULL,
  strip = " NA$",
  pairs = NULL
) {
  contrast_sym <- rlang::ensym(contrast)
  contrast_name <- rlang::as_name(contrast_sym)
  contrast_str <- trimws(as.character(rlang::eval_tidy(contrast_sym, data)))
  value_quo <- rlang::enquo(value)
  has_value <- !rlang::quo_is_null(value_quo)
  value_name <- if (has_value) rlang::as_name(value_quo) else NULL

  split <- strsplit(contrast_str, " - ", fixed = TRUE)
  n_pieces <- lengths(split)
  if (any(n_pieces != 2)) {
    bad <- which(n_pieces != 2)[1]
    stop(
      "prepare_bf_contrasts(): row ", bad, "'s `", contrast_name, "` (\"",
      contrast_str[bad], "\") doesn't split into exactly 2 pieces on ",
      "\" - \" - is it really in bayestestR's \"<left> - <right>\" format?",
      call. = FALSE
    )
  }

  left <- vapply(split, `[`, character(1), 1)
  right <- vapply(split, `[`, character(1), 2)
  if (!is.null(strip)) {
    left <- trimws(gsub(strip, "", left))
    right <- trimws(gsub(strip, "", right))
  }
  data$.left <- left
  data$.right <- right

  if (!is.null(pairs)) {
    pair_left <- trimws(vapply(pairs, `[`, character(1), 1))
    pair_right <- trimws(vapply(pairs, `[`, character(1), 2))

    row_idx <- integer(length(pairs))
    reversed <- logical(length(pairs))
    for (i in seq_along(pairs)) {
      direct_match <- which(data$.left == pair_left[i] & data$.right == pair_right[i])
      if (length(direct_match) >= 1) {
        row_idx[i] <- direct_match[1]
        reversed[i] <- FALSE
        next
      }
      swapped_match <- which(data$.left == pair_right[i] & data$.right == pair_left[i])
      if (length(swapped_match) >= 1) {
        row_idx[i] <- swapped_match[1]
        reversed[i] <- TRUE
      } else {
        row_idx[i] <- NA_integer_
        reversed[i] <- NA
      }
    }

    unmatched <- is.na(row_idx)
    if (any(unmatched)) {
      bad <- which(unmatched)[1]
      stop(
        "prepare_bf_contrasts(): requested pair c(\"", pair_left[bad],
        "\", \"", pair_right[bad], "\") not found in `data` in either order (",
        sum(unmatched), " of ", length(pairs), " requested pair(s) missing ",
        "in total) - check unique(data$", contrast_name, ") for the exact ",
        "available strings.",
        call. = FALSE
      )
    }

    data <- data[row_idx, , drop = FALSE]
    # relabel to the *requested* order regardless of which way `data` had
    # it, so `.contrast_label` (and any downstream use of `.left`/`.right`)
    # always reflects what the caller asked for, not bayestestR's own
    # arbitrary enumeration order.
    data$.left <- pair_left
    data$.right <- pair_right

    if (any(reversed)) {
      if (has_value) {
        data[[value_name]][reversed] <- -data[[value_name]][reversed]
      } else {
        warning(
          "prepare_bf_contrasts(): ", sum(reversed), " of ", length(pairs),
          " requested pair(s) matched `data` in reversed order; pass ",
          "`value` (e.g. the log-BF column) so it can be sign-flipped to ",
          "match the requested order - otherwise the returned rows are ",
          "relabeled but their value column(s) still reflect the original ",
          "direction.",
          call. = FALSE
        )
      }
    }
  }

  data$.contrast_label <- paste(data$.left, "vs.", data$.right)
  data
}

#' Log Bayes Factor forest plot
#'
#' One row per contrast, point (+/- optional SE), colored by sign, with
#' [layer_bf_evidence_scale()]'s weak-evidence-region annotation bundled in
#' by default.
#'
#' @param data A data frame with one row per contrast.
#' @param contrast Unquoted column with the contrast label. If `pairs` is
#'   given, this is treated as bayestestR's raw `"<left> - <right>"` string
#'   and run through [prepare_bf_contrasts()] first; otherwise used directly
#'   as the display label, unchanged.
#' @param log_bf Unquoted column of log Bayes Factors.
#' @param se Optional unquoted column of standard errors (`NULL` omits the
#'   errorbar - a Bayes Factor from a single `bayesfactor_rope()` call,
#'   unlike a repeated bridge-sampling estimate, has no natural per-contrast
#'   SE at all, and that's a fully supported, first-class case here, not a
#'   fallback).
#' @param pairs Optional list of `c(left, right)` pairs; see
#'   [prepare_bf_contrasts()]. A pair matched in reversed order gets its
#'   sign flipped automatically (via `log_bf` passed as `prepare_bf_contrasts()`'s
#'   `value`).
#' @param contrast_strip Passed to `prepare_bf_contrasts()`'s `strip` when
#'   `pairs` is given.
#' @param contrast_reorder `TRUE` (default) sorts rows by `log_bf`; `FALSE`
#'   keeps `pairs`' own order (or `data`'s own order, if `pairs` wasn't
#'   used).
#' @param positive_color,negative_color Colors for positive/negative
#'   contrasts; default to `colors[1]`/`colors[2]`.
#' @param positive_shape,negative_shape Point shapes for positive/negative
#'   contrasts. Color and shape both carry sign, redundantly, so direction
#'   stays legible under grayscale printing or for red/green-blind readers.
#' @param point_size Size of the contrast points.
#' @param evidence_scale `TRUE` (default) bundles [layer_bf_evidence_scale()]
#'   in automatically, with `range` computed from `data` itself; `FALSE` for
#'   a bare forest plot with no annotation.
#' @param weak_threshold,weak_label Passed to `layer_bf_evidence_scale()`
#'   when `evidence_scale = TRUE`.
#' @param direction_labels,secondary_axis,secondary_breaks Passed through to
#'   `layer_bf_evidence_scale()` when `evidence_scale = TRUE`.
#' @param xlab,ylab Axis labels.
#' @return A `ggplot` object.
#' @export
plot_bf_forest <- function(
  data,
  contrast,
  log_bf,
  se = NULL,
  pairs = NULL,
  contrast_strip = " NA$",
  contrast_reorder = TRUE,
  positive_color = NULL,
  negative_color = NULL,
  positive_shape = 16,
  negative_shape = 17,
  point_size = 3,
  evidence_scale = TRUE,
  weak_threshold = log(3),
  weak_label = "Weak evidence region",
  direction_labels = NULL,
  secondary_axis = FALSE,
  secondary_breaks = c(1, 2, 5, 15, 50, 150),
  xlab = NULL,
  ylab = "Contrast"
) {
  contrast_sym <- rlang::ensym(contrast)
  log_bf_sym <- rlang::ensym(log_bf)
  se_quo <- rlang::enquo(se)
  has_se <- !rlang::quo_is_null(se_quo)

  if (!is.null(pairs)) {
    data <- rlang::inject(prepare_bf_contrasts(
      data,
      contrast = !!contrast_sym,
      value = !!log_bf_sym,
      strip = contrast_strip,
      pairs = pairs
    ))
    contrast_sym <- rlang::sym(".contrast_label")
  }

  positive_color <- positive_color %||% colors[1]
  negative_color <- negative_color %||% colors[2]

  plot_data <- data
  plot_data$.log_bf <- rlang::eval_tidy(log_bf_sym, data)
  plot_data$.sign <- ifelse(plot_data$.log_bf >= 0, "positive", "negative")
  if (has_se) {
    plot_data$.se <- rlang::eval_tidy(se_quo, data)
  }

  x_expr <- if (contrast_reorder) {
    rlang::expr(forcats::fct_reorder(!!contrast_sym, .data$.log_bf))
  } else {
    contrast_sym
  }

  xlab <- xlab %||%
    if (has_se) "log Bayes factor \u00b1SE" else "log Bayes factor"

  p <- ggplot(
    plot_data,
    aes(y = !!x_expr, x = .data$.log_bf, color = .data$.sign, shape = .data$.sign)
  ) +
    # establishes the y scale as discrete *before* any annotate()-based
    # layer below (which have inherit.aes = FALSE and, for the
    # evidence-scale layer's arrows/labels, a raw numeric y position) gets
    # a chance to. Without this, an annotate() layer with a bare numeric y,
    # if processed before any layer supplying the real discrete factor,
    # makes ggplot2 infer a *continuous* y scale, and every subsequent
    # discrete-y layer then fails with "Discrete value supplied to a
    # continuous scale." A blank layer trains the scale without affecting
    # the visual stacking order, so the evidence-scale annotation can still
    # be added right after and still render behind the real data points.
    geom_blank()

  if (evidence_scale) {
    abs_extent <- max(
      abs(plot_data$.log_bf - (if (has_se) plot_data$.se else 0)),
      abs(plot_data$.log_bf + (if (has_se) plot_data$.se else 0)),
      na.rm = TRUE
    )
    arrow_range <- c(-1, 1) * max(abs_extent, weak_threshold) * 1.15

    p <- p +
      layer_bf_evidence_scale(
        orientation = "x",
        weak_threshold = weak_threshold,
        weak_label = weak_label,
        range = arrow_range,
        direction_labels = direction_labels,
        secondary_axis = secondary_axis,
        secondary_breaks = secondary_breaks
      )
  }

  if (has_se) {
    p <- p +
      geom_errorbar(
        aes(xmin = .data$.log_bf - .data$.se, xmax = .data$.log_bf + .data$.se),
        width = 0
      )
  }

  p +
    geom_point(size = point_size) +
    scale_color_manual(
      values = c(positive = positive_color, negative = negative_color)
    ) +
    scale_shape_manual(
      values = c(positive = positive_shape, negative = negative_shape)
    ) +
    guides(color = "none", shape = "none") +
    labs(x = xlab, y = ylab) +
    # right-align the contrast labels against the axis line, matching
    # plot_ridge_hdi()'s axis.text.y (see its own comment on why both the
    # base and position-suffixed elements need setting). Axis titles are
    # guarded the same way (see plot_location_scale()'s own comment) since,
    # like that function, there's no coord_flip() here.
    theme(
      axis.text.y = element_markdown(hjust = 1),
      axis.text.y.left = element_markdown(hjust = 1),
      axis.text.y.right = element_markdown(hjust = 1),
      axis.title.x = element_markdown(),
      axis.title.x.top = element_markdown(),
      axis.title.y = element_markdown(),
      axis.title.y.right = element_markdown()
    )
}
