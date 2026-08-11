# A half-violin with a mean +/- 1 SD band

A half-violin split into a low-alpha "aura" (the full density, drawn
first) plus a solid mean +/- 1 SD band on top (fill and/or outline,
controlled by `style`). Same calling convention as
[`gghalves::geom_half_violin()`](https://rdrr.io/pkg/gghalves/man/geom_half_violin.html)
(mapping/data first, both default `NULL`, `inherit.aes`-aware) - the
only additions are `fill`/`style`/
`base_alpha`/`sd_alpha`/`outline_color`/`sd_linewidth`.

## Usage

``` r
geom_half_violin_sd(
  mapping = NULL,
  data = NULL,
  ...,
  fill = NULL,
  side = "l",
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

- side:

  Which side to draw the half-violin on - `"l"` or `"r"`, or a vector
  thereof (see Details).

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

`side` follows gghalves' own convention: a scalar applies to every
group, a vector is indexed by sorted factor-level order of the discrete
axis (not data row order).

`gghalves` has no concept of `orientation`/`flipped_aes` anywhere in its
source (unlike ggplot2's own
[`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)) -
half-violins are vertical-only. Swapping x/y (e.g.
`aes(x = value, y = group)`) or using
[`coord_flip()`](https://ggplot2.tidyverse.org/reference/coord_flip.html)
is not supported upstream and will silently misbehave (e.g.
[`position_dodge()`](https://ggplot2.tidyverse.org/reference/position_dodge.html)
warnings about non-overlapping x intervals); this is a `gghalves`
limitation, not something `geom_half_violin_sd()` can fix.

## Examples

``` r
library(ggplot2)
set.seed(1)
df <- data.frame(
  grp = rep(c("a", "b"), each = 40),
  y = c(rnorm(40), rnorm(40, 1))
)
ggplot(df, aes(grp, y, fill = grp)) +
  geom_half_violin_sd()
```
