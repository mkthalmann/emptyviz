# Activate `theme_mt()` as the session's default theme

Calls
[`ggplot2::theme_set()`](https://ggplot2.tidyverse.org/reference/get_theme.html)
with `theme_mt(base_size = base_size)` and sets
[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)'s
default `adjust` to 5 (a heavier smoothing bandwidth than ggplot2's own
default, matching how
[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
is used throughout this package's plots). Call this once per
session/script after
[`library(emptyviz)`](https://github.com/mkthalmann/emptyviz) - loading
the package does not do this automatically, since a package silently
mutating global `ggplot2` state on load is a bad default.

## Usage

``` r
use_theme_mt(base_size = 10, ...)
```

## Arguments

- base_size:

  Passed to
  [`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md).

- ...:

  Passed to
  [`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)
  as well - e.g. `base_family` or `dark`, for callers that want an
  activated theme other than the plain default.

## Value

`invisible(NULL)`, called for its side effect.

## Details

If `knitr` is installed, this also registers a `knit_print` method for
`ggplot`/`patchwork` objects that renders a chunk twice - once normally,
once with a dark-mode color overlay - whenever that chunk sets the
`dual_render` chunk option to `TRUE` (directly, or via a project-wide
`knitr: opts_chunk: dual_render: true` default), emitting both images
wrapped for Quarto's light/dark toggle. Chunks that don't set the option
are completely unaffected.

## See also

[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)

## Examples

``` r
old <- ggplot2::theme_get() # so the example can restore it afterward
use_theme_mt()
ggplot2::theme_set(old) # not required in a real script/session
```
