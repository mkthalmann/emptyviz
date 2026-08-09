# emptyviz 0.1.0

Initial package release, migrated from the `theme.R` / `theme_bayes.R`
scripts previously copy-pasted into each project.

* **Breaking:** theme activation is no longer automatic on `library(emptyviz)`.
  Call `use_theme_mt()` explicitly to set `theme_mt()` as the active
  `ggplot2` theme and apply the package's `geom_density()` default.
* All functions are namespaced under `emptyviz::` instead of being sourced
  from a local copy of `theme.R`/`theme_bayes.R`.
* `geom_half_violin_sd()` (and, through it, `geom_split_violin_sd()`) call
  `gghalves:::StatHalfYdensity`, an unexported object of the `gghalves`
  package. This has been verified to work against `gghalves` 0.1.4; if a
  future `gghalves` release restructures that internal ggproto, these two
  geoms may need an update. See the comment above `StatHalfYdensitySD` in
  `R/geom-violin-sd.R`.
* The former `demo/demo.qmd` walkthrough is now two package vignettes,
  `vignette("geoms-and-theme")` and `vignette("bayesian-plots")`, plus a
  short README.
* Both vignettes now use real data (`believe_projection` and the
  `believe_projection_draws`/`believe_projection_coef_draws`/
  `believe_projection_bf` posterior summaries) from Thalmann & Matticchio
  (2024) instead of fabricated examples; see `?believe_projection`.
* **Fixed:** `plot_location_scale()`'s `location`/`sigma` arguments no
  longer default to same-named bare symbols (`location = location`,
  `sigma = sigma`). That self-referential default crashed with a cryptic
  "promise already under evaluation: recursive default argument reference"
  error whenever the caller's data lacked columns literally named
  `location`/`sigma` and didn't pass those arguments explicitly - which was
  every realistic use case, since posterior draws are never naturally named
  that way. `location`/`sigma` are now required arguments with no default.
