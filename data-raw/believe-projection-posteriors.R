# Extracts small, vignette-ready posterior summaries from the cached
# believe-projection model. The fitted `brmsfit` itself lives outside this
# repo (a 660MB .rds, far too large to ship) - only these derived draws are
# saved as package data.
#
# Source model: `judgment ~ negation*scenario*trigger`,
# `sigma ~ negation*scenario + trigger`, fit in
# believe-projection/scripts/belproj-paper.R:220-244 (cached at
# models/belproj-nomed.rds). This script reproduces that script's own
# emmeans()/spread_draws()/bayesfactor_rope() extraction calls almost
# verbatim - see inline notes for the two places this deviates (both fixing
# a latent mismatch there, not a design choice).
library(brms)
library(emmeans)
library(tidybayes)
library(bayestestR)
library(dplyr)
library(tidyr)

model_path <- "~/Desktop/LaTeX/believe-projection/models/belproj-nomed.rds"
mod <- readRDS(model_path)

set.seed(2024)
# thin every submodel/coefficient down to this many draws - stat_slab()/
# stat_pointinterval() don't need the full 40,000-draw chain to render a
# stable density + interval, and this keeps the shipped .rda files small.
#
# Critically, this is ONE shared set of draw indices, applied by filtering
# (not a per-group slice_sample()) - plot_location_scale() needs the mu and
# sigma draws PAIRED (the same posterior iteration's location and scale
# value on one row), which only holds if every condition/submodel keeps the
# exact same .draw indices. A per-group random subsample would silently
# break that pairing (mu's kept draw 5,013 for "true-with" would no longer
# line up with sigma's own independently-sampled draws for that condition).
n_thin <- 2000
keep_draws <- sort(sample(seq_len(brms::ndraws(mod)), n_thin))
thin_draws <- function(data) {
  dplyr::filter(data, .draw %in% keep_draws)
}

# ---- 1. marginal (location + scale) draws ----------------------------
# feeds plot_ridge_hdi() (mu), the value_transform = exp section (sigma),
# and plot_location_scale() (paired via a dpar pivot on the shared .draw
# column, same idea as belproj-paper.R's own two separate emmeans() calls).
mu_draws <- mod |>
  emmeans(~ scenario * negation * trigger) |>
  gather_emmeans_draws() |>
  ungroup() |>
  mutate(dpar = "mu")

sigma_draws <- mod |>
  emmeans(~ scenario * negation * trigger, dpar = "sigma") |>
  gather_emmeans_draws() |>
  ungroup() |>
  mutate(dpar = "sigma")

believe_projection_draws <- bind_rows(mu_draws, sigma_draws) |>
  select(scenario, negation, trigger, dpar, .draw, .value) |>
  thin_draws()

# ---- 2. named fixed-effect coefficient draws --------------------------
# feeds plot_coef_grid_hdi() for both submodels.
clean_coef_name <- function(x) {
  x <- gsub("b_", "", x, fixed = TRUE)
  x <- gsub("sigma_", "", x, fixed = TRUE)
  x <- gsub("negationwith_v_GM", "Negation<sub>GM</sub>", x, fixed = TRUE)
  x <- gsub("trigger", "", x, fixed = TRUE)
  x <- gsub("MU", "", x, fixed = TRUE)
  x <- gsub("scenario", "", x, fixed = TRUE)
  gsub("_v_GM", "<sub>GM</sub>", x, fixed = TRUE)
}

# mu coefficients: same set belproj-paper.R:482-500 spreads.
mu_coef_draws <- mod |>
  spread_draws(
    b_Intercept,
    b_negationwith_v_GM,
    b_scenariofalse_v_GM,
    b_scenarioundef_v_GM,
    b_scenariocritical_v_GM,
    b_triggerMUstopMU_v_GM,
    `b_negationwith_v_GM:scenariofalse_v_GM`,
    `b_negationwith_v_GM:scenarioundef_v_GM`,
    `b_negationwith_v_GM:scenariocritical_v_GM`,
    `b_negationwith_v_GM:triggerMUstopMU_v_GM`,
    `b_scenariofalse_v_GM:triggerMUstopMU_v_GM`,
    `b_scenarioundef_v_GM:triggerMUstopMU_v_GM`,
    `b_scenariocritical_v_GM:triggerMUstopMU_v_GM`,
    `b_negationwith_v_GM:scenariofalse_v_GM:triggerMUstopMU_v_GM`,
    `b_negationwith_v_GM:scenarioundef_v_GM:triggerMUstopMU_v_GM`,
    `b_negationwith_v_GM:scenariocritical_v_GM:triggerMUstopMU_v_GM`
  ) |>
  pivot_longer(starts_with("b_"), names_to = "coef", values_to = ".value") |>
  mutate(dpar = "mu")

