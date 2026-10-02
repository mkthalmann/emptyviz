test_that("ggplot(df, aes(x, y)) + geom_violin_sd() works, matching geom_violin's own calling convention", {
  p <- ggplot(sd_fixture, aes(x = grp, y = y)) + geom_violin_sd(fill = "steelblue")
  expect_no_error(ggplot_build(p))
})

test_that("ggplot(df, aes(x, y)) + geom_half_violin_sd() works", {
  p <- ggplot(sd_fixture, aes(x = grp, y = y)) + geom_half_violin_sd(fill = "tomato")
  expect_no_error(ggplot_build(p))
})

test_that("mapping/data can still be supplied per-call, standard ggplot2 layer-data-override style", {
  df2 <- sd_fixture
  df2$y <- df2$y + 10
  p <- ggplot(sd_fixture, aes(x = grp, y = y)) +
    geom_violin_sd(data = df2, fill = "steelblue")
  expect_no_error(ggplot_build(p))
})

test_that("inherit.aes = FALSE opts a layer out of the parent ggplot() mapping, as with any geom", {
  p <- ggplot(sd_fixture, aes(x = grp, y = y)) +
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), inherit.aes = FALSE, fill = "steelblue")
  expect_no_error(ggplot_build(p))
})

test_that("calling with neither data nor mapping and no parent ggplot() aes builds an empty plot, matching plain geom_violin/geom_half_violin (no longer a missing-argument error)", {
  expect_no_error(ggplot_build(ggplot() + geom_violin()))
  expect_no_error(ggplot_build(ggplot() + geom_violin_sd()))
  expect_no_error(ggplot_build(ggplot() + gghalves::geom_half_violin()))
  expect_no_error(ggplot_build(ggplot() + geom_half_violin_sd()))
})

test_that("data given as a function or a lambda formula is applied to the plot data, as for any layer", {
  keep_ab <- function(d) d[d$grp != "c", ]
  for (geom in list(geom_violin_sd, geom_half_violin_sd)) {
    built <- ggplot_build(ggplot(sd_fixture, aes(grp, y)) + geom(data = keep_ab))
    expect_true(all(vapply(built$data, function(d) length(unique(d$x)) == 2, logical(1))))
    built <- ggplot_build(ggplot(sd_fixture, aes(grp, y)) + geom(data = ~ subset(.x, grp != "c")))
    expect_true(all(vapply(built$data, function(d) length(unique(d$x)) == 2, logical(1))))
  }
  expect_error(geom_split_violin_sd(data = keep_ab, split = grp), "data frame")
})
