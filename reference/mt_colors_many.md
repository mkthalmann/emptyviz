# Continuous color ramp between the first two base colors

A
[`grDevices::colorRampPalette()`](https://rdrr.io/r/grDevices/colorRamp.html)
between `mt_colors[1]` and `mt_colors[2]`, for continuous scales that
want to match the discrete palette's hue.

## Usage

``` r
mt_colors_many(n)
```

## Arguments

- n:

  Number of colors to generate.

## Value

A character vector of `n` hex colors.

## Examples

``` r
mt_colors_many(5)
#> [1] "#066B8A" "#265179" "#483869" "#691F5A" "#8A064A"
```
