test_that("layer_bf_evidence_scale() always returns a shaded rect, with the correct bounds per orientation", {
  layers_x <- layer_bf_evidence_scale(orientation = "x", weak_threshold = log(3))
  expect_true(inherits(layers_x[[1]]$geom, "GeomRect"))
  expect_equal(layers_x[[1]]$data$xmin, -log(3))
  expect_equal(layers_x[[1]]$data$xmax, log(3))
  expect_equal(layers_x[[1]]$data$ymin, -Inf)
  expect_equal(layers_x[[1]]$data$ymax, Inf)

  layers_y <- layer_bf_evidence_scale(orientation = "y", weak_threshold = log(3))
  expect_equal(layers_y[[1]]$data$ymin, -log(3))
  expect_equal(layers_y[[1]]$data$ymax, log(3))
  expect_equal(layers_y[[1]]$data$xmin, -Inf)
  expect_equal(layers_y[[1]]$data$xmax, Inf)
})

test_that("plot_bf_forest()'s y-axis (contrast) text is right-aligned, matching plot_ridge_hdi()'s axis.text.y", {
  p <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  expect_equal(p$theme$axis.text.y$hjust, 1)
  expect_equal(p$theme$axis.text.y.left$hjust, 1)
  expect_equal(p$theme$axis.text.y.right$hjust, 1)
})

test_that("plot_bf_forest() forces both axis titles to element_markdown() (base + position-suffixed)", {
  # no coord_flip() here either (contrast is mapped directly to y, log_bf
  # to x) - same reasoning as plot_location_scale()'s matching test.
  p <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  th <- p$theme
  expect_true(inherits(th$axis.title.x, "element_markdown"))
  expect_true(inherits(th$axis.title.x.top, "element_markdown"))
  expect_true(inherits(th$axis.title.y, "element_markdown"))
  expect_true(inherits(th$axis.title.y.right, "element_markdown"))
})

test_that("plot_bf_forest() maps shape to sign (redundant with color), default solid circle/triangle, legend hidden for both", {
  p <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  expect_true("shape" %in% names(rlang::get_expr(p$mapping)))

  b <- ggplot_build(p)
  point_idx <- which(sapply(p$layers, function(l) inherits(l$geom, "GeomPoint")))
  point_layer <- b$data[[point_idx]]
  pos_shapes <- unique(point_layer$shape[bf_forest_fixture$log_bf >= 0])
  neg_shapes <- unique(point_layer$shape[bf_forest_fixture$log_bf < 0])
  expect_equal(pos_shapes, 16)
  expect_equal(neg_shapes, 17)

  # legend suppressed for both redundant-encoding aesthetics
  expect_equal(p$guides$guides$colour, "none")
  expect_equal(p$guides$guides$shape, "none")
})

test_that("`positive_shape`/`negative_shape` override the default point shapes", {
  p <- plot_bf_forest(
    bf_forest_fixture,
    contrast = contrast,
    log_bf = log_bf,
    positive_shape = 15,
    negative_shape = 18
  )
  b <- ggplot_build(p)
  point_idx <- which(sapply(p$layers, function(l) inherits(l$geom, "GeomPoint")))
  point_layer <- b$data[[point_idx]]
  expect_equal(unique(point_layer$shape[bf_forest_fixture$log_bf >= 0]), 15)
  expect_equal(unique(point_layer$shape[bf_forest_fixture$log_bf < 0]), 18)
})

test_that("`weak_threshold` changes the rect bounds", {
  layers <- layer_bf_evidence_scale(orientation = "x", weak_threshold = 2)
  expect_equal(layers[[1]]$data$xmin, -2)
  expect_equal(layers[[1]]$data$xmax, 2)
})

test_that("`weak_label = NULL` omits the richtext layer, a string includes it", {
  with_label <- layer_bf_evidence_scale(orientation = "x", weak_label = "Weak")
  without_label <- layer_bf_evidence_scale(orientation = "x", weak_label = NULL)
  expect_length(with_label, 2)
  expect_true(inherits(with_label[[2]]$geom, "GeomRichText"))
  expect_length(without_label, 1)
})

test_that("`direction_labels = NULL` (default) omits arrows/labels entirely", {
  layers <- layer_bf_evidence_scale(orientation = "x")
  geom_classes <- sapply(layers, function(l) class(l$geom)[1])
  expect_false(any(geom_classes == "GeomArrow"))
  expect_false(any(geom_classes == "GeomText"))
})

