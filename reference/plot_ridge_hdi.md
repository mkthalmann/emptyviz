# Ridgeline plot of posterior marginal means/SDs, one row per category

Every category stacked as a row in one shared-scale panel (optionally
faceted, but with a common axis across facets by default via
`facet_scales = "fixed"`) - for when the categories themselves are
what's being compared.

## Usage

``` r
plot_ridge_hdi(
  data,
  category,
  value = .value,
  facet = NULL,
  facet_nrow = NULL,
  facet_ncol = NULL,
  facet_scales = "fixed",
  hline = NULL,
  hline_color = mt_colors[2],
  value_transform = identity,
  value_limits = NULL,
  value_breaks = waiver(),
  category_reorder = TRUE,
  xlab = "Parameter",
  ylab = "Posterior marginal means ±HDI<sub>95</sub> ±ETI<sub>50;90;95</sub>",
  ...
)
```

## Arguments

- data:

  A data frame of long-format posterior draws.

- category:

  Unquoted column identifying each category (one row per panel/facet
  row).

- value:

  Unquoted column of posterior draws (default `.value`, matching
  [`tidybayes::gather_emmeans_draws()`](https://mjskay.github.io/tidybayes/reference/gather_emmeans_draws.html)'s
  own column name).

- facet:

  Optional unquoted column to facet by.

- facet_nrow, facet_ncol, facet_scales:

  Passed to
  [`facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
  when `facet` is given.

- hline:

  Optional y-intercept for a dashed reference line (`NULL` omits it).

- hline_color:

  Color of the reference line.

- value_transform:

  Applied to `value` before plotting (e.g. `exp` for a sigma submodel
  estimated on the log scale).

- value_limits, value_breaks:

  Passed to
  [`scale_y_continuous()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html).

- category_reorder:

  `TRUE` (default) sorts categories by their mean transformed `value`
  (descending) via
  [`forcats::fct_reorder()`](https://forcats.tidyverse.org/reference/fct_reorder.html);
  `FALSE` keeps whatever factor-level order `category` already has.

- xlab, ylab:

  Axis labels.

- ...:

  Passed through to
  [`layer_halfeye_hdi()`](https://mkthalmann.github.io/emptyviz/reference/layer_halfeye_hdi.md).

## Value

A `ggplot` object.

## Details

`category`/`value` are unquoted columns, as in the usual ggplot2 idiom.
`value` should be long-format posterior draws (one row per draw per
category), e.g. from
[`tidybayes::gather_emmeans_draws()`](https://mjskay.github.io/tidybayes/reference/gather_emmeans_draws.html).

## Examples

``` r
ridge_draws <- subset(believe_projection_draws, dpar == "mu")
plot_ridge_hdi(ridge_draws, category = scenario)
```
