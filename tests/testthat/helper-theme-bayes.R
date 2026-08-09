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
  purrr::pmap_dfr(
    list(cats, mus, sigmas),
    function(cat, mu, sigma) {
      data.frame(
        cond = cat,
        facet_grp = rep(c("a", "b"), each = 100),
        .value = rnorm(200, mu, sigma)
      )
    }
  )
})()

# Synthetic coefficient draws, standing in for tidybayes::spread_draws() +
# pivot_longer() on named brms coefficients.
bayes_coef_fixture <- (function() {
  set.seed(2)
  coefs <- forcats::fct_inorder(c("Intercept", "negation", "scenario_false"))
  mus <- c(1, -.4, .2)
  purrr::pmap_dfr(
    list(as.character(coefs), mus),
    function(coef, mu) {
      data.frame(coef = coef, .value = rnorm(300, mu, .3))
    }
  ) |>
    dplyr::mutate(coef = forcats::fct_relevel(coef, levels(coefs)))
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
  specs <- tidyr::expand_grid(
    category = c("narrow", "wide"),
    trigger = c("t1", "t2")
  ) |>
    dplyr::mutate(
      mu = dplyr::case_when(
        category == "narrow" & trigger == "t1" ~ -1,
        category == "narrow" & trigger == "t2" ~ 1,
        category == "wide" & trigger == "t1" ~ -1.5,
        category == "wide" & trigger == "t2" ~ 1.5
      ),
      sig = dplyr::if_else(category == "narrow", .3, .8)
    )
  specs |>
    dplyr::rowwise() |>
    dplyr::mutate(draws = list(data.frame(
      .draw = 1:300,
      location = rnorm(300, mu, .1),
      sigma = rnorm(300, sig, .05)
    ))) |>
    dplyr::ungroup() |>
    dplyr::select(category, trigger, draws) |>
    tidyr::unnest(draws)
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
# `at = list(trigger = NA)`, as belproj-paper.R does), with no SE column at
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