test_that("`direction_labels` without an explicit `range` falls back to a generic extent", {
  layers <- layer_bf_evidence_scale(
    orientation = "x",
    direction_labels = c("A", "B"),
    weak_threshold = log(3)
  )
  arrow_layers <- Filter(function(l) inherits(l$geom, "GeomArrow"), layers)
  expect_length(arrow_layers, 2)
  expect_equal(arrow_layers[[1]]$data$x, c(0, log(3) * 3))
})

test_that("`direction_labels` adds 2 arrow layers + 2 text layers, Inf-anchored to the panel edge", {
  layers <- layer_bf_evidence_scale(
    orientation = "x",
    direction_labels = c("A", "B"),
    range = c(-5, 5)
  )
  geom_classes <- sapply(layers, function(l) class(l$geom)[1])
  expect_equal(sum(geom_classes == "GeomArrow"), 2)
  expect_equal(sum(geom_classes == "GeomText"), 2)

  arrow_layers <- Filter(function(l) inherits(l$geom, "GeomArrow"), layers)
  expect_true(all(sapply(arrow_layers, function(l) all(is.infinite(l$data$y)))))

  text_layers <- Filter(function(l) inherits(l$geom, "GeomText"), layers)
  expect_true(all(sapply(text_layers, function(l) is.infinite(l$data$y))))
})

test_that("orientation = 'y' direction labels are offset clear of their arrow (not stacked directly on top of it)", {
  # regression test: the labels used to be positioned with vjust = 1 (pos)
  # / vjust = 0 (neg), which put both directly on top of the (same-colored)
  # arrow - unreadable - and the vjust = 0 one got clipped by the panel
  # margin besides. vjust = 2.6 for both (mirroring orientation = "x"'s own
  # vjust = 2.6, which pushes its labels clear of the horizontal arrow) is
  # what actually clears the line; hjust = 1 (pos) / 0 (neg) then anchors
  # each label's near edge at its arrow tip and lets it read back inward
  # toward zero, instead of overshooting past the tip into unclipped space
  # that isn't backed by any axis expansion.
  layers <- layer_bf_evidence_scale(
    orientation = "y",
    direction_labels = c("A", "B"),
    range = c(-5, 5)
  )
  text_layers <- Filter(function(l) inherits(l$geom, "GeomText"), layers)
  expect_length(text_layers, 2)

  pos_text <- Filter(function(l) l$aes_params$label == "A", text_layers)[[1]]
  neg_text <- Filter(function(l) l$aes_params$label == "B", text_layers)[[1]]

  expect_equal(pos_text$aes_params$vjust, 2.6)
  expect_equal(neg_text$aes_params$vjust, 2.6)
  expect_equal(pos_text$aes_params$hjust, 1)
  expect_equal(neg_text$aes_params$hjust, 0)
  expect_equal(pos_text$aes_params$angle, 90)
  expect_equal(neg_text$aes_params$angle, 90)
})

test_that("`secondary_axis` adds a scale with the right breaks, only when TRUE", {
  without_sec <- layer_bf_evidence_scale(orientation = "x", secondary_axis = FALSE)
  with_sec <- layer_bf_evidence_scale(
    orientation = "x",
    secondary_axis = TRUE,
    secondary_breaks = c(1, 5, 50)
  )
  expect_true(!any(sapply(without_sec, function(l) inherits(l, "ScaleContinuousPosition"))))
  sec_scale <- Filter(function(l) inherits(l, "ScaleContinuousPosition"), with_sec)
  expect_length(sec_scale, 1)
  expect_equal(sec_scale[[1]]$secondary.axis$breaks, log(c(1, 5, 50)))
})

test_that("layer_bf_evidence_scale() renders without error against both discrete and continuous perpendicular axes", {
  d_discrete <- data.frame(cat = c("a", "b", "c"), val = c(1, -2, 3))
  p_discrete <- ggplot(d_discrete, aes(y = cat, x = val)) +
    geom_blank() +
    layer_bf_evidence_scale(
      orientation = "x",
      direction_labels = c("A", "B"),
      range = c(-5, 5)
    ) +
    geom_point()
  expect_no_error(ggplot_build(p_discrete))

  d_continuous <- data.frame(x = seq(0.1, 1.5, by = .2), val = rnorm(8))
  p_continuous <- ggplot(d_continuous, aes(x = x, y = val)) +
    layer_bf_evidence_scale(
      orientation = "y",
      direction_labels = c("A", "B"),
      range = c(-5, 5)
    ) +
    geom_point()
  expect_no_error(ggplot_build(p_continuous))
})

