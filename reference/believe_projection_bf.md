# Bayes Factor ROPE contrasts from the believe-projection model

[`bayestestR::bayesfactor_rope()`](https://easystats.github.io/bayestestR/reference/bayesfactor_parameters.html)
output for the same model: one row per pairwise contrast (trigger
marginalized out) among the 8 `scenario` x `negation` cells, for both
the mu and sigma submodels. Requires prior draws from the same model
structure (`update(mod, sample_prior = "only")`, refit once for this
extraction, not otherwise cached) - see
`data-raw/believe-projection-posteriors.R`.

## Usage

``` r
believe_projection_bf
```

## Format

A tibble with 56 rows and 3 variables:

- contrast:

  Raw bayestestR contrast label.

- log_BF:

  Log Bayes Factor for the region of practical equivalence (ROPE), \\0
  \pm 0.1 \times SD(Y)\\.

- dpar:

  `"mu"` or `"sigma"`.

## Source

See
[believe_projection_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_draws.md).

## Details

`contrast` is bayestestR's own auto-generated `"<left> - <right> NA"`
string (the trailing `" NA"` marks `trigger` as marginalized out) -
unchanged, ready for
[`prepare_bf_contrasts()`](https://mkthalmann.github.io/emptyviz/reference/prepare_bf_contrasts.md)/[`plot_bf_forest()`](https://mkthalmann.github.io/emptyviz/reference/plot_bf_forest.md)'s
`pairs` argument the way
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md)
uses it.

## See also

[believe_projection](https://mkthalmann.github.io/emptyviz/reference/believe_projection.md),
[believe_projection_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_draws.md),
[believe_projection_coef_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_coef_draws.md),
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md).
