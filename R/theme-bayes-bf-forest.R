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
#' @param weak_fill,weak_color Fill of the shaded band and colour of its
#'   label. `NULL` (default) uses `mt_colors5[3]` for the band and a darker
#'   shade of it for the label, chosen so the label keeps 4.5:1 contrast
#'   against the band; under a dark theme, such as `theme_mt(dark = TRUE)`,
#'   both use `dark_mt_colors5[3]`.
#' @param direction_labels `c(positive, negative)` - text naming what a
#'   positive/negative log-BF supports (e.g. `c("supports a real
#'   difference", "supports practical equivalence")` for a ROPE comparison).
#'   `NULL` (default) omits the arrows and labels entirely.
#' @param direction_colors Length-2 colors for the positive/negative
#'   arrows/labels. `NULL` (default) uses `mt_colors[1:2]`, or
#'   `dark_mt_colors[1:2]` under a dark theme.
#' @param arrow_range `c(min, max)` the arrows should span along the BF axis.
#'   Only used when `direction_labels` is given; `NULL` falls back to a
#'   generic `c(-1, 1) * weak_threshold * 3`.
#' @param secondary_axis `FALSE` (default) or `TRUE` to add a linear-BF
#'   secondary axis via `sec.axis = dup_axis(...)` at `secondary_breaks`.
#' @param secondary_breaks Breaks for the secondary linear-BF axis.
#' @param secondary_name Axis title for the secondary linear-BF axis.
#' @return A list of `ggplot2`/`ggarrow` layers and annotations.
#' @examples
#' library(ggplot2)
#' df <- data.frame(x = 1:3, log_bf = c(-2.1, 0.3, 4.8))
#' ggplot(df, aes(x, log_bf)) +
#'   geom_point() +
#'   layer_bf_evidence_scale(
#'     orientation = "y",
#'     direction_labels = c("supports difference", "supports equivalence")
#'   )
#' @export
layer_bf_evidence_scale <- function(
  orientation = c("x", "y"),
  weak_threshold = log(3),
  weak_label = "Weak evidence region",
  weak_fill = NULL,
  weak_color = NULL,
  direction_labels = NULL,
  direction_colors = NULL,
  arrow_range = NULL,
  secondary_axis = FALSE,
  secondary_breaks = c(1, 2, 5, 15, 50, 150),
  secondary_name = "Bayes factor (BF)"
) {
  orientation <- match.arg(orientation)
  weak_fill_spec <- .colour_spec(
    weak_fill, "fill", mt_colors5[3], dark_mt_colors5[3]
  )
  weak_colour_spec <- .colour_spec(
    weak_color, "colour", .weak_label_light, dark_mt_colors5[3]
  )
  direction_specs <- list(
    .colour_spec(direction_colors[1], "colour", mt_colors[1], dark_mt_colors[1]),
    .colour_spec(direction_colors[2], "colour", mt_colors[2], dark_mt_colors[2])
  )

  layers <- list()

  rect_data <- if (orientation == "x") {
    data.frame(xmin = -weak_threshold, xmax = weak_threshold, ymin = -Inf, ymax = Inf)
  } else {
    data.frame(ymin = -weak_threshold, ymax = weak_threshold, xmin = -Inf, xmax = Inf)
  }
  layers[[length(layers) + 1]] <- .annotation_layer(
    GeomRect,
    data = rect_data,
    mapping = .merge_aes(
      aes(
        xmin = .data$xmin, xmax = .data$xmax,
        ymin = .data$ymin, ymax = .data$ymax
      ),
      weak_fill_spec$mapping
    ),
    params = c(list(alpha = .2), weak_fill_spec$params)
  )

  if (!is.null(weak_label)) {
    label_data <- if (orientation == "x") {
      data.frame(x = 0, y = Inf)
    } else {
      data.frame(x = Inf, y = 0)
    }
    label_just <- if (orientation == "x") {
      list(vjust = 1.3)
    } else {
      list(hjust = 1.05, vjust = 0.5)
    }
    # The GeomRichtext object itself, not the string "richtext": ggplot2
    # resolves a geom name from its own namespace, where ggtext is not
    # visible once this package is installed.
    layers[[length(layers) + 1]] <- .annotation_layer(
      ggtext::GeomRichtext,
      data = label_data,
      mapping = .merge_aes(aes(x = .data$x, y = .data$y), weak_colour_spec$mapping),
      params = c(
        list(
          label = weak_label,
          label.colour = NA,
          size = 3.2,
          label.padding = unit(rep(0.02, 4), "lines"),
          lineheight = .8,
          fill = NA
        ),
        label_just,
        weak_colour_spec$params
      )
    )
  }

  if (!is.null(direction_labels)) {
    arrow_range <- arrow_range %||% (c(-1, 1) * weak_threshold * 3)

    arrow_data <- if (orientation == "x") {
      list(
        data.frame(x = c(0, arrow_range[2]), y = c(Inf, Inf)),
        data.frame(x = c(0, arrow_range[1]), y = c(Inf, Inf))
      )
    } else {
      list(
        data.frame(x = c(Inf, Inf), y = c(0, arrow_range[2])),
        data.frame(x = c(Inf, Inf), y = c(0, arrow_range[1]))
      )
    }

    # The labels sit at the arrow tips. vjust > 1 pushes a label just past
    # its Inf anchor in text-size increments, so the offset stays
    # proportionate across plot sizes. With orientation = "y" the text is
    # rotated, so vjust moves it sideways, clear of the vertical arrow, and
    # hjust anchors each label's end (positive) or start (negative) at the
    # tip so that it reads back towards zero instead of running off the
    # panel.
    text_data <- if (orientation == "x") {
      list(data.frame(x = arrow_range[2], y = Inf), data.frame(x = arrow_range[1], y = Inf))
    } else {
      list(data.frame(x = Inf, y = arrow_range[2]), data.frame(x = Inf, y = arrow_range[1]))
    }
    text_params <- if (orientation == "x") {
      list(list(hjust = 1, vjust = 2.6), list(hjust = 0, vjust = 2.6))
    } else {
      list(
        list(hjust = 1, vjust = 2.6, angle = 90),
        list(hjust = 0, vjust = 2.6, angle = 90)
      )
    }

    for (i in 1:2) {
      # geom_arrow() rather than .annotation_layer(): it translates
      # `arrow_head`/`length_head` into GeomArrow's own parameters.
      layers[[length(layers) + 1]] <- do.call(
        ggarrow::geom_arrow,
        c(
          list(
            data = arrow_data[[i]],
            mapping = .merge_aes(aes(x = .data$x, y = .data$y), direction_specs[[i]]$mapping),
            inherit.aes = FALSE,
            show.legend = FALSE,
            linewidth = 1.2,
            arrow_head = ggarrow::arrow_head_wings(),
            length_head = unit(2.5, "mm")
          ),
          direction_specs[[i]]$params
        )
      )
    }
    for (i in 1:2) {
      layers[[length(layers) + 1]] <- .annotation_layer(
        GeomText,
        data = text_data[[i]],
        mapping = .merge_aes(aes(x = .data$x, y = .data$y), direction_specs[[i]]$mapping),
        params = c(
          list(label = direction_labels[i], size = 3),
          text_params[[i]],
          direction_specs[[i]]$params
        )
      )
    }
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
#' @param value Optional column(s) to negate on any row matched via a swapped
#'   pair (see `pairs`), so that a positive value still favours the caller's
#'   first-named condition. Takes a bare column name or a tidyselect
#'   selection such as `c(estimate, log_BF)`. Select only columns whose sign
#'   depends on the direction of the contrast: an estimated difference, or
#'   the log Bayes factor of an order-restricted test (H1: A > B against H2:
#'   A < B). Do *not* select the log Bayes factor of a ROPE test
#'   (`bayestestR::bayesfactor_rope()`) or of a two-sided point null: their
#'   hypotheses are symmetric in the two conditions, so reversing the
#'   contrast leaves the Bayes factor unchanged. A ratio-scale Bayes factor
#'   is inverted, not negated, by a reversal; take its `log()` first.
#'   Interval bounds need swapping as well as negating, so negating them
#'   here would produce a reversed interval. Columns not selected keep their
#'   values. `NULL` (default) selects nothing.
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
#'   order regardless of which way `data` actually had it, and the columns
#'   selected by `value` are negated.
#'
#'   Two entries can therefore resolve to the *same* row of `data` - either
#'   as an outright repeat, or as the two directions of one contrast
#'   (`c("a", "b")` and `c("b", "a")`, the second relabeled, with its `value`
#'   columns negated). Both are allowed and warn: each becomes its own output
#'   row, so a forest plot built from the result shows one estimate as
#'   several, which reads as several independent ones. Drop the duplicate if
#'   that wasn't the intent.
#' @return `data`, with `.left`, `.right`, and `.contrast_label` columns
#'   added (and, if `pairs` was given, filtered/reordered/relabeled to
#'   match).
#' @examples
#' bf <- data.frame(
#'   contrast = c("a - b NA", "c - d NA"),
#'   estimate = c(0.9, -0.2),
#'   log_BF = c(1.2, -0.3)
#' )
#' prepare_bf_contrasts(bf)
#' # "b vs. a" matches "a - b" reversed: the estimated difference is negated,
#' # the ROPE log Bayes factor is not
#' prepare_bf_contrasts(bf, value = estimate, pairs = list(c("b", "a")))
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
  value_names <- if (has_value) {
    names(dplyr::select(as.data.frame(data), !!value_quo))
  }
  not_numeric <- value_names[!vapply(
    value_names, function(col) is.numeric(data[[col]]), logical(1)
  )]
  if (length(not_numeric) > 0) {
    stop(
      "prepare_bf_contrasts(): `value` must select numeric columns; ",
      paste0("`", not_numeric, "`", collapse = ", "), " is not.",
      call. = FALSE
    )
  }

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

    # Two requested pairs can resolve to one source row - an outright
    # repeat, or the two directions of the same contrast. Neither is an
    # error (the caller may genuinely want both directions shown), but on a
    # forest plot the same estimate then appears as two rows, which reads as
    # two independent ones. Warn rather than silently duplicating.
    duplicated_rows <- unique(row_idx[duplicated(row_idx)])
    if (length(duplicated_rows) > 0) {
      offenders <- vapply(duplicated_rows, function(row) {
        i <- which(row_idx == row)
        paste0(
          sprintf('c("%s", "%s")', pair_left[i], pair_right[i]),
          collapse = " and "
        )
      }, character(1))
      warning(
        "prepare_bf_contrasts(): ",
        paste(offenders, collapse = "; "),
        " resolve to the same row of `data`, so the same estimate appears ",
        "more than once in the output - on a forest plot that reads as ",
        "several independent estimates. Requesting both directions of a ",
        "pair is supported (the reversed one is relabeled, with its `value` ",
        "columns negated); ",
        "drop the duplicate if it wasn't intended.",
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

    # Only the columns `value` names change sign. A reversed match without
    # `value` is not an error: the log Bayes factors of ROPE and two-sided
    # point-null tests do not depend on the direction of the contrast.
    for (col in value_names) {
      data[[col]][reversed] <- -data[[col]][reversed]
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
#'   [prepare_bf_contrasts()]. A pair matched in reversed order is relabeled
#'   to the requested order; whether its `log_bf` changes sign is set by
#'   `negate_reversed`.
#' @param negate_reversed Whether `log_bf` is negated for a pair that `pairs`
#'   matches in reversed order. `FALSE` (default) is correct for Bayes
#'   factors whose hypotheses are symmetric in the two conditions, such as a
#'   ROPE test (`bayestestR::bayesfactor_rope()`) or a two-sided point null:
#'   reversing the contrast does not change them. Set `TRUE` only when
#'   reversing the contrast swaps the two hypotheses, as for an
#'   order-restricted test of H1: A > B against H2: A < B.
#' @param contrast_strip Passed to `prepare_bf_contrasts()`'s `strip` when
#'   `pairs` is given.
#' @param contrast_reorder `TRUE` (default) sorts rows by `log_bf`; `FALSE`
#'   keeps `pairs`' own order (or `data`'s own order, if `pairs` wasn't
#'   used).
#' @param positive_color,negative_color Colors for positive/negative
#'   contrasts. `NULL` (default) uses `mt_colors[1]`/`mt_colors[2]`, or
#'   `dark_mt_colors[1]`/`dark_mt_colors[2]` under a dark theme such as
#'   `theme_mt(dark = TRUE)`.
#' @param positive_shape,negative_shape Point shapes for positive/negative
#'   contrasts. Color and shape both carry sign, redundantly, so direction
#'   stays legible under grayscale printing or for red/green-blind readers.
#' @param point_size Size of the contrast points.
#' @param evidence_scale `TRUE` (default) bundles [layer_bf_evidence_scale()]
#'   in automatically, with `arrow_range` computed from `data` itself; `FALSE` for
#'   a bare forest plot with no annotation.
#' @param weak_threshold,weak_label Passed to `layer_bf_evidence_scale()`
#'   when `evidence_scale = TRUE`.
#' @param direction_labels,secondary_axis,secondary_breaks Passed through to
#'   `layer_bf_evidence_scale()` when `evidence_scale = TRUE`.
#' @param xlab,ylab Axis labels.
#' @return A `ggplot` object.
#' @examples
#' bf_data <- data.frame(
#'   contrast = c("A vs. B", "C vs. D", "E vs. F"),
#'   log_bf = c(8.2, 1.1, -0.4)
#' )
#' plot_bf_forest(
#'   bf_data,
#'   contrast = contrast,
#'   log_bf = log_bf,
#'   direction_labels = c("supports difference", "supports equivalence")
#' )
#' @export
plot_bf_forest <- function(
  data,
  contrast,
  log_bf,
  se = NULL,
  pairs = NULL,
  negate_reversed = FALSE,
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
  if (missing(contrast)) {
    stop("plot_bf_forest(): `contrast` is required.", call. = FALSE)
  }
  if (missing(log_bf)) {
    stop("plot_bf_forest(): `log_bf` is required.", call. = FALSE)
  }
  contrast_sym <- rlang::ensym(contrast)
  log_bf_sym <- rlang::ensym(log_bf)
  se_quo <- rlang::enquo(se)
  has_se <- !rlang::quo_is_null(se_quo)

  if (!is.null(pairs)) {
    data <- rlang::inject(prepare_bf_contrasts(
      data,
      contrast = !!contrast_sym,
      value = !!(if (negate_reversed) log_bf_sym),
      strip = contrast_strip,
      pairs = pairs
    ))
    contrast_sym <- rlang::sym(".contrast_label")
  }

  plot_data <- data
  plot_data$.log_bf <- rlang::eval_tidy(log_bf_sym, data)
  plot_data$.sign <- ifelse(plot_data$.log_bf >= 0, "positive", "negative")
  if (has_se) {
    plot_data$.se <- rlang::eval_tidy(se_quo, data)
  }

  # Checked whether or not rows are reordered: without a finite value, the
  # arrow range below would become infinite.
  if (!any(is.finite(plot_data$.log_bf))) {
    stop(
      "plot_bf_forest(): `log_bf` has no finite values - nothing to plot.",
      call. = FALSE
    )
  }

  # The row order is fixed here, on the full data, because the points are
  # drawn by one layer per sign (see below), each of which sees only its own
  # rows. .check_reorder_values() turns forcats' error for a contrast without
  # a non-NA log_bf (with one row per contrast: any NA row) into one that
  # names this function.
  contrast_values <- rlang::eval_tidy(contrast_sym, plot_data)
  # With `pairs`, prepare_bf_contrasts() has already warned about repeats.
  repeated <- unique(contrast_values[duplicated(contrast_values) & !is.na(contrast_values)])
  if (is.null(pairs) && length(repeated) > 0) {
    warning(
      "plot_bf_forest(): ",
      paste(sQuote(as.character(repeated), q = FALSE), collapse = ", "),
      if (length(repeated) == 1) " labels" else " label",
      " more than one row; those rows share one line of the plot.",
      call. = FALSE
    )
  }
  plot_data$.contrast <- if (contrast_reorder) {
    .check_reorder_values(
      values = plot_data$.log_bf,
      categories = contrast_values,
      fn = "plot_bf_forest",
      value_arg = "log_bf",
      reorder_arg = "contrast_reorder"
    )
    forcats::fct_reorder(contrast_values, plot_data$.log_bf)
  } else {
    contrast_values
  }

  xlab <- xlab %||%
    if (has_se) "log Bayes factor \u00b1SE" else "log Bayes factor"

  p <- ggplot(
    plot_data,
    aes(y = .data$.contrast, x = .data$.log_bf, shape = .data$.sign)
  ) +
    # Trains the y scale as discrete before the evidence-scale layers, whose
    # numeric Inf positions would otherwise make it continuous. A blank layer
    # does not change what is drawn on top of what.
    geom_blank()

  if (evidence_scale) {
    # Filtered rather than na.rm-ed: na.rm drops NA but keeps Inf, so a
    # single infinite log_bf (a perfectly ordinary Bayes Factor result) would
    # still stretch the arrow range to infinity. The all-non-finite case is
    # already ruled out by the guard above, so this can't be empty.
    extent_values <- c(
      plot_data$.log_bf - (if (has_se) plot_data$.se else 0),
      plot_data$.log_bf + (if (has_se) plot_data$.se else 0)
    )
    extent_values <- extent_values[is.finite(extent_values)]
    abs_extent <- if (length(extent_values) > 0) max(abs(extent_values)) else 0
    arrow_range <- c(-1, 1) * max(abs_extent, weak_threshold) * 1.15

    p <- p +
      layer_bf_evidence_scale(
        orientation = "x",
        weak_threshold = weak_threshold,
        weak_label = weak_label,
        arrow_range = arrow_range,
        direction_labels = direction_labels,
        secondary_axis = secondary_axis,
        secondary_breaks = secondary_breaks
      )
  }

  # One layer per sign rather than a colour scale, so that each default
  # colour can follow the theme (a scale's values are fixed literals).
  sign_colours <- list(
    positive = .colour_spec(positive_color, "colour", mt_colors[1], dark_mt_colors[1]),
    negative = .colour_spec(negative_color, "colour", mt_colors[2], dark_mt_colors[2])
  )
  sign_layers <- function(geom, mapping = aes(), params = list()) {
    lapply(names(sign_colours), function(sign) {
      spec <- sign_colours[[sign]]
      do.call(geom, c(
        list(
          data = function(d) d[d$.sign %in% sign, , drop = FALSE],
          mapping = .merge_aes(mapping, spec$mapping)
        ),
        params,
        spec$params
      ))
    })
  }

  if (has_se) {
    p <- p +
      sign_layers(
        geom_errorbar,
        aes(xmin = .data$.log_bf - .data$.se, xmax = .data$.log_bf + .data$.se),
        list(width = 0)
      )
  }

  p +
    sign_layers(geom_point, params = list(size = point_size)) +
    scale_shape_manual(
      values = c(positive = positive_shape, negative = negative_shape)
    ) +
    guides(shape = "none") +
    labs(x = xlab, y = ylab) +
    # Right-aligned contrast labels and markdown-aware axis titles, set on
    # base and position-specific elements as in plot_ridge_hdi().
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
