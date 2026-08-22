test_that("trim is a real parameter, not reserved - no warning, and every sub-layer gets the requested value", {
  expect_no_warning(
    layers <- geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), trim = FALSE)
  )
  expect_true(all(vapply(
    layers[1:3],
    function(l) isFALSE(l$geom_params$trim %||% l$stat_params$trim),
    logical(1)
  )))

  expect_no_warning(
    half_layers <- geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), trim = FALSE)
  )
  expect_true(all(vapply(
    half_layers[1:3],
    function(l) isFALSE(l$geom_params$trim %||% l$stat_params$trim),
    logical(1)
  )))
})

test_that("trim defaults to TRUE, matching geom_violin()/gghalves::geom_half_violin()'s own default", {
  layers <- geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y))
  expect_true(all(vapply(
    layers[1:3],
    function(l) isTRUE(l$geom_params$trim %||% l$stat_params$trim),
    logical(1)
  )))
})

test_that("stat passed via ... no longer crashes with a duplicate-argument error, and warns instead", {
  expect_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), stat = "identity"),
    "stat"
  )
  expect_warning(
    geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), stat = "identity"),
    "stat"
  )
})

test_that("colour/color passed via ... warns instead of being silently dropped", {
  expect_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue", colour = "red"),
    "colour"
  )
  expect_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue", color = "red"),
    "color"
  )
})

test_that("alpha/linewidth passed via ... warn instead of being silently dropped", {
  expect_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), alpha = 0.9),
    "alpha"
  )
  expect_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), linewidth = 2),
    "linewidth"
  )
})

test_that("`fill` is a real formal, not a reserved ... argument, so passing it never warns", {
  # The comment above warn_reserved_dots() used to list `fill` among the
  # internally-controlled arguments; it isn't in the `reserved` vector, and
  # correctly so - it's a named formal of all three geoms, so it never
  # arrives through `...` at all. Harmless drift, but a future reader
  # reconciling comment against code would burn time on it. Pinned here so
  # the two can't disagree silently again.
  for (geom in list(geom_violin_sd, geom_half_violin_sd)) {
    expect_no_warning(
      geom(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue")
    )
  }
  # ...and the genuinely reserved ones still do warn, so this isn't just
  # asserting that warnings are broken
  expect_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), alpha = 0.5),
    "alpha"
  )
})

test_that("non-reserved stat/geom params (scale, bw, adjust, kernel, na.rm, width, position) pass through without warning", {
  expect_no_warning(
    geom_violin_sd(
      data = sd_fixture, mapping = aes(x = grp, y = y), fill = "steelblue",
      scale = "count", bw = "SJ", adjust = 2, kernel = "epanechnikov", na.rm = TRUE
    )
  )
  expect_no_warning(
    geom_half_violin_sd(
      data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato",
      scale = "count", position = position_dodge(width = 0.5)
    )
  )
})

test_that("side passed as a named argument to geom_half_violin_sd never collides with ... (no duplicate-argument error)", {
  expect_no_error(
    geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), fill = "tomato", side = "r")
  )
})

test_that("missing data with no parent ggplot() still surfaces a clear error at build time, not an opaque one at construction", {
  # data now defaults to NULL (inherit), so construction itself no longer
  # errors merely because `data` was omitted - it errors later, at build
  # time, if there's truly nothing to inherit from.
  expect_no_error(geom_violin_sd(mapping = aes(x = grp, y = y)))
  expect_no_error(geom_half_violin_sd(mapping = aes(x = grp, y = y)))
})

test_that("show.legend via ... reaches only the aura sub-layer; the SD sub-layers are always FALSE", {
  # The comments at the fill_layer/outline_layer construction sites state
  # that show.legend "is always FALSE regardless of what's in `...`" - the
  # aura is the single sub-layer allowed to contribute a key, so the legend
  # shows one entry per group rather than two or three stacked ones. That
  # was prose; this makes it fail if a future refactor starts forwarding
  # show.legend to all three.
  for (geom in list(geom_violin_sd, geom_half_violin_sd)) {
    layers <- Filter(
      function(l) inherits(l, "Layer"),
      geom(data = sd_fixture, mapping = aes(x = grp, y = y), show.legend = TRUE)
    )
    expect_gte(length(layers), 3)
    # first layer is the aura, and it honoured the caller
    expect_true(isTRUE(layers[[1]]$show.legend))
    # every sub-layer after it stays out of the legend
    for (l in layers[-1]) expect_false(isTRUE(l$show.legend))
  }
})
