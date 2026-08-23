# Dark-mode variant of the base palette

Lightened tints of
[mt_colors](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)/[mt_colors3](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)/[mt_colors4](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)/[mt_colors5](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)/[mt_colors12](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md),
each hue's HSL lightness raised to keep adequate contrast against a
near-black background. Used by `theme_mt(dark = TRUE)` as the discrete
palette and geom fill defaults; exported separately so the same tints
can be reused directly (e.g. in a hand-written
[`scale_color_manual()`](https://ggplot2.tidyverse.org/reference/scale_manual.html))
without re-deriving them. `dark_mt_colors12[i]` is the dark counterpart
of `mt_colors12[i]` at every position.

## Usage

``` r
dark_mt_colors

dark_mt_colors3

dark_mt_colors4

dark_mt_colors5

dark_mt_colors12
```

## Examples

``` r
dark_mt_colors
#> [1] "#70ceeb" "#eb70af"
dark_mt_colors5
#> [1] "#70ceeb" "#eb70af" "#ebad70" "#c270eb" "#7b91e0"
dark_mt_colors12
#>  [1] "#70ceeb" "#eb70af" "#ebad70" "#c270eb" "#7b91e0" "#e755e2" "#e76855"
#>  [8] "#9f8bef" "#8befe6" "#ef8ba4" "#efd68b" "#55a3e7"
```
