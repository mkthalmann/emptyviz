test_that("StatYdensitySD truncates the density curve to mean +/- sd of raw y", {
  p <- ggplot() +
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue")
  b <- ggplot_build(p)

  bounds <- sd_fixture |>
    group_by(grp) |>
    summarise(lo = mean(y) - sd(y), hi = mean(y) + sd(y), .groups = "drop")

  sd_fill <- b$data[[2]] # fill_layer uses StatYdensitySD
  # group 1/2/3 correspond to sorted factor levels a/b/c
  ordered_bounds <- bounds[match(c("a", "b", "c"), bounds$grp), ]
  for (g in 1:3) {
    grp_rows <- sd_fill[sd_fill$group == g, ]
    expect_true(nrow(grp_rows) > 0)
    expect_true(all(grp_rows$y >= ordered_bounds$lo[g] - 1e-8))
    expect_true(all(grp_rows$y <= ordered_bounds$hi[g] + 1e-8))
  }
})

test_that("StatHalfYdensitySD truncates the density curve to mean +/- sd of raw y", {
  p <- ggplot() +
    geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato")
  b <- ggplot_build(p)

  bounds <- sd_fixture |>
    group_by(grp) |>
    summarise(lo = mean(y) - sd(y), hi = mean(y) + sd(y), .groups = "drop")
  ordered_bounds <- bounds[match(c("a", "b", "c"), bounds$grp), ]

  sd_fill <- b$data[[2]]
  for (g in 1:3) {
    grp_rows <- sd_fill[sd_fill$group == g, ]
    expect_true(nrow(grp_rows) > 0)
    expect_true(all(grp_rows$y >= ordered_bounds$lo[g] - 1e-8))
    expect_true(all(grp_rows$y <= ordered_bounds$hi[g] + 1e-8))
  }
})

test_that("groups with fewer than 2 observations are dropped from every layer, same as plain geom_violin", {
  # A density needs >= 2 points, so stat_ydensity itself (not just our SD
  # truncation) already drops singleton groups from the base "aura" layer -
  # this just pins down that geom_violin_sd doesn't do anything to change
  # that inherited behavior.
  df <- rbind(sd_fixture, data.frame(grp = "d", y = 5))
  p <- ggplot() +
    geom_violin_sd(data = df, mapping = aes(x = grp, y = y), fill = "steelblue")
  b <- suppressWarnings(ggplot_build(p))

  base_layer <- b$data[[1]]
  sd_fill <- b$data[[2]]

  expect_false(4 %in% unique(base_layer$group))
  expect_false(4 %in% unique(sd_fill$group))
})

test_that("the SD-truncated curve keeps the same width scaling as the full density (truncation, not recomputation)", {
  # Because StatYdensitySD runs the parent stat on the *full* group and only
  # filters the resulting points afterwards, the max violinwidth for a group
  # should match between the untruncated and SD-truncated layers - if a
  # future change recomputed density on the SD-restricted subset instead,
  # this would drift because scale="area" normalizes on whatever data it's
  # given.
  p <- ggplot() +
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue")
  b <- ggplot_build(p)

  base_layer <- b$data[[1]]
  sd_fill <- b$data[[2]]

  for (g in 1:3) {
    full_max <- max(base_layer$violinwidth[base_layer$group == g])
    sd_max <- max(sd_fill$violinwidth[sd_fill$group == g])
    expect_equal(sd_max, full_max, tolerance = 1e-6)
  }
})

test_that("StatYdensitySD absorbs ggplot2's `bounds` stat param without erroring", {
  # ggplot2 >= 3.5's StatYdensity$compute_panel() gained a `bounds` argument;
  # StatYdensitySD's signature explicitly absorbs it. This pins down that
  # calling with an explicit bounds= (as any ggplot2 user might) still works.
  p <- ggplot() +
    geom_violin_sd(
      data = sd_fixture,
      mapping = aes(x = grp, y = y),
      fill = "steelblue",
      bounds = c(-10, 10)
    )
  expect_no_error(ggplot_build(p))
})

test_that("`drop = FALSE` keeps a thin group in the aura layer without crashing the SD layers", {
  # Regression test for the "guaranteed consistent" invariant
  # .truncate_to_sd_bounds() used to assert. It holds only under the default
  # drop = TRUE: with drop = FALSE, ggplot2's StatYdensity deliberately keeps
  # groups with fewer than 2 points, while .sd_bounds() still filters them
  # out, so the group survived into `result` with no matching `bounds` row.
  # match() returned NA, and NA-index subsetting produced a block of all-NA
  # rows that surfaced much later as ggplot2's own `scale_id` must not
  # contain any "NA"` from scale_apply() - naming nothing this package owns.
  #
  # drop = FALSE is ggplot2's own documented remedy for thin groups and is
  # suggested by name in the warning users see, so a user following that
  # advice hit this. Plain geom_violin(drop = FALSE) builds fine on the same
  # data, which is asserted below so this stays a parity test rather than a
  # bare "doesn't error".
  df <- rbind(sd_fixture, data.frame(grp = "d", y = 5))
  mapping <- aes(x = grp, y = y)

  expect_no_error(
    b <- suppressWarnings(ggplot_build(
      ggplot() + geom_violin_sd(data = df, mapping = mapping, drop = FALSE)
    ))
  )
  expect_no_error(
    suppressWarnings(ggplot_build(
      ggplot(df, mapping) + geom_violin(drop = FALSE)
    ))
  )

  # no NA rows leak into any sub-layer's positional columns
  for (layer_data in b$data) {
    expect_false(anyNA(layer_data$x))
    expect_false(anyNA(layer_data$y))
    expect_false(anyNA(layer_data$group))
  }

  # the thin group (4, sorted level "d") has no SD band, but the aura layer
  # keeps its slot - matching plain geom_violin(drop = FALSE), which is the
  # whole point of the argument
  expect_true(4 %in% unique(b$data[[1]]$group))
  expect_false(4 %in% unique(b$data[[2]]$group))
  expect_false(4 %in% unique(b$data[[3]]$group))
})
