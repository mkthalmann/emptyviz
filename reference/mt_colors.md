# Base two-color palette

The package's base discrete palette, and three extensions of it
(`mt_colors3`, `mt_colors4`, `mt_colors5`) with one, two, and three
additional hues appended.
[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)
uses `mt_colors5` as its default discrete palette
(`palette.colour.discrete`/`palette.fill.discrete`).

## Usage

``` r
mt_colors

mt_colors3

mt_colors4

mt_colors5
```

## Examples

``` r
mt_colors
#> [1] "#066b8a" "#8a064a"
mt_colors5
#> [1] "#066b8a" "#8a064a" "#d56f09" "#9109d5" "#142f8f"
```
