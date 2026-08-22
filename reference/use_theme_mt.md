# Activate `theme_mt()` as the session's default theme

Calls
[`ggplot2::theme_set()`](https://ggplot2.tidyverse.org/reference/get_theme.html)
with `theme_mt(base_size = base_size)`. Call this once per
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
  [`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md),
  whose own default is the same value - the two used to disagree by
  nearly 2x.

- ...:

  Passed to
  [`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)
  as well - e.g. `base_family` or `dark`, for callers that want an
  activated theme other than the plain default.

## Value

`invisible(NULL)`, called for its side effect.

## Details

This used to also call
`update_geom_defaults("density", list(adjust = 5))`, documented as a
heavier smoothing bandwidth. It never worked: `adjust` is a
[`ggplot2::stat_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
parameter, not a geom aesthetic, so the call only wrote a phantom
`adjust` entry into `GeomDensity$default_aes` where nothing reads it,
session-wide and with no way to undo it short of restarting R. Bandwidth
was ggplot2's default throughout. Pass `adjust` to
[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)/[`stat_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html)
directly if you want heavier smoothing.

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