test_that("plot_bf_forest() builds without error and colors points by sign", {
  p <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  expect_true(inherits(p, "ggplot"))
  expect_no_error(ggplot_build(p))

  b <- ggplot_build(p)
  point_layer <- b$data[[length(b$data)]] # geom_point is always last
  # 2 positive, 2 negative (see fixture) -> exactly 2 distinct colors used
  expect_length(unique(point_layer$colour), 2)
})

test_that("errorbar layer is present only when `se` is given", {
  p_no_se <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  p_se <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf, se = se)
  expect_false(any(sapply(p_no_se$layers, function(l) inherits(l$geom, "GeomErrorbar"))))
  expect_true(any(sapply(p_se$layers, function(l) inherits(l$geom, "GeomErrorbar"))))
})

test_that("`contrast_reorder` sorts rows by log_bf; FALSE keeps original order", {
  p_sorted <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  p_unsorted <- plot_bf_forest(
    bf_forest_fixture,
    contrast = contrast,
    log_bf = log_bf,
    contrast_reorder = FALSE
  )
  labels_sorted <- ggplot_build(p_sorted)$layout$panel_scales_y[[1]]$get_labels()
  labels_unsorted <- ggplot_build(p_unsorted)$layout$panel_scales_y[[1]]$get_labels()
  expect_equal(labels_sorted, bf_forest_fixture$contrast[order(bf_forest_fixture$log_bf)])
  # FALSE doesn't reorder, but a plain character `contrast` column still
  # goes through ggplot2's own as.factor() when not pre-built as a factor,
  # which sorts alphabetically rather than preserving row order - the same
  # behavior plot_ridge_hdi()'s category_reorder = FALSE has.
  expect_equal(labels_unsorted, sort(bf_forest_fixture$contrast))
})

test_that("`evidence_scale = FALSE` omits the weak-evidence rect", {
  p_with <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  p_without <- plot_bf_forest(
    bf_forest_fixture,
    contrast = contrast,
    log_bf = log_bf,
    evidence_scale = FALSE
  )
  expect_true(any(sapply(p_with$layers, function(l) inherits(l$geom, "GeomRect"))))
  expect_false(any(sapply(p_without$layers, function(l) inherits(l$geom, "GeomRect"))))
})

test_that("`direction_labels` on plot_bf_forest() builds without error and widens the y-scale expansion", {
  p <- plot_bf_forest(
    bf_forest_fixture,
    contrast = contrast,
    log_bf = log_bf,
    se = se,
    direction_labels = c("supports a real difference", "supports practical equivalence")
  )
  expect_no_error(ggplot_build(p))
  expect_true(any(sapply(p$layers, function(l) inherits(l$geom, "GeomArrow"))))
})

test_that("`secondary_axis` passes through to plot_bf_forest()'s output", {
  p <- plot_bf_forest(
    bf_forest_fixture,
    contrast = contrast,
    log_bf = log_bf,
    secondary_axis = TRUE,
    secondary_breaks = c(1, 5, 50)
  )
  b <- ggplot_build(p)
  expect_no_error(b)
  sec_scale <- Filter(
    function(l) inherits(l, "ScaleContinuousPosition"),
    p$scales$scales
  )
  expect_true(length(sec_scale) >= 1)
})

test_that("xlab mentions SE only when `se` is given, and doesn't state the weak-evidence threshold", {
  p_no_se <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  p_se <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf, se = se)
  expect_false(grepl("SE", p_no_se$labels$x))
  expect_true(grepl("SE", p_se$labels$x))
  expect_false(grepl("1.10|1\\.1|threshold", p_no_se$labels$x))
  expect_false(grepl("1.10|1\\.1|threshold", p_se$labels$x))
})

test_that("prepare_bf_contrasts() splits on ' - ' and strips a trailing ' NA'", {
  res <- prepare_bf_contrasts(bf_raw_contrasts_fixture)
  expect_equal(res$.left[1], "true with")
  expect_equal(res$.right[1], "true without")
  expect_false(any(grepl("NA", res$.left)))
  expect_false(any(grepl("NA", res$.right)))
  expect_equal(res$.contrast_label[1], "true with vs. true without")
})

