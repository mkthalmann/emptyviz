test_that("returns a list of 3 layers for style = 'both' (default)", {
  layers <- geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue")
  expect_type(layers, "list")
  expect_length(layers, 3)
  expect_true(all(vapply(layers, inherits, logical(1), "LayerInstance")))
})

test_that("style = 'fill' / 'outline' return 2 layers, and an invalid style errors", {
  expect_length(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue", style = "fill"),
    2
  )
  expect_length(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue", style = "outline"),
    2
  )
  expect_error(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), style = "nonsense")
  )
})

test_that("fill is optional: omitting it doesn't set a fixed fill aes_param", {
  layers <- geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y))
  expect_null(layers[[1]]$aes_params$fill)
})

test_that("base_alpha / sd_alpha / sd_linewidth take effect on the right layer", {
  layers <- geom_violin_sd(
    data = sd_fixture,
    mapping = aes(x = grp, y = y),
    fill = "steelblue",
    base_alpha = 0.11,
    sd_alpha = 0.22,
    sd_linewidth = 0.44
  )
  expect_equal(layers[[1]]$aes_params$alpha, 0.11)
  expect_equal(layers[[2]]$aes_params$alpha, 0.22)
  expect_equal(layers[[3]]$aes_params$linewidth, 0.44)
})

test_that("outline_color defaults to fill when not given, and can be overridden", {
  layers <- geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue")
  expect_equal(layers[[3]]$aes_params$colour, "steelblue")

  layers2 <- geom_violin_sd(
    data = sd_fixture, mapping = aes(x = grp, y = y),
    fill = "steelblue", outline_color = "black"
  )
  expect_equal(layers2[[3]]$aes_params$colour, "black")
})

test_that("builds without error and facets correctly", {
  df <- sd_fixture
  df$panel <- rep(c("p1", "p2"), 45)
  p <- ggplot() +
    geom_violin_sd(data = df, mapping = aes(x = grp, y = y), fill = "steelblue") +
    facet_wrap(~panel)
  expect_no_error(ggplot_build(p))
})

test_that("mapped (discrete) fill aesthetic builds without error", {
  p <- ggplot() +
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y, fill = grp))
  expect_no_error(ggplot_build(p))
})
