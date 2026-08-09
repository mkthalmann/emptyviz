test_that("geom_violin_sd truncates correctly for horizontal orientation (aes(x = value, y = group))", {
  # Regression test: ggplot2::StatYdensity$compute_panel() itself flips
  # data internally so "y" is always the continuous axis, then flips the
  # *output* back before returning - but the raw `data` argument our stat
  # override receives is still in the user's original (unflipped)
  # orientation. Computing SD bounds directly off data$y without accounting
  # for flipped_aes silently computes bounds on the wrong column (the
  # discrete group codes) whenever the plot is horizontal.
  bounds <- sd_fixture |>
    group_by(grp) |>
    summarise(lo = mean(y) - sd(y), hi = mean(y) + sd(y), .groups = "drop") |>
    arrange(grp) # a, b, c -> matches sorted-factor-level group ids 1, 2, 3

  p <- ggplot(sd_fixture, aes(x = y, y = grp)) + geom_violin_sd(fill = "steelblue")
  b <- ggplot_build(p)
  sd_fill <- b$data[[2]]

  for (g in 1:3) {
    rows <- sd_fill[sd_fill$group == g, ]
    expect_true(nrow(rows) > 0)
    # the continuous values live in `x` here, not `y`, since x/y are swapped
    expect_true(all(rows$x >= bounds$lo[g] - 1e-8))
    expect_true(all(rows$x <= bounds$hi[g] + 1e-8))
  }
})

test_that("horizontal and vertical orientations agree on which points survive truncation", {
  p_vert <- ggplot(sd_fixture, aes(x = grp, y = y)) + geom_violin_sd(fill = "steelblue")
  p_horiz <- ggplot(sd_fixture, aes(x = y, y = grp)) + geom_violin_sd(fill = "steelblue")

  n_vert <- table(ggplot_build(p_vert)$data[[2]]$group)
  n_horiz <- table(ggplot_build(p_horiz)$data[[2]]$group)

  expect_equal(as.vector(n_vert), as.vector(n_horiz))
})

test_that("coord_flip() still builds and renders without error", {
  p <- ggplot(sd_fixture, aes(x = grp, y = y)) + geom_violin_sd(fill = "steelblue") + coord_flip()
  expect_no_error(ggplot_build(p))
  expect_no_error(render_plot(p))
})

test_that("SD bounds are computed per-facet-panel, not bled across panels", {
  df <- bind_rows(
    data.frame(panel = "p1", grp = "a", y = rnorm(40, mean = 0, sd = 1)),
    data.frame(panel = "p2", grp = "a", y = rnorm(40, mean = 100, sd = 5))
  )
  expected <- df |>
    group_by(panel, grp) |>
    summarise(lo = mean(y) - sd(y), hi = mean(y) + sd(y), .groups = "drop")

  p <- ggplot(df, aes(x = grp, y = y)) +
    geom_violin_sd(fill = "steelblue") +
    facet_wrap(~panel, scales = "free_y")
  b <- ggplot_build(p)
  sd_fill <- b$data[[2]]

  for (panel_id in unique(sd_fill$PANEL)) {
    exp_row <- expected[panel_id, ]
    rows <- sd_fill[sd_fill$PANEL == panel_id, ]
    expect_true(all(rows$y >= exp_row$lo - 1e-8))
    expect_true(all(rows$y <= exp_row$hi + 1e-8))
  }
})
