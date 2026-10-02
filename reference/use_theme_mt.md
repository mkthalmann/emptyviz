# Activate `theme_mt()` as the session's default theme

Calls
[`ggplot2::theme_set()`](https://ggplot2.tidyverse.org/reference/get_theme.html)
with `theme_mt(base_size = base_size)`. Call this once per
session/script after
[`library(emptyviz)`](https://mkthalmann.github.io/emptyviz/) - loading
the package does not do this automatically, since a package silently
mutating global `ggplot2` state on load is a bad default.

## Usage

``` r
use_theme_mt(base_size = 10, ..., dual_render = TRUE)
```

## Arguments

- base_size:

  Passed to
  [`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md),
  whose own default is the same value.

- ...:

  Passed to
  [`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)
  as well - e.g. `base_family` or `dark`, for callers that want an
  activated theme other than the plain default.

- dual_render:

  Whether to register the dual light/dark `knit_print` method described
  in Details (default `TRUE`).

## Value

`invisible(NULL)`, called for its side effect.

## Details

It changes no geom defaults. For heavier density smoothing, pass
`adjust` to
[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)/[`stat_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
directly.

If `knitr` is installed, this also registers a `knit_print` method for
`ggplot`/`patchwork` objects that renders a chunk twice - once normally,
once with a dark-mode color overlay - whenever that chunk sets the
`dual_render` chunk option to `TRUE` (directly, or via a project-wide
`knitr: opts_chunk: dual_render: true` default), emitting both images
wrapped for Quarto's light/dark toggle. This applies only to HTML output
rendered by Quarto. For PDF or Word output, figures are rendered
normally; for HTML not rendered by Quarto they are too, with a warning.
Chunks that don't set the option are unaffected. Pass
`dual_render = FALSE` to leave knitr's printing of ggplot objects
untouched; this also removes the method if an earlier call registered
it.

A dual-rendered chunk's `fig.alt` becomes the alt text of both images. A
`fig.cap` is shown as plain text: markdown and math in it are not
rendered, unless the chunk has a `fig-` label, in which case Quarto
captions the figure itself.

## See also

[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)

## Examples

``` r
old <- ggplot2::theme_get() # so the example can restore it afterward
use_theme_mt()
ggplot2::theme_set(old) # not required in a real script/session
```
