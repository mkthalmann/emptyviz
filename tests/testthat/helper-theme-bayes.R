# Fixtures are built with base R only, so the suite does not depend on
# suggested packages to load.

# Synthetic long-format posterior draws, standing in for the output of
# tidybayes::gather_emmeans_draws()/spread_draws() - one row per draw per
# category, deliberately with unequal spread across categories (some tight,
# some wide) so tests can check that both the location and the shape of the
# rendered slab respond to real differences in the data, not just render
# without erroring.
bayes_draws_fixture <- (function() {
  set.seed(1)
  cats <- c("true-without", "false-with", "undefined-without", "critical-with")
  mus <- c(1.5, 1.5, 0, 0)
  sigmas <- c(.3, .3, .8, .8)
  do.call(rbind, Map(
    function(cat, mu, sigma) {
      data.frame(
        cond = cat,
        facet_grp = rep(c("a", "b"), each = 100),
        .value = rnorm(200, mu, sigma)
      )
    },
    cats, mus, sigmas
  ))
})()

# Synthetic coefficient draws, standing in for tidybayes::spread_draws() +
# pivot_longer() on named brms coefficients.
bayes_coef_fixture <- (function() {
  set.seed(2)
  coefs <- forcats::fct_inorder(c("Intercept", "negation", "scenario_false"))
  mus <- c(1, -.4, .2)
  draws <- do.call(rbind, Map(
    function(coef, mu) data.frame(coef = coef, .value = rnorm(300, mu, .3)),
    as.character(coefs), mus
  ))
  draws$coef <- factor(draws$coef, levels = levels(coefs))
  draws
})()

# Synthetic PAIRED (location, sigma) draws - one row per (category,
# trigger, .draw), i.e. from the *same* posterior iteration - standing in
# for the join-on-.draw a real analysis does between two separate
# gather_emmeans_draws() calls (one for location, one for dpar = "sigma").
# `trigger`'s mean genuinely differs by facet level (t1/t2), deliberately -
# needed to catch aggregation-across-facets bugs in
# plot_location_scale()'s point_data (a real bug found during development:
# without grouping by the facet variable too, the point layer silently
# averaged a category's values *across* facets and replicated that wrong
# point into every panel).
location_scale_fixture <- (function() {
  set.seed(4)
  specs <- expand.grid(
    trigger = c("t1", "t2"),
    category = c("narrow", "wide"),
    stringsAsFactors = FALSE
  )[, c("category", "trigger")]
  mus <- c(narrow.t1 = -1, narrow.t2 = 1, wide.t1 = -1.5, wide.t2 = 1.5)
  sigs <- c(narrow = .3, wide = .8)
  do.call(rbind, lapply(seq_len(nrow(specs)), function(i) {
    category <- specs$category[i]
    trigger <- specs$trigger[i]
    location <- rnorm(300, mus[[paste(category, trigger, sep = ".")]], .1)
    sigma <- rnorm(300, sigs[[category]], .05)
    data.frame(
      category = category, trigger = trigger,
      .draw = 1:300, location = location, sigma = sigma
    )
  }))
})()

# Synthetic per-contrast log-BF table, standing in for a coerced
# bayestestR::bayesfactor_rope() result - one row per contrast, with both a
# clearly positive and a clearly negative log_bf (so sign-based coloring
# tests have both cases to check) and one deliberately inside the default
# weak-evidence threshold (log(3) =~ 1.10), so tests can check shading/
# verdict logic against a real borderline case, not just extremes.
bf_forest_fixture <- data.frame(
  contrast = c(
    "true-with vs true-without",
    "false-with vs false-without",
    "critical-with vs critical-without",
    "undef-with vs undef-without"
  ),
  log_bf = c(8.2, 7.9, 0.5, -0.4),
  se = c(.3, .3, .2, .15)
)

# Synthetic RAW bayestestR::bayesfactor_rope()-style output - a `contrast`
# column in emmeans' own auto-generated "<left> - <right> NA" format (the
# trailing " NA" artifact from marginalizing over a grouping variable, e.g.
# `at = list(trigger = NA)`), with no SE column at
# all (a bayesfactor_rope() call, unlike a repeated bridge-sampling
# estimate, has no natural per-contrast SE) and one extra row
# ("true with - false with NA") deliberately NOT requested by
# `bf_pairs_fixture` below, to confirm prepare_bf_contrasts()'s `pairs`
# argument actually filters rather than just relabeling everything.
bf_raw_contrasts_fixture <- data.frame(
  contrast = c(
    "true with - true without NA",
    "false with - false without NA",
    "critical with - critical without NA",
    "undef with - undef without NA",
    "false with - critical with NA",
    "true with - false with NA"
  ),
  log_BF = c(8.2, 7.9, 1.1, -0.4, 5.3, 0.9)
)

bf_pairs_fixture <- list(
  c("undef with", "undef without"),
  c("critical with", "critical without"),
  c("false with", "critical with")
)

# plot_bf_forest() draws its points in one layer per sign; this binds the
# built data of all point layers together.
built_points <- function(p) {
  built <- ggplot_build(p)
  idx <- which(vapply(p$layers, function(l) inherits(l$geom, "GeomPoint"), logical(1)))
  dplyr::bind_rows(built$data[idx])
}
