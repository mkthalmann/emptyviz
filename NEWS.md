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
* **Breaking:** `colors`/`colors3`/`colors4`/`colors5`/`colors_many` are
  renamed to `mt_colors`/`mt_colors3`/`mt_colors4`/`mt_colors5`/
  `mt_colors_many`. The old names shadowed `grDevices::colors()`, a base R
  function, once the package was attached - confusing enough (ambiguous
  `?colors`, noisy autocomplete, a surprising break if calling code ever
  did `colors <- colors[1:2]` and later called `colors()`) to fix before
  the API has any real installed base to break.
* Every exported function now has a runnable `@examples` block.
* `theme_mt()`'s default `base_family = "Roboto Condensed"` is not
  installed by this package; its docs and the README now say so
  explicitly, since a missing font degrades silently (a fallback font, no
  error) rather than failing loudly - exactly the kind of thing that
  breaks the "reproduce this exact plot" promise silently.
* **Fixed:** `geom_split_violin_sd()`'s fill legend no longer ignores
  `labs(fill = ...)`/`guides(fill = guide_legend(title = ...))`. The
  internal `scale_fill_manual()` used to hardcode its `name` argument to
  the `split` column's name, which permanently pinned the fill guide's title
  and kept it from merging with `color`/`shape` legends mapped to the
  same column - producing two separate legends (one correctly retitled,
  one stuck showing the raw column name) with no way to avoid it short of
  renaming the column or overriding its label. The scale now leaves
  `name` as the ggplot2 default, so it follows normal `labs()`/`guides()`
  conventions like every other scale.
