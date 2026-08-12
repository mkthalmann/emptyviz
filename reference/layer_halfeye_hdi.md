# The recurring halfeye (HDI slab + ETI point-interval) layer bundle

The `stat_slab()`+`stat_pointinterval()` block that recurs, nearly
verbatim, across posterior-summary plots: an HDI-shaded density
([`ggdist::stat_slab()`](https://mjskay.github.io/ggdist/reference/stat_slab.html))
plus a multi-width ETI point-interval
([`ggdist::stat_pointinterval()`](https://mjskay.github.io/ggdist/reference/stat_pointinterval.html)).
Returns a list of layers/scales to add to a
[`ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html) that
already has a discrete category on one axis and a continuous draws
column on the other - orientation (vertical vs. flipped) is the caller's
job via
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html),
not this function's. Used internally by
[`plot_ridge_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_ridge_hdi.md)
and
[`plot_coef_grid_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_coef_grid_hdi.md);
exposed standalone for building a custom layout around the same visual
grammar.

## Usage

``` r
layer_halfeye_hdi(
  slab_widths = c(0.95, 0.999),
  interval_widths = c(0.5, 0.9, 0.95),
  slab_limits = NULL,
  pointinterval_limits = NULL,
  scale = 1,
  dodge_width = 0.4,
  gap = 0.02,
  n = NULL,
  point_size = 1.5,
  fill = NULL,
  fill_range = c(0.4, 1),
  interval_color = NULL
)
```

## Arguments

- slab_widths:

  HDI width(s) for the slab shading, passed to `stat_slab()`'s `.width`.

- interval_widths:

  ETI width(s) for the point-interval, passed to
  `stat_pointinterval()`'s `.width`.

- slab_limits, pointinterval_limits:

  Passed through to `stat_slab()`'s/ `stat_pointinterval()`'s own
  `limits` argument (`NULL` by default, i.e. ggdist's own auto
  behavior). Not the same as `value_limits` in
  [`plot_ridge_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_ridge_hdi.md)/[`plot_coef_grid_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_coef_grid_hdi.md),
  which is a real axis-scale limit.

- scale:

  Slab height, passed to `stat_slab()`.

- dodge_width:

  Dodge width shared by the slab and point-interval.

- gap:

  Point-interval offset from the slab baseline, as a fraction of panel
  height (see Details).

- n:

  Passed to `stat_slab()`'s `n` (density resolution), if given.

- point_size:

  Size of the point-interval's point.

- fill:

  Base slab color, ramped by HDI width (see `fill_range`); defaults to
  `mt_colors[1]`.

- fill_range:

  Two-value alpha/lightness range (passed to
  [`ggdist::scale_fill_ramp_discrete()`](https://mjskay.github.io/ggdist/reference/scale_colour_ramp.html)'s
  `range`) the slab's HDI widths are shaded across, from the widest
  (most faded, closer to white) to the narrowest (most saturated, `fill`
  at full strength). Default `c(.4, 1)`.

- interval_color:

  Color of the point-interval; defaults to `mt_colors[1]`.

## Value

A list of `ggplot2`/`ggdist` layers, scales, and guides.

## Details

`scale` (slab height) and `dodge_width` have no single correct default -
pass whatever fits your panel count and coefficient spread.

`gap` is how far the point-interval is shifted away from the slab's
baseline, as a target fraction of *panel height* (see
`position_dodge_gap()`'s own comment for why this - not a row-unit
fraction - is the right invariant to hold constant across callers with
different category counts per panel). Default `.02` (~2% of panel
height) looks right both for many-categories-sharing-one-panel layouts
and one-category-per-panel grids; `0` reproduces a touching layout with
no gap at all.

## Examples

``` r
library(ggplot2)
set.seed(1)
draws <- data.frame(
  cond = rep(c("a", "b"), each = 500),
  value = c(rnorm(500), rnorm(500, 1))
)
ggplot(draws, aes(x = cond, y = value)) +
  layer_halfeye_hdi() +
  coord_flip()
```
