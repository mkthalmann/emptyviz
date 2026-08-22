test_that("a zero-variance group (sd = 0) doesn't error at build or render time", {
  df <- data.frame(grp = rep(c("a", "b"), each = 20), y = c(rnorm(20), rep(5, 20)))
  p <- ggplot(df, aes(x = grp, y = y)) + geom_violin_sd(fill = "steelblue")
  expect_no_error(ggplot_build(p))
  expect_no_error(render_plot(p))

  p2 <- ggplot(df, aes(x = grp, y = y)) + geom_half_violin_sd(fill = "tomato")
  expect_no_error(ggplot_build(p2))
  expect_no_error(render_plot(p2))
})

test_that("an explicitly empty data frame doesn't error at build or render time", {
  df <- data.frame(grp = character(0), y = numeric(0))
  p <- ggplot() + geom_violin_sd(data = df, mapping = aes(x = grp, y = y), fill = "steelblue")
  expect_no_error(ggplot_build(p))
  expect_no_error(render_plot(p))

  p2 <- ggplot() + geom_half_violin_sd(data = df, mapping = aes(x = grp, y = y), fill = "tomato")
  expect_no_error(ggplot_build(p2))
  expect_no_error(render_plot(p2))
})

test_that("a single group (no real comparison) doesn't error at build or render time", {
  df <- data.frame(grp = "a", y = rnorm(30))
  p <- ggplot(df, aes(x = grp, y = y)) + geom_violin_sd(fill = "steelblue")
  expect_no_error(ggplot_build(p))
  expect_no_error(render_plot(p))
})

test_that("dodged sub-groups (aes(fill = subgroup) with multiple violins per x) resolve to the right group count", {
  df <- expand.grid(grp = c("a", "b", "c"), sub = c("x", "y"))
  df <- df[rep(seq_len(nrow(df)), 20), ]
  set.seed(1)
  df$y <- rnorm(nrow(df))

  p <- ggplot(df, aes(x = grp, y = y, fill = sub)) + geom_violin_sd()
  b <- ggplot_build(p)
  expect_length(unique(b$data[[1]]$group), 6)
  expect_no_error(render_plot(p))
})

test_that("aes(weight = ...) reaches the density but not the SD bounds, exactly as documented", {
  # The NOTE above StatYdensitySD states this asymmetry - the density curve
  # respects `weight` (inherited from StatYdensity) while the SD truncation
  # band is computed from the raw y values and does not. That was prose
  # only; this pins both halves of it, so if a future change starts
  # weighting the bounds (or stops weighting the density), the claim in the
  # comment fails with it instead of quietly becoming wrong.
  set.seed(11)
  df <- sd_fixture
  # deliberately lopsided, so a weighted mean/sd would differ visibly from
  # the unweighted one rather than by rounding noise
  df$w <- ifelse(df$y > 0, 10, 0.1)

  p <- ggplot(df, aes(x = grp, y = y, weight = w)) + geom_violin_sd(fill = "steelblue")
  expect_no_error(b <- suppressWarnings(ggplot_build(p)))

  unweighted <- df |>
    group_by(grp) |>
    summarise(lo = mean(y) - sd(y), hi = mean(y) + sd(y), .groups = "drop")
  ordered <- unweighted[match(c("a", "b", "c"), unweighted$grp), ]

  # the SD band sits at the UNWEIGHTED bounds
  sd_fill <- b$data[[2]]
  for (g in 1:3) {
    rows <- sd_fill[sd_fill$group == g, ]
    expect_true(all(rows$y >= ordered$lo[g] - 1e-8))
    expect_true(all(rows$y <= ordered$hi[g] + 1e-8))
    # and actually reaches them, i.e. it isn't trivially inside a weighted
    # band that happens to be wider
    expect_lt(min(rows$y) - ordered$lo[g], 0.15)
    expect_lt(ordered$hi[g] - max(rows$y), 0.15)
  }

  # ...while the aura's density DOES differ from the unweighted one
  aura_weighted <- b$data[[1]]$violinwidth
  aura_unweighted <- ggplot_build(
    ggplot(df, aes(x = grp, y = y)) + geom_violin_sd(fill = "steelblue")
  )$data[[1]]$violinwidth
  expect_false(isTRUE(all.equal(aura_weighted, aura_unweighted)))
})

test_that("a vector `fill` (not mapped via aes) errors the same way plain geom_violin does, not worse", {
  plain_err <- tryCatch(
    ggplot_build(ggplot(sd_fixture, aes(x = grp, y = y)) + geom_violin(fill = c("red", "green", "blue"))),
    error = function(e) e
  )
  sd_err <- tryCatch(
    ggplot_build(ggplot(sd_fixture, aes(x = grp, y = y)) + geom_violin_sd(fill = c("red", "green", "blue"))),
    error = function(e) e
  )
  expect_s3_class(plain_err, "error")
  expect_s3_class(sd_err, "error")
})