test_that("prepare_bf_contrasts() errors clearly on a `contrast` that doesn't split into 2 pieces", {
  bad <- data.frame(contrast = "no separator here", log_BF = 1)
  expect_error(prepare_bf_contrasts(bad), "doesn't split into exactly 2 pieces")
})

test_that("prepare_bf_contrasts()'s `pairs` filters to just the requested rows, in the requested order", {
  res <- prepare_bf_contrasts(bf_raw_contrasts_fixture, pairs = bf_pairs_fixture)
  expect_equal(nrow(res), length(bf_pairs_fixture))
  expect_equal(
    res$.contrast_label,
    c(
      "undef with vs. undef without",
      "critical with vs. critical without",
      "false with vs. critical with"
    )
  )
  # the un-requested 7th row ("true with - false with") must be excluded
  expect_false("true with vs. false with" %in% res$.contrast_label)
})

test_that("prepare_bf_contrasts()'s `pairs` errors clearly (naming the pair) when a pair isn't found", {
  expect_error(
    prepare_bf_contrasts(
      bf_raw_contrasts_fixture,
      pairs = list(c("nonexistent", "pair"))
    ),
    "nonexistent.*pair|not found"
  )
})

test_that("plot_bf_forest()'s `pairs` argument builds the same filtered, labeled plot end to end", {
  p <- plot_bf_forest(
    bf_raw_contrasts_fixture,
    contrast = contrast,
    log_bf = log_BF,
    pairs = bf_pairs_fixture
  )
  expect_no_error(b <- ggplot_build(p))
  labels <- b$layout$panel_scales_y[[1]]$get_labels()
  expect_length(labels, length(bf_pairs_fixture))
  expect_true(all(c(
    "undef with vs. undef without",
    "critical with vs. critical without",
    "false with vs. critical with"
  ) %in% labels))
})

test_that("plot_bf_forest() with `pairs = NULL` (default) leaves an already-clean `contrast` column untouched", {
  # regression test for backward compatibility: this is the pre-`pairs`
  # behavior and must keep working unchanged
  p <- plot_bf_forest(bf_forest_fixture, contrast = contrast, log_bf = log_bf)
  b <- ggplot_build(p)
  labels <- b$layout$panel_scales_y[[1]]$get_labels()
  expect_true(all(bf_forest_fixture$contrast %in% labels))
})

test_that("prepare_bf_contrasts()'s `pairs` matches a pair given in the opposite order from `data`, and flips `value` on that row", {
  # bf_raw_contrasts_fixture's first row is "true with - true without NA" -
  # requesting c("true without", "true with") (the opposite order) must
  # still match, relabel to the requested order, and negate log_BF since a
  # `value` column is given.
  res <- prepare_bf_contrasts(
    bf_raw_contrasts_fixture,
    value = log_BF,
    pairs = list(c("true without", "true with"))
  )
  expect_equal(res$.left, "true without")
  expect_equal(res$.right, "true with")
  expect_equal(res$.contrast_label, "true without vs. true with")
  expect_equal(res$log_BF, -8.2)
})

test_that("prepare_bf_contrasts()'s `pairs` leaves `value` untouched (and warns) on a reversed match when `value` isn't given", {
  expect_warning(
    res <- prepare_bf_contrasts(
      bf_raw_contrasts_fixture,
      pairs = list(c("true without", "true with"))
    ),
    "reversed order"
  )
  expect_equal(res$.contrast_label, "true without vs. true with")
  expect_equal(res$log_BF, 8.2) # NOT flipped - no `value` column was named
})

test_that("prepare_bf_contrasts()'s `pairs` handles direct- and reversed-order pairs together in one call", {
  res <- prepare_bf_contrasts(
    bf_raw_contrasts_fixture,
    value = log_BF,
    pairs = list(
      c("true with", "true without"), # direct order in `data`
      c("false with", "true with") # reversed relative to "true with - false with NA"
    )
  )
  expect_equal(res$log_BF, c(8.2, -0.9))
  expect_equal(
    res$.contrast_label,
    c("true with vs. true without", "false with vs. true with")
  )
})