# sigma coefficients: belproj-paper.R:566-577 actually spreads
# `b_triggerMUstopMU_v_GM` (the MU model's own trigger coefficient) instead
# of the sigma submodel's `b_sigma_triggerMUstopMU_v_GM` - a copy/paste slip
# in the original script (confirmed against `names(mod$fit)`, which has
# both as distinct parameters). Using the real sigma-prefixed name here.
sigma_coef_draws <- mod |>
  spread_draws(
    b_sigma_Intercept,
    b_sigma_negationwith_v_GM,
    b_sigma_scenariofalse_v_GM,
    b_sigma_scenarioundef_v_GM,
    b_sigma_scenariocritical_v_GM,
    b_sigma_triggerMUstopMU_v_GM,
    `b_sigma_negationwith_v_GM:scenariofalse_v_GM`,
    `b_sigma_negationwith_v_GM:scenarioundef_v_GM`,
    `b_sigma_negationwith_v_GM:scenariocritical_v_GM`
  ) |>
  pivot_longer(starts_with("b_"), names_to = "coef", values_to = ".value") |>
  mutate(dpar = "sigma")

believe_projection_coef_draws <- bind_rows(mu_coef_draws, sigma_coef_draws) |>
  mutate(coef = clean_coef_name(coef)) |>
  select(dpar, coef, .draw, .value) |>
  thin_draws()

# ---- 3. Bayes Factor ROPE contrasts -----------------------------------
# feeds plot_bf_forest()/prepare_bf_contrasts(). Requires prior draws from
# the same model structure, not cached anywhere - this re-fits once with
# sample_prior = "only" (reuses the already-compiled Stan model via
# update(), so nothing needs recompiling).
mod_prior <- update(mod, sample_prior = "only", cores = parallel::detectCores())

# belproj-paper.R:668-672 filters `at = list(scenario = c(...), negation =
# c(...), trigger = NA)` using its own hand-typed level spellings (which
# happened to say "undef", not "undefined", for one of them, diverging from
# a rename earlier in that same script). Reading the real fitted levels off
# `mod$data` instead avoids replaying that mismatch.
bf_params <- list(
  scenario = levels(mod$data$scenario),
  negation = levels(mod$data$negation),
  trigger = NA
)

# bayesfactor_rope()'s return value carries a large `plot_data` attribute
# (the full posterior/prior density objects behind its own plotting method)
# that survives bind_rows()/as_tibble() and balloons the saved size ~80x for
# no benefit here - rebuilding as a plain tibble of just the 3 used columns
# drops it.
clean_bf <- function(x, dpar) {
  tibble(contrast = x$contrast, log_BF = x$log_BF, dpar = dpar)
}

rg_mu <- ref_grid(mod, at = bf_params)
rg_mu_prior <- ref_grid(mod_prior, at = bf_params)
bf_mu <- bayesfactor_rope(pairs(rg_mu), prior = pairs(rg_mu_prior), effects = "fixed") |>
  clean_bf("mu")

rg_sigma <- ref_grid(mod, dpar = "sigma", at = bf_params)
rg_sigma_prior <- ref_grid(mod_prior, dpar = "sigma", at = bf_params)
bf_sigma <- bayesfactor_rope(pairs(rg_sigma), prior = pairs(rg_sigma_prior), effects = "fixed") |>
  clean_bf("sigma")

believe_projection_bf <- bind_rows(bf_mu, bf_sigma)

usethis::use_data(believe_projection_draws, overwrite = TRUE)
usethis::use_data(believe_projection_coef_draws, overwrite = TRUE)
usethis::use_data(believe_projection_bf, overwrite = TRUE)
