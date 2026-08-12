test_that("returns a list of 3 layers plus a guides() call for style = 'both' (default)", {
  layers <- geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue")
  expect_type(layers, "list")
  expect_length(layers, 4)
  expect_true(all(vapply(layers[1:3], inherits, logical(1), "LayerInstance")))
  expect_s3_class(layers[[4]], "Guides")
})

test_that("style = 'fill' / 'outline' return 2 layers plus a guides() call, and an invalid style errors", {
  expect_length(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue", style = "fill"),
    3
  )
  expect_length(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue", style = "outline"),
    3
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

test_that("outline sub-layer dodges identically to the aura/SD-fill sub-layers and to plain geom_violin()", {
  # Regression test: a literal fill = NA geom param on the outline
  # sub-layer used to make ggplot2 drop fill from that layer's own group
  # computation, collapsing dodge groups and drawing one outline spanning
  # both dodge slots instead of two correctly-positioned ones.
  df <- sd_fixture
  df$sub <- rep(c("x", "y"), 45)

  b_sd <- ggplot_build(ggplot(df, aes(grp, y, fill = sub)) + geom_violin_sd())
  b_plain <- ggplot_build(ggplot(df, aes(grp, y, fill = sub)) + geom_violin())

  reference <- unique(b_plain$data[[1]][, c("x", "xmin", "xmax", "group")])
  reference <- reference[order(reference$group), ]

  for (i in 1:3) { # aura, sd-fill, sd-outline
    layer_data <- unique(b_sd$data[[i]][, c("x", "xmin", "xmax", "group")])
    layer_data <- layer_data[order(layer_data$group), ]
    expect_equal(layer_data$x, reference$x, label = paste("layer", i, "x"))
    expect_equal(layer_data$xmin, reference$xmin, label = paste("layer", i, "xmin"))
    expect_equal(layer_data$xmax, reference$xmax, label = paste("layer", i, "xmax"))
  }
})

test_that("outline colour tracks each group's mapped fill when outline_color/fill aren't given literally", {
  p <- ggplot() + geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y, fill = grp))
  b <- ggplot_build(p)

  outline_colours <- unique(b$data[[3]][, c("group", "colour")])
  expect_gt(length(unique(outline_colours$colour)), 1)

  fill_colours <- unique(b$data[[1]][, c("group", "fill")])
  merged <- merge(outline_colours, fill_colours, by = "group")
  expect_equal(merged$colour, merged$fill)
})

test_that("legend key: only the aura sub-layer contributes, matching plain geom_violin()'s single key", {
  p_sd <- ggplot(sd_fixture, aes(grp, y, fill = grp)) + geom_violin_sd()
  p_plain <- ggplot(sd_fixture, aes(grp, y, fill = grp)) + geom_violin()
  expect_equal(n_legend_boxes(p_sd), n_legend_boxes(p_plain))

  for (style in c("both", "fill", "outline")) {
    layers <- Filter(
      function(l) inherits(l, "LayerInstance"),
      geom_violin_sd(style = style)
    )
    contributes <- vapply(layers, function(l) isTRUE(l$show.legend) || is.na(l$show.legend), logical(1))
    expect_equal(sum(contributes), 1)
  }
})
