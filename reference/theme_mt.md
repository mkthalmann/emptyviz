# A markdown-aware ggplot2 theme

Extends
[`ggplot2::theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html)
with markdown/HTML-aware text (via
[`ggtext::element_markdown()`](https://wilkelab.org/ggtext/reference/element_markdown.html))
on every text element, a bottom legend, and the package's color palettes
([mt_colors12](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)
for discrete scales, a lightness ramp of `mt_colors[1]` for continuous
ones) wired into the theme itself. Also sets `geom.*` defaults (an
opaque "paper" for label backgrounds, plus fill defaults for
[`geom_bar()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/[`geom_area()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)/
[`geom_col()`](https://ggplot2.tidyverse.org/reference/geom_bar.html)/[`geom_ribbon()`](https://ggplot2.tidyverse.org/reference/geom_ribbon.html)/[`geom_density()`](https://ggplot2.tidyverse.org/reference/geom_density.html))
so plots look consistent without repeating `fill = ...` on every layer.

## Usage

``` r
theme_mt(
  base_size = 10,
  base_family = "Roboto Condensed",
  plot_title_family = base_family,
  subtitle_family = base_family,
  strip_text_family = base_family,
  axis_title_family = base_family,
  axis_text_family = base_family,
  caption_family = base_family,
  plot_title_size = base_size + 4,
  axis_text_size = base_size,
  strip_text_size = base_size + 1,
  subtitle_size = base_size + 1,
  caption_size = base_size - 2,
  axis_title_size = base_size + 1,
  legend_text_size = base_size,
  dark = FALSE,
  minor_grid = FALSE,
  background = if (dark) "transparent" else "white",
  grid_color = if (dark) .dark_grid else "gray87",
  axis_text_color = if (dark) .dark_axis_text else "gray30",
  axis_line_color = if (dark) .dark_axis_line else grid_color,
  continuous_palette = if (dark) {
     c("#13414f", dark_mt_colors[1])
 } else {
    
    c("#b7d4e0", mt_colors[1])
 }
)
```

## Arguments

- base_size:

  Base font size, in points. Every other size argument derives from it
  by default.
  [`use_theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/use_theme_mt.md)
  has the same default.

- base_family, plot_title_family, subtitle_family, strip_text_family,
  axis_title_family, axis_text_family, caption_family:

  Font families for each text element; all default to `base_family`. See
  Details for the `"Roboto Condensed"` default's system requirement.

- plot_title_size, axis_text_size, strip_text_size, subtitle_size,
  caption_size, axis_title_size, legend_text_size:

  Font sizes for each text element, all derived from `base_size` by
  default. See Details for how the scale is laid out. `legend_text_size`
  covers both `legend.text` and `legend.title`.

- dark:

  Build a dark-mode-appropriate variant instead: transparent plot/panel
  background (rather than the opaque white "paper" used in light mode),
  light text/gridline/ink colors, and
  [dark_mt_colors12](https://mkthalmann.github.io/emptyviz/reference/dark_mt_colors.md)
  in place of
  [mt_colors12](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)
  as the discrete palette and geom fill default. Meant for rendering the
  same plot a second time for a dark-themed page, alongside a
  `dark = FALSE` (default) render for the light-themed page.
  `grid_color`/`axis_text_color`/`axis_line_color`/`background`/
  `continuous_palette` still default off of `dark` but can be overridden
  individually either way.

- minor_grid:

  Whether to draw minor gridlines (on the major axis only, matching the
  major grid). `FALSE` by default. See Details.

- background:

  Fill for `plot.background` in light mode: `"white"` (the default),
  `"transparent"`, or any opaque color. A semi-transparent fill would
  tint whatever page the figure is placed on. With `dark = TRUE` the
  background is always transparent; see Details.

- grid_color:

  Color of the panel grid lines, and of the axis line unless
  `axis_line_color` says otherwise. Defaults to a near-invisible light
  gray, or a near-invisible dark gray when `dark = TRUE`.

- axis_text_color:

  Color of the axis tick labels. Defaults to a dark gray, or a light
  gray when `dark = TRUE`.

- axis_line_color:

  Color of the axis line, which is always drawn. Defaults to
  `grid_color` in light mode; in dark mode it defaults to something
  brighter than `grid_color`, since the axis line is a real boundary
  (drawn thicker than the grid) and reads as too faint at the grid's own
  brightness.

- continuous_palette:

  Colors for continuous `colour`/`fill` scales, as the two ends of a
  ramp. Defaults to a lightness ramp of `mt_colors[1]` (or of
  `dark_mt_colors[1]` when `dark = TRUE`) - a single-hue sequential
  scale in the palette's own teal, running from light (low values) to
  dark (high values). `NULL` leaves ggplot2's own default gradient.

## Value

A `ggplot2` theme object.

## Details

Call
[`use_theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/use_theme_mt.md)
to make this the session's active theme -
[`library(emptyviz)`](https://mkthalmann.github.io/emptyviz/) does not
do this automatically.

Only the title stands above the rest of the type scale, at
`base_size + 4`. Subtitle, strip text and axis titles are
`base_size + 1`, tick labels and legend text `base_size`, and the
caption `base_size - 2`. Every size is an argument.

Margins, legend keys and the gap between panel and legend are sized off
`base_size`, so they scale with the type. The plot margin is wider on
the right and top, where the right-aligned axis titles and the title
would otherwise touch the device edge.

Minor gridlines are off by default (`minor_grid`): at `linewidth = 0.1`
they are about 0.1 mm, which is where print workflows stop guaranteeing
a line, and they double the grid's ink without adding information.

`dark = TRUE` is tuned for a page background of about `#151515`. It sets
`paper = NA` and a transparent `plot.background`, deliberately - the
figure then sits directly on whatever the host page uses, which is what
makes a Quarto light/dark toggle work without re-rendering. The
consequence is that the *real* background is the host's, not this
theme's, and every contrast decision in dark mode is made against
`#151515`: the grid line at 1.19:1, the axis line at 3.14:1, the ink at
14.4:1. Nothing validates the assumption, and a host theme at, say,
`#2b2b2b` or `#1e1e2e` shifts all three - far enough that the
near-invisible grid could invert against a light-ish "dark" background.
If your site's dark background differs much from `#151515`, either match
it or pass `grid_color`/`axis_text_color`/`axis_line_color` explicitly.
`geom.paper` follows the same assumption: it is that same `#151515`, so
a
[`geom_label()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
on a dark page has an opaque background. The default colours of this
package's plot builders
([`plot_bf_forest()`](https://mkthalmann.github.io/emptyviz/reference/plot_bf_forest.md),
[`plot_ridge_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_ridge_hdi.md),
...) follow the theme as well: under a dark theme they switch from
[mt_colors12](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)
to the matching
[dark_mt_colors12](https://mkthalmann.github.io/emptyviz/reference/dark_mt_colors.md)
tints.

The discrete palette separates categories by **hue**, with very little
lightness difference between them: every pair in
[mt_colors5](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)
falls below the 3:1 WCAG 1.4.11 contrast threshold for distinguishable
graphical objects, and eight of the ten pairs below 2:1 (teal `#066b8a`
and purple `#9109d5` sit at 1.09:1 - effectively the same shade of
gray). Each color has adequate contrast against a white background, so
text and outlines are fine; the limitation is strictly
category-vs-category. Under grayscale printing, a monochrome projector,
or reduced color discrimination, categories can merge. Beyond about
three categories, give the plot a redundant non-color channel - `shape`,
`linetype`, or direct labels - rather than relying on hue alone.
[`plot_location_scale()`](https://mkthalmann.github.io/emptyviz/reference/plot_location_scale.md)
does this by default (see its `category_shape`/`category_linetype`), and
[`plot_bf_forest()`](https://mkthalmann.github.io/emptyviz/reference/plot_bf_forest.md)'s
`positive_shape`/`negative_shape` are the same idea.

[mt_colors12](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)'s
first five positions are
[mt_colors5](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md),
so plots with five or fewer categories are unaffected by the extension
to twelve. The advice above applies with more force past five
categories, not less: the worst pair sits at 1.02:1 against
[mt_colors5](https://mkthalmann.github.io/emptyviz/reference/mt_colors.md)'s
1.09:1.

`base_family` (and every other `*_family` argument, which default to it)
defaults to `"Roboto Condensed"`, a font this package does not install
or register - it must already be present on the system (and discoverable
by the graphics device in use) for text to render as intended. If it
isn't installed, most graphics devices silently substitute a fallback
font rather than erroring, so a plot can look subtly different across
machines with no warning. Install it (e.g. via a system font manager, or
`sysfonts::font_add_google("Roboto Condensed")` +
[`showtext::showtext_auto()`](https://rdrr.io/pkg/showtext/man/showtext_auto.html)
for device-independent rendering), or pass a `base_family` you know is
available, if reproducing a plot's exact appearance matters.

## Hiding elements

Native elements (lines, rectangles, plain text) are hidden the usual
way: `theme(panel.grid = element_blank())` also hides
`panel.grid.major.y`, as under ggplot2's built-in themes. The markdown
text elements are an exception. ggplot2 4 draws axis labels through the
position-specific children (`axis.text.y.left`, `axis.text.x.bottom`,
...), which this theme has to set explicitly with
[`ggtext::element_markdown()`](https://wilkelab.org/ggtext/reference/element_markdown.html),
and ggplot2 ignores `inherit.blank` for such elements.
`theme(axis.text.y = element_blank())` therefore leaves the y tick
labels drawn. Use
[`blank_elements()`](https://mkthalmann.github.io/emptyviz/reference/blank_elements.md)
instead, which blanks an element together with all of its children, or
blank the position-specific child directly. The same applies to
`strip.text` and its children, to the parent `axis.title`, and to the
secondary-axis titles (`axis.title.x.top`, `axis.title.y.right`).
Blanking `axis.title.x`, `axis.title.y`, `legend.text` or `legend.title`
directly works as usual.

## See also

[`use_theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/use_theme_mt.md),
[`blank_elements()`](https://mkthalmann.github.io/emptyviz/reference/blank_elements.md)

## Examples

``` r
library(ggplot2)
# a system-available family sidesteps the "Roboto Condensed" requirement
# described in Details, so this renders identically everywhere
ggplot(mtcars, aes(wt, mpg)) +
  geom_point() +
  theme_mt(base_family = "")
```
