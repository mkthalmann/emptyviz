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
use_theme_mt(base_size = 10)
```

## Arguments

- base_size:

  Passed to
  [`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md).

## Value

`invisible(NULL)`, called for its side effect.

## See also

[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)

## Examples

``` r
old <- ggplot2::theme_get() # so the example can restore it afterward
use_theme_mt()
ggplot2::theme_set(old) # not required in a real script/session
```