test_that("prepare_bf_contrasts()'s `pairs` prefers the direct-order row when `data` contains both orderings for one pair", {
  # a reference grid can (rarely) contain both "A - B" and "B - A" as
  # separate rows for the same pair of conditions; confirmed desired
  # behavior is to silently prefer whichever row matches the requested
  # pair directly, ignoring the reversed one, rather than erroring on the
  # ambiguity or warning about it.
  both_orders <- data.frame(
    contrast = c("true with - true without NA", "true without - true with NA"),
    log_BF = c(8.2, -8.2)
  )
  res <- prepare_bf_contrasts(
    both_orders,
    value = log_BF,
    pairs = list(c("true with", "true without"))
  )
  expect_equal(nrow(res), 1)
  expect_equal(res$log_BF, 8.2) # the direct-order row, untouched (not flipped)
  expect_equal(res$.contrast_label, "true with vs. true without")
})

test_that("plot_bf_forest()'s `pairs` sign-flips a reversed-order pair automatically end to end", {
  p_direct <- plot_bf_forest(
    bf_raw_contrasts_fixture,
    contrast = contrast,
    log_bf = log_BF,
    pairs = list(c("true with", "true without")),
    contrast_reorder = FALSE
  )
  p_reversed <- plot_bf_forest(
    bf_raw_contrasts_fixture,
    contrast = contrast,
    log_bf = log_BF,
    pairs = list(c("true without", "true with")),
    contrast_reorder = FALSE
  )
  x_direct <- ggplot_build(p_direct)$data[[length(p_direct$layers)]]$x
  x_reversed <- ggplot_build(p_reversed)$data[[length(p_reversed$layers)]]$x
  expect_equal(x_direct, 8.2)
  expect_equal(x_reversed, -8.2)
})

test_that("plot_bf_forest() works with no `se` column present at all in `data` (not just se = NULL on a table that has one)", {
  # bf_raw_contrasts_fixture has no `se`/`log_bf_se` column whatsoever,
  # matching bayesfactor_rope()'s actual output shape (no per-contrast SE,
  # unlike a repeated bridge-sampling estimate)
  expect_false("se" %in% names(bf_raw_contrasts_fixture))
  p <- plot_bf_forest(
    bf_raw_contrasts_fixture,
    contrast = contrast,
    log_bf = log_BF,
    pairs = bf_pairs_fixture,
    direction_labels = c("supports a real difference", "supports practical equivalence")
  )
  expect_no_error(ggplot_build(p))
  expect_false(any(sapply(p$layers, function(l) inherits(l$geom, "GeomErrorbar"))))
})

test_that("plot_bf_forest() requires `contrast`/`log_bf`, with a clear error", {
  expect_error(plot_bf_forest(data.frame(x = 1)), "`contrast` is required")
  expect_error(plot_bf_forest(data.frame(x = 1), contrast = x), "`log_bf` is required")
})

test_that("plot_bf_forest() gives a clear error for all-NA `log_bf`, not forcats' own cryptic one", {
  # Regression test: forcats::fct_reorder() used to fail deep inside
  # ggplot2's own aesthetic evaluation with a cryptic, emptyviz-unattributed
  # error if `log_bf` was entirely NA. The message that fires now is the
  # unconditional "no finite values" one rather than the reorder guard's,
  # deliberately: with nothing plottable in the column, telling the user to
  # pass `contrast_reorder = FALSE` would be advice that doesn't help. The
  # reorder guard still owns the partial case (see the tests below), which
  # is the common one.
  d <- data.frame(contrast = c("a - b", "c - d"), log_bf = NA_real_)
  expect_error(
    plot_bf_forest(d, contrast = contrast, log_bf = log_bf),
    "no finite values"
  )
})

test_that("plot_bf_forest() catches a single NA `log_bf` row, not only an entirely-NA column", {
  # The all-NA guard above used to be the *only* guard, but
  # forcats::fct_reorder() fails whenever any level is left with no non-NA
  # value - and here each contrast is a single row, so one NA is enough.
  # This case previously produced forcats' own "`idx` must contain one
  # integer for each level of `f`" from inside ggplot2's aesthetic
  # evaluation: verbatim the error the guard exists to replace.
  d <- data.frame(
    contrast = c("A vs B", "C vs D", "E vs F"),
    log_bf = c(2.1, NA, -0.4)
  )
  expect_error(
    plot_bf_forest(d, contrast = contrast, log_bf = log_bf),
    "'C vs D'",
    fixed = TRUE
  )
  expect_error(
    plot_bf_forest(d, contrast = contrast, log_bf = log_bf),
    "no non-NA `log_bf`",
    fixed = TRUE
  )
  # the documented escape hatch still works
  expect_no_error(
    suppressWarnings(ggplot_build(
      plot_bf_forest(d, contrast = contrast, log_bf = log_bf, contrast_reorder = FALSE)
    ))
  )
})

