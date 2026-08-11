# Posterior marginal draws from the believe-projection model

Long-format posterior draws from the distributional `brms` model fit to
[believe_projection](https://mkthalmann.github.io/emptyviz/reference/believe_projection.md)
(`judgment ~ negation*scenario*trigger`,
`sigma ~ negation*scenario + trigger`), one row per posterior draw per
`scenario` x `negation` x `trigger` cell x submodel. Extracted via
`emmeans(mod, ~scenario*negation*trigger)` (and again with
`dpar = "sigma"`) piped through
[`tidybayes::gather_emmeans_draws()`](https://mjskay.github.io/tidybayes/reference/gather_emmeans_draws.html),
then thinned to 2,000 draws per cell per submodel - see
`data-raw/believe-projection-posteriors.R`.

## Usage

``` r
believe_projection_draws
```

## Format

A tibble with 64,000 rows and 6 variables:

- scenario:

  `"true"`, `"false"`, `"undef"`, or `"critical"`.

- negation:

  `"with"` or `"without"`.

- trigger:

  `"*again*"` or `"*stop*"` (markdown-italicized).

- dpar:

  `"mu"` (the judgment submodel) or `"sigma"` (the distributional scale
  submodel, log scale).

- .draw:

  Posterior draw index.

- .value:

  The draw's value.

## Source

See
[believe_projection](https://mkthalmann.github.io/emptyviz/reference/believe_projection.md).
Model fit in `believe-projection/scripts/belproj-paper.R`; draws
extracted by `data-raw/believe-projection-posteriors.R`.

## Details

`dpar == "sigma"` draws are on the log scale (the model's own link
function for that submodel); back-transform with
[`exp()`](https://rdrr.io/r/base/Log.html) before plotting, e.g. via
[`plot_ridge_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_ridge_hdi.md)'s
`value_transform = exp`.

Pivoting `dpar` wide and joining on `.draw` (plus the condition columns)
recovers the *paired* location/scale draws
[`plot_location_scale()`](https://mkthalmann.github.io/emptyviz/reference/plot_location_scale.md)
requires - the same pairing
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md)
builds by hand.

## See also

[believe_projection](https://mkthalmann.github.io/emptyviz/reference/believe_projection.md),
[believe_projection_coef_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_coef_draws.md),
[believe_projection_bf](https://mkthalmann.github.io/emptyviz/reference/believe_projection_bf.md),
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md).
