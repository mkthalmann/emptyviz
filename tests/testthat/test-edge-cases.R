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

test_that("aes(weight = ...) doesn't error, even though SD bounds stay unweighted", {
  df <- sd_fixture
  df$w <- runif(nrow(df), 0.5, 2)
  p <- ggplot(df, aes(x = grp, y = y, weight = w)) + geom_violin_sd(fill = "steelblue")
  expect_no_error(suppressWarnings(ggplot_build(p)))
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
