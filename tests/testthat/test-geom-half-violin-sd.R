test_that("returns a list of 3 layers plus a guides() call for style = 'both' (default)", {
  layers <- geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato")
  expect_type(layers, "list")
  expect_length(layers, 4)
  expect_true(all(vapply(layers[1:3], inherits, logical(1), "LayerInstance")))
  expect_s3_class(layers[[4]], "Guides")
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

test_that("outline sub-layer dodges identically to the aura/SD-fill sub-layers", {
  # Regression test: a literal fill = NA geom param on the outline
  # sub-layer used to make ggplot2 drop fill from that layer's own group
  # computation, collapsing dodge groups and drawing one outline spanning
  # both dodge slots instead of two correctly-positioned ones.
  df <- sd_fixture
  df$sub <- rep(c("x", "y"), 45)

  b <- ggplot_build(ggplot(df, aes(grp, y, fill = sub)) + geom_half_violin_sd())

  reference <- unique(b$data[[1]][, c("x", "xmin", "xmax", "group")])
  reference <- reference[order(reference$group), ]

  for (i in 2:3) { # sd-fill, sd-outline (compared against the aura, layer 1)
    layer_data <- unique(b$data[[i]][, c("x", "xmin", "xmax", "group")])
    layer_data <- layer_data[order(layer_data$group), ]
    expect_equal(layer_data$x, reference$x, label = paste("layer", i, "x"))
    expect_equal(layer_data$xmin, reference$xmin, label = paste("layer", i, "xmin"))
    expect_equal(layer_data$xmax, reference$xmax, label = paste("layer", i, "xmax"))
  }
})

test_that("outline colour tracks each group's mapped fill when outline_color/fill aren't given literally", {
  p <- ggplot() + geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y, fill = grp))
  b <- ggplot_build(p)

  outline_colours <- unique(b$data[[3]][, c("group", "colour")])
  expect_gt(length(unique(outline_colours$colour)), 1)

  fill_colours <- unique(b$data[[1]][, c("group", "fill")])
  merged <- merge(outline_colours, fill_colours, by = "group")
  expect_equal(merged$colour, merged$fill)
})

test_that("legend key: only the aura sub-layer contributes, matching gghalves::geom_half_violin()'s single key", {
  p_sd <- ggplot(sd_fixture, aes(grp, y, fill = grp)) + geom_half_violin_sd()
  p_plain <- ggplot(sd_fixture, aes(grp, y, fill = grp)) + geom_half_violin()
  expect_equal(n_legend_boxes(p_sd), n_legend_boxes(p_plain))

  for (style in c("both", "fill", "outline")) {
    layers <- Filter(
      function(l) inherits(l, "LayerInstance"),
      geom_half_violin_sd(style = style)
    )
    contributes <- vapply(layers, function(l) isTRUE(l$show.legend) || is.na(l$show.legend), logical(1))
    expect_equal(sum(contributes), 1)
  }
})
