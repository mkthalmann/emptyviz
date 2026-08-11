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

  Alpha of the aura and SD-band sub-layers.

- outline_color:

  Color of the SD-band outline; defaults to `fill` when not given.

- sd_linewidth:

  Line width of the SD-band outline.

## Value

A list of `ggplot2` layers.

## Details

`alpha`/`color`/`colour`/`linewidth`/`trim` passed via `...` are
reserved (used internally by the aura/fill/outline sub-layers) and will
warn, not error or silently vanish - use
`base_alpha`/`sd_alpha`/`outline_color`/ `sd_linewidth` instead.

SD bounds are always the *unweighted* mean/sd of the raw y values, even
if `aes(weight = ...)` is mapped.

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
