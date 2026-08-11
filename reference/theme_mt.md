# A markdown-aware ggplot2 theme

Extends
[`ggplot2::theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html)
with markdown/HTML-aware text (via
[`ggtext::element_markdown()`](https://wilkelab.org/ggtext/reference/element_markdown.html))
on every text element, a bottom legend, and the package's discrete color
palette
([mt_colors5](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md))
wired into the theme itself. Also sets `geom.*` defaults (a translucent
global "paper" aura, plus fill defaults for
[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/[`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)/[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/
[`geom_ribbon()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)/[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html))
so plots look consistent without repeating `fill = ...` on every layer.

## Usage

``` r
theme_mt(
  base_size = 19,
  base_family = "Roboto Condensed",
  plot_title_family = base_family,
  subtitle_family = base_family,
  strip_text_family = base_family,
  axis_title_family = base_family,
  axis_text_family = base_family,
  caption_family = base_family,
  plot_title_size = base_size + 2,
  axis_text_size = base_size,
  strip_text_size = base_size + 2,
  subtitle_size = base_size + 2,
  caption_size = base_size - 3,
  axis_title_size = base_size + 2,
  dark = FALSE,
  grid_color = if (dark) .dark_grid else "gray85",
  show_axis_line = TRUE,
  axis_text_color = if (dark) .dark_axis_text else "gray30"
)
```

## Arguments

- base_size:

  Base font size, in points.

- base_family, plot_title_family, subtitle_family, strip_text_family,
  axis_title_family, axis_text_family, caption_family:

  Font families for each text element; all default to `base_family`. See
  Details for the `"Roboto Condensed"` default's system requirement.

- plot_title_size, axis_text_size, strip_text_size, subtitle_size,
  caption_size, axis_title_size:

  Font sizes for each text element, all derived from `base_size` by
  default.

- dark:

  Build a dark-mode-appropriate variant instead: transparent plot/panel
  background (rather than the translucent white "paper" used in light
  mode), light text/gridline/ink colors, and
  [dark_mt_colors5](https://mkthalmann.github.io/emptyviz/reference/dark_mt_colors.md)
  in place of
  [mt_colors5](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)
  as the discrete palette and geom fill default. Meant for rendering the
  same plot a second time for a dark-themed page, alongside a
  `dark = FALSE` (default) render for the light-themed page -
  `theme_mt()`'s output with `dark = FALSE` is unchanged by this
  argument existing at all. `grid_color`/`axis_text_color` still default
  off of `dark` but can be overridden individually either way.

- grid_color:

  Color of the panel grid lines (and the axis line, when
  `show_axis_line` is `TRUE`). Defaults to a near-invisible light gray,
  or a near-invisible dark gray when `dark = TRUE`.

- show_axis_line:

  Whether to draw the axis line at all (`TRUE`) or make it transparent
  (`FALSE`).

- axis_text_color:

  Color of the axis tick labels. Defaults to a dark gray, or a light
  gray when `dark = TRUE`.

## Value

A `ggplot2` theme object.

## Details

Call
[`use_theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/use_theme_mt.md)
to make this the session's active theme -
[`library(emptyviz)`](https://github.com/mkthalmann/emptyviz) does not
do this automatically.

`base_family` (and every other `*_family` argument, which default to it)
defaults to `"Roboto Condensed"`, a font this package does not install
or register - it must already be present on the system (and discoverable
by the graphics device in use) for text to render as intended. If it
isn't installed, most graphics devices silently substitute a fallback
font rather than erroring, so a plot can look subtly different across
machines with no warning. Install it (e.g. via a system font manager, or
`sysfonts::font_add_google("Roboto Condensed")` +
`showtext::showtext_auto()` for device-independent rendering), or pass a
`base_family` you know is available, if reproducing a plot's exact
appearance matters.

## See also

[`use_theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/use_theme_mt.md)

## Examples

``` r
library(ggplot2)
# a system-available family sidesteps the "Roboto Condensed" requirement
# described in Details, so this renders identically everywhere
ggplot(mtcars, aes(wt, mpg)) +
  geom_point() +
  theme_mt(base_family = "")
```
