test_that("returns a list of 3 layers for style = 'both' (default)", {
  layers <- geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato")
  expect_type(layers, "list")
  expect_length(layers, 3)
  expect_true(all(vapply(layers, inherits, logical(1), "LayerInstance")))
})

test_that("outline_color defaults to fill, matching geom_violin_sd's behavior", {
  layers <- geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato")
  expect_equal(layers[[3]]$aes_params$colour, "tomato")

  layers2 <- geom_half_violin_sd(
    data = sd_fixture, mapping = aes(x = grp, y = y),
    fill = "tomato", outline_color = "black"
  )
  expect_equal(layers2[[3]]$aes_params$colour, "black")
})

test_that("builds without error and facets correctly", {
  df <- sd_fixture
  df$panel <- rep(c("p1", "p2"), 45)
  p <- ggplot() +
    geom_half_violin_sd(data = df, mapping = aes(x = grp, y = y), fill = "tomato") +
    facet_wrap(~panel)
  expect_no_error(ggplot_build(p))
})

test_that("non-symbol x mappings (e.g. interaction()) no longer error", {
  df <- sd_fixture
  df$sub <- rep(c("x", "y"), 45)
  p <- ggplot() +
    geom_half_violin_sd(data = df, mapping = aes(x = interaction(grp, sub), y = y), fill = "tomato")
  expect_no_error(ggplot_build(p))
})

test_that("a scalar side is applied to every group regardless of data row order", {
  applied <- capture_applied_sides(
    ggplot() + geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato", side = "r")
  )
  expect_true(all(applied$side == "r"))
  expect_setequal(applied$group, 1:3)
})

test_that("a vector side is applied per sorted-factor-level group, not per data first-appearance order", {
  # regression test for the bug where side was pre-recycled against
  # unique(data[[x]]) in first-appearance order ("c","a","b" here) while
  # gghalves itself indexes side by the internal group id, which follows
  # sorted factor level order (a=1, b=2, c=3). Requesting side = c("l","r","l")
  # must land as a->l, b->r, c->l, not c->l, a->r, b->l.
  expect_equal(unique(sd_fixture$grp[!duplicated(sd_fixture$grp)]), c("c", "a", "b"))

  applied <- capture_applied_sides(
    ggplot() + geom_half_violin_sd(
      data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato",
      side = c("l", "r", "l")
    )
  )
  applied <- applied[!duplicated(applied$group), ]
  applied <- applied[order(applied$group), ]

  expect_equal(applied$side, c("l", "r", "l")) # group 1=a, 2=b, 3=c
})

test_that("the 3 sub-layers agree on side for a given group", {
  applied <- capture_applied_sides(
    ggplot() + geom_half_violin_sd(
      data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato",
      side = c("l", "r", "l")
    )
  )
  by_group <- split(applied$side, applied$group)
  expect_true(all(vapply(by_group, function(s) length(unique(s)) == 1, logical(1))))
})
