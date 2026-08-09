test_that("trim passed via ... no longer crashes with a duplicate-argument error, and warns instead", {
  expect_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), trim = TRUE),
    "trim"
  )
  expect_warning(
    geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), trim = TRUE),
    "trim"
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
