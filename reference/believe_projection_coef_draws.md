# Posterior fixed-effect coefficient draws from the believe-projection model

Long-format posterior draws for the same model's named (sum-coded)
fixed-effect coefficients, one row per posterior draw per coefficient
per submodel. Extracted via
[`tidybayes::spread_draws()`](https://mjskay.github.io/tidybayes/reference/spread_draws.html)
on the model's `b_*` parameters, pivoted long, then thinned to 2,000
draws per coefficient per submodel - see
`data-raw/believe-projection-posteriors.R`.

## Usage

``` r
believe_projection_coef_draws
```

## Format

A tibble with 50,000 rows and 4 variables:

- dpar:

  `"mu"` (16 coefficients) or `"sigma"` (9 coefficients).

- coef:

  Coefficient label (markdown-formatted).

- .draw:

  Posterior draw index.

- .value:

  The draw's value.

## Source

See
[believe_projection_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_draws.md).

## Details

Coefficient labels are markdown-formatted (e.g.
`"Negation<sub>GM</sub>"`, `"false<sub>GM</sub>"` for a
level-vs-grand-mean sum-coding contrast), ready for
[`plot_coef_grid_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_coef_grid_hdi.md)'s
markdown-aware facet strips.

## See also

[believe_projection](https://mkthalmann.github.io/emptyviz/reference/believe_projection.md),
[believe_projection_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_draws.md),
[believe_projection_bf](https://mkthalmann.github.io/emptyviz/reference/believe_projection_bf.md),
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md).
