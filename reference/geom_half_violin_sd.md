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

- side:

  Which side to draw the half-violin on - `"l"` or `"r"`, or a vector
  thereof (see Details).

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

x-levels (or, when built through
[`geom_split_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_split_violin_sd.md),
one thin side of an x-level) with fewer than 2 raw data points are
silently dropped by the underlying density stat - the same
[`stats::sd()`](https://rdrr.io/r/stats/sd.html)-needs-2-points floor
[`geom_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_violin_sd.md)
has - and ggplot2's own "Groups with fewer than two datapoints have been
dropped" warning fires. The remaining groups still render correctly
around the gap.

Only the aura sub-layer ever contributes a legend key (the SD-band
sub-layers are always `show.legend = FALSE`), so the legend shows one
clean, full-opacity swatch per group instead of the aura's and SD-fill's
low-alpha keys overlaid on top of each other.

When `outline_color` isn't given and `fill` isn't passed as a literal
(i.e. it's mapped via `aes(fill = ...)`, locally or inherited from the
plot), the SD-band outline's colour tracks each group's resolved fill
automatically - it no longer falls back to one flat default color for
every group.

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