test_that("plot_bf_forest() names every offending contrast, and builds when none is empty", {
  d <- data.frame(
    contrast = c("A vs B", "C vs D", "E vs F"),
    log_bf = c(NA, NA, -0.4)
  )
  err <- expect_error(plot_bf_forest(d, contrast = contrast, log_bf = log_bf))
  expect_match(conditionMessage(err), "categories 'A vs B', 'C vs D'", fixed = TRUE)

  ok <- data.frame(contrast = c("A vs B", "C vs D"), log_bf = c(1.2, -0.4))
  expect_no_error(ggplot_build(plot_bf_forest(ok, contrast = contrast, log_bf = log_bf)))
})

test_that("plot_bf_forest() errors on an all-non-finite `log_bf` even with contrast_reorder = FALSE", {
  # The NA guard used to live inside the `if (contrast_reorder)` branch, so
  # contrast_reorder = FALSE - which the guard's own error message
  # recommended as the remedy - bypassed it. Execution then reached
  # max(..., na.rm = TRUE) with nothing left to compare: abs_extent became
  # -Inf, arrow_range became c(-Inf, Inf), and the plot "built successfully"
  # with meaningless arrow geometry, the only signal a base-R warning naming
  # max() rather than this package.
  d <- data.frame(contrast = c("a - b", "c - d"), log_bf = NA_real_)
  expect_error(
    plot_bf_forest(d, contrast = contrast, log_bf = log_bf, contrast_reorder = FALSE),
    "no finite values"
  )
  # ...and with the evidence scale off too, since the column is unplottable
  # either way
  expect_error(
    plot_bf_forest(
      d,
      contrast = contrast, log_bf = log_bf,
      contrast_reorder = FALSE, evidence_scale = FALSE
    ),
    "no finite values"
  )

  # a column that still has something finite in it keeps working, and the
  # reorder escape hatch with it
  partial <- data.frame(contrast = c("a - b", "c - d"), log_bf = c(2.1, NA))
  expect_no_error(suppressWarnings(ggplot_build(
    plot_bf_forest(partial, contrast = contrast, log_bf = log_bf, contrast_reorder = FALSE)
  )))
})

test_that("plot_bf_forest()'s arrow range ignores infinite log_bf values", {
  # abs_extent used na.rm = TRUE, which drops NA but keeps Inf - so a single
  # infinite Bayes Factor (an ordinary enough result) stretched the evidence
  # arrows to an infinite range.
  d <- data.frame(contrast = c("a - b", "c - d"), log_bf = c(Inf, 2))
  b <- suppressWarnings(ggplot_build(
    plot_bf_forest(d, contrast = contrast, log_bf = log_bf)
  ))
  expect_true(all(is.finite(b$layout$panel_params[[1]]$x.range)))
})

test_that("prepare_bf_contrasts() warns when two requested pairs resolve to the same source row", {
  # Requesting both directions of a contrast returns the same source row
  # twice with opposite signs, and requesting the identical pair twice
  # returns it twice unchanged - in both cases with duplicated row names.
  # Neither is an error (both directions can genuinely be wanted), but on a
  # forest plot one estimate then appears as two rows, reading as two
  # independent ones. It used to happen silently.
  bf <- data.frame(contrast = c("a - b", "c - d"), log_BF = c(2.5, -1))

  expect_warning(
    both_directions <- prepare_bf_contrasts(
      bf,
      contrast = contrast, value = log_BF,
      pairs = list(c("a", "b"), c("b", "a"))
    ),
    "resolve to the same row"
  )
  # the behaviour itself is unchanged - relabeled and sign-flipped
  expect_equal(both_directions$.left, c("a", "b"))
  expect_equal(both_directions$log_BF, c(2.5, -2.5))

  expect_warning(
    prepare_bf_contrasts(
      bf,
      contrast = contrast, value = log_BF,
      pairs = list(c("a", "b"), c("a", "b"))
    ),
    'c("a", "b") and c("a", "b")',
    fixed = TRUE
  )

  # distinct pairs stay silent
  expect_no_warning(prepare_bf_contrasts(
    bf,
    contrast = contrast, value = log_BF,
    pairs = list(c("a", "b"), c("c", "d"))
  ))
})
