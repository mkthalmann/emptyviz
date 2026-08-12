# A violin with a mean +/- 1 SD band

A violin split into a low-alpha "aura" (the full density, drawn first)
plus a solid mean +/- 1 SD band on top (fill and/or outline, controlled
by `style`). Same calling convention as
[`ggplot2::geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)
(mapping/data first, both default `NULL`, `inherit.aes`-aware, supports
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
and horizontal orientation via `aes(x = value, y = group)`)

- the only additions are `fill`/`style`/`base_alpha`/`sd_alpha`/
  `outline_color`/`sd_linewidth`.

## Usage

``` r
geom_violin_sd(
  mapping = NULL,
  data = NULL,
  ...,
  fill = NULL,
  style = c("both", "outline", "fill"),
  base_alpha = 0.25,
  sd_alpha = 0.25,
  outline_color = NULL,
  sd_linewidth = 0.3,
  trim = TRUE,
  inherit.aes = TRUE
)
```

## Arguments

- mapping, data, ..., inherit.aes:

  As in
  [`gghalves::geom_half_violin()`](https://rdrr.io/pkg/gghalves/man/geom_half_violin.html).

- fill:

  A constant fill for all violins; omit it to map fill via `mapping`
  instead (`aes(fill = ...)`) the normal ggplot2 way.

- style:

  One of `"both"` (default), `"fill"`, or `"outline"` - which SD-band
  sub-layer(s) to draw.

- base_alpha, sd_alpha:

  Alpha of the aura and SD-band *fill* sub-layers, respectively. The
  SD-band *outline* is always drawn at full opacity regardless of
  either - it's the one element meant to reliably mark the SD band even
  when `base_alpha`/`sd_alpha` are turned down or off entirely.

- outline_color:

  Color of the SD-band outline; defaults to `fill` when given as a
  literal, or otherwise tracks each group's resolved fill automatically
  (see Details).

- sd_linewidth:

  Line width of the SD-band outline.

- trim:

  Trim each violin to the range of the observed data (`TRUE`, the
  default, matching
  [`gghalves::geom_half_violin()`](https://rdrr.io/pkg/gghalves/man/geom_half_violin.html)'s
  own default) or let the density estimate extend past it for a softer,
  tapered edge (`FALSE`).

## Value

A list of `ggplot2` layers and a
[`guides()`](https://ggplot2.tidyverse.org/reference/guides.html) call
(tuned to keep the legend key at full opacity - see Details).

## Details

`alpha`/`color`/`colour`/`linewidth`/`stat` passed via `...` are
reserved (used internally by the aura/fill/outline sub-layers) and will
warn, not error or silently vanish - use
`base_alpha`/`sd_alpha`/`outline_color`/ `sd_linewidth` instead (there's
no equivalent substitute for `stat` - swapping it out isn't meaningful
for this geom's own identity).

SD bounds are always the *unweighted* mean/sd of the raw y values, even
if `aes(weight = ...)` is mapped.

As with
[`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md):
only the aura sub-layer ever contributes a legend key, and the SD-band
outline's colour tracks each group's resolved fill automatically when
`outline_color`/`fill` aren't given as literals.

## Examples

``` r
library(ggplot2)
set.seed(1)
df <- data.frame(
  grp = rep(c("a", "b", "c"), each = 40),
  y = c(rnorm(40), rnorm(40, 1.5, 0.6), rnorm(40, -0.5, 1.8))
)
ggplot(df, aes(grp, y, fill = grp)) +
  geom_violin_sd() +
  guides(fill = "none")
```
