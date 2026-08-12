# Two half-violins back to back, split by a two-level column

A "split violin": two
[`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md)
halves back-to-back at the same x position, one per level of `split`,
instead of the caller pre-filtering `data` and calling
[`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md)
twice by hand with `side = "l"`/`"r"`. `split` follows the same "sorted
factor-level order" convention gghalves itself uses for `side` (left
gets the first sorted level, right the second) - pass `flip = TRUE` to
swap them.

## Usage

``` r
geom_split_violin_sd(
  mapping = NULL,
  data = NULL,
  ...,
  split,
  flip = FALSE,
  fill = NULL,
  style = c("both", "outline", "fill"),
  base_alpha = 0.25,
  sd_alpha = 0.25,
  outline_color = NULL,
  sd_linewidth = 0.3,
  scale = "count",
  trim = TRUE,
  inherit.aes = TRUE
)
```

## Arguments

- mapping, data, ..., inherit.aes:

  As in
  [`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md),
  except `data` is required (see Details).

- split:

  An unquoted column in `data` with exactly *two* levels (more or fewer
  is an error). Rows with `NA` in this column are dropped with a
  warning.

- flip:

  Swap which split level renders on the left vs. right.

- fill:

  Defaults to the package's own two-color
  [mt_colors](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)
  palette (one color per side); pass a length-2 vector to override, one
  color per sorted (or flipped) split level. Any `aes(fill = ...)` in
  `mapping` is ignored - fill is spoken for by `split` here.

- style, base_alpha, sd_alpha, sd_linewidth, trim:

  As in
  [`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md).

- outline_color:

  Length-2 or `NULL` (falls back to `fill` per side).

- scale:

  Passed to the underlying density stat; see Details.

## Value

A list of `ggplot2` layers, scales, and guides.

## Details

Unlike
[`geom_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_violin_sd.md)/[`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md),
`data` must be supplied directly (not `NULL`/inherited from the plot) -
the split has to happen before the two side-specific layer sets are
built, so the data must exist at call time, not at
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
time.

`scale` defaults to `"count"` (not gghalves'/ggplot2's own `"area"`
default), matching what
[`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)'s
own default would be. This does NOT make the two sides' widths
comparable to each other - left and right are two independent
[`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md)
layers, each with its own Stat computation, so `"count"` only normalizes
a side's x-levels against *that side's own* other x-levels, never
against the other side's counts.

The aura and SD-fill sub-layers are hidden from the legend
(`show.legend = FALSE`) on both sides; only a dedicated dummy layer
contributes a key, so `split` shows up as one clean legend entry per
level instead of 2-3 near-duplicate, differently-alpha'd swatches (two
layers both mapping fill to the same scale with `show.legend = TRUE`
would otherwise overlay every contributing layer's key glyph at every
break).

The internal fill scale leaves its `name` as the ggplot2 default
([`waiver()`](https://ggplot2.tidyverse.org/reference/waiver.html))
rather than hardcoding it to the `split` column name, so
`labs(fill = ...)`/`guides(fill = guide_legend(title = ...))` control
the legend title the normal ggplot2 way and can merge with `color`/
`shape` legends mapped to the same column.

Warns (does not silently drop) when an x-level has data on only one side
of the split, or when a side's cell count falls under the `n >= 2`
minimum the underlying SD-band stat already requires - splitting divides
already-thin repeated-measures cells a third way. Either way, the plot
still renders correctly around the thin/missing cell - a below-minimum
side is silently dropped by the underlying density stat (same as
[`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md)),
it doesn't stop the rest of the plot from drawing.

## Examples

``` r
library(ggplot2)
set.seed(1)
df <- data.frame(
  grp = rep(c("a", "b", "c"), each = 40),
  cond = rep(c("x", "y"), 60),
  y = rnorm(120)
)
ggplot(df, aes(grp, y)) +
  geom_split_violin_sd(data = df, split = cond)
```
