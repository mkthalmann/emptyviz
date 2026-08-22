# theme_mt() and the SD-band violin geoms

``` r

library(emptyviz)
library(ggplot2)
library(dplyr)
library(forcats)
library(gghalves)
library(patchwork)
use_theme_mt()
```

## `believe_projection`

The demos below use `believe_projection`, truth-value judgment data from
Thalmann & Matticchio (2024) — a sentence-picture verification task
testing whether presuppositions triggered by *again*/*stop* under a
negated belief predicate (“Peter isn’t certain that Sonja stopped
smoking”) project universally or only relative to the attitude holder.
[`?believe_projection`](https://mkthalmann.github.io/emptyviz/reference/believe_projection.md)
has the full column reference; see
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md)
for the actual distributional model fit to this data.

`sub_exp == "1"` restricts to the main judgment task (dropping training
and a separate world-knowledge norming block); the same three recodes
`believe-projection/scripts/belproj-paper.R` applies before modeling —
rescaling the 0-100 slider to a signed -2/+2 scale, expanding the
abbreviated `"undef"` scenario label, and markdown-italicizing `trigger`
so it renders nicely via
[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)’s
markdown-aware axis text — are exactly what’s reused below and, later,
in
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md).

``` r

d <- believe_projection |>
  filter(sub_exp == "1") |>
  mutate(
    judgment = (judgment - 50) / 25,
    scenario = gsub("undef", "undefined", scenario),
    scenario = factor(scenario, levels = c("true", "false", "undefined", "critical")),
    negation = factor(negation, levels = c("pos", "neg")),
    negation = fct_recode(negation, without = "pos", with = "neg"),
    trigger = paste0("*", trigger, "*"),
    trigger = factor(trigger, levels = c("*again*", "*stop*"))
  )
```

## `theme_mt()`

Extends
[`theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html)
with markdown/HTML-aware text (via `ggtext`), a bottom legend, and an
automatic discrete color palette. Same data/labels below, only the theme
differs:
[`theme_gray()`](https://ggplot2.tidyverse.org/reference/ggtheme.html),
[`theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html),
[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md).

``` r

# theme_mt()'s discrete palette and geom_text() font default are both
# theme-level settings that resolve once, from whichever theme is active
# when the plot's scale/geom defaults are first constructed - not from
# whatever theme ends up attached via `+ theme_X()` afterward. Since this
# vignette's global default is theme_mt() (set by use_theme_mt() above),
# the gray/minimal panels need an explicit scale_fill_hue()/family = "sans"
# to force ggplot2's real defaults instead of silently inheriting
# theme_mt()'s.
theme_compare_data <- data.frame(
  condition = c("Baseline", "Weak Trigger", "Strong Trigger", "Control"),
  mean_rating = c(6.1, 4.8, 2.3, 6.5),
  se = c(0.15, 0.22, 0.28, 0.12)
)
theme_compare_data$condition <- factor(
  theme_compare_data$condition,
  levels = theme_compare_data$condition
)

build_theme_compare_plot <- function() {
  ggplot(theme_compare_data, aes(x = condition, y = mean_rating, fill = condition, color = condition)) +
    geom_col(alpha = .3) +
    geom_errorbar(aes(ymin = mean_rating - se, ymax = mean_rating + se), width = 0.2) +
    labs(
      title = "Acceptability ratings by condition",
      subtitle = "synthetic **data**, *n* = 45 per condition",
      x = "Condition", y = "Mean rating &plusmn;1 SE (1&ndash;7)",
      caption = "Test caption"
    ) +
    guides(fill = "none", color = "none")
}

value_label <- function(...) {
  geom_text(
    aes(label = sprintf("%.1f", mean_rating)),
    vjust = -1.8, color = "black", size = 5,
    ...
  )
}

p_theme_gray <- build_theme_compare_plot() + theme_gray() + scale_fill_hue() + value_label(family = "sans")
p_theme_minimal <- build_theme_compare_plot() + theme_minimal() + scale_fill_hue() + value_label(family = "sans")
p_theme_mt <- build_theme_compare_plot() + theme_mt(base_size = 12) + value_label()

p_theme_gray + p_theme_minimal + p_theme_mt
```

![The same bar chart drawn three times side by side, under theme_gray(),
theme_minimal() and theme_mt(). Each panel shows mean acceptability
ratings for four conditions - Baseline 6.1, Weak Trigger 4.8, Strong
Trigger 2.3, Control 6.5 - with a small standard-error bar and the value
printed above each bar. Only the theme_mt() panel renders the markdown
and HTML entities in its title, subtitle and axis titles; the other two
show the literal markup (&plusmn;, &ndash; and asterisks) as text.
theme_mt() also drops the grey panel background, bolds the title, keeps
only horizontal gridlines, and uses the package palette instead of
ggplot2's default
hues.](geoms-and-theme_files/figure-html/theme-compare-1.png)

## `geom_violin_sd()` / `geom_half_violin_sd()`

Compound layers built on
[`geom_violin()`](https://ggplot2.tidyverse.org/reference/geom_violin.html)/[`gghalves::geom_half_violin()`](https://rdrr.io/pkg/gghalves/man/geom_half_violin.html):
a low-alpha “aura” (full density) plus a solid mean ± 1 SD band on top.

Real truth-value judgments by `scenario` (collapsed across `negation`/
`trigger`) — floor/ceiling-heavy and asymmetric in a way
[`rnorm()`](https://rdrr.io/r/stats/Normal.html) samples never quite
are, which is exactly the case the “aura + SD-band” split is meant to
make legible.

``` r

demo_data <- d |> transmute(group = scenario, value = judgment)

violin_plain <- ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_violin() +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

violin_sd <- ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_violin_sd() +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

half_violin_plain <- ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_half_violin(side = "r") +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

half_violin_sd <- ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_half_violin_sd(side = "r") +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

(violin_plain + violin_sd) / (half_violin_plain + half_violin_sd)
```

![A two-by-two grid of violin plots of truth-value judgments, on a -2 to
+2 scale, for the four scenarios true, false, undefined and critical.
The top row shows full violins, the bottom row right-side half violins;
the left column is the plain geom (geom_violin() and
gghalves::geom_half_violin()), the right column this package's SD-band
version. Every distribution is floor- and ceiling-heavy: mass piled at
both ends of the scale with a narrow waist between. The plain violins
render that as one flat silhouette, while the \_sd versions overlay a
solid, outlined mean plus-or-minus-one-SD band on a pale full-density
aura, so how much of each scenario's spread falls inside one SD is
readable
directly.](geoms-and-theme_files/figure-html/violin-sd-comparison-1.png)

### `style = "both"` / `"fill"` / `"outline"`

The SD band can be a solid fill, an outline, or both (default) — shared
by all three `_sd` geoms.

``` r

style_both <- ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_violin_sd(style = "both") +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

style_fill <- ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_violin_sd(style = "fill") +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

style_outline <- ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_violin_sd(style = "outline") +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

style_both + style_fill + style_outline
```

![The same four scenario violins drawn three times to compare the style
argument. Left, style = both (the default): the SD band is a solid fill
with an outline around it. Middle, style = fill: the same solid band
with no outline. Right, style = outline: only the outlined band, with
the pale full-density aura showing through where the fill used to be.
The underlying distributions are identical across all
three.](geoms-and-theme_files/figure-html/violin-sd-style-1.png)

## `geom_split_violin_sd()`

Two
[`geom_half_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_half_violin_sd.md)
halves back-to-back, one per level of `split` — no manual filtering or
`side = "l"`/`"r"` calls needed.

``` r

balanced_data <- d |> filter(trigger == "*again*")
split_mapping <- aes(x = scenario, y = judgment)
```

### Balanced

``` r

ggplot(balanced_data, split_mapping) +
  geom_split_violin_sd(split_mapping, data = balanced_data, split = negation) +
  labs(x = NULL, y = "Judgment (rescaled -2/+2)")
```

![Back-to-back split violins of judgments, on a -2 to +2 scale, for the
four scenarios. At each scenario the teal half for negation = without is
drawn on the left and the crimson half for negation = with on the right.
For true, the without half piles up at the top of the scale and the with
half at the bottom; false reverses that; undefined puts both halves near
the floor with a long tail upward; critical has without at the floor and
with spread much
higher.](geoms-and-theme_files/figure-html/split-violin-balanced-1.png)

### `flip = TRUE`

Same data, sides swapped.

``` r

ggplot(balanced_data, split_mapping) +
  geom_split_violin_sd(split_mapping, data = balanced_data, split = negation, flip = TRUE) +
  labs(x = NULL, y = "Judgment (rescaled -2/+2)")
```

![The same split violins as the previous figure with flip = TRUE, so
each scenario's with half is now drawn on the left and its without half
on the right. Every shape is mirrored across its scenario's centre line;
the distributions themselves are unchanged, and the legend order swaps
to match.](geoms-and-theme_files/figure-html/split-violin-flip-1.png)

### Missing cell

Dropping `critical`/`with` entirely warns, not errors, and still renders
a lone half-violin.

``` r

missing_data <- balanced_data |>
  filter(!(scenario == "critical" & negation == "with"))

ggplot(missing_data, split_mapping) +
  geom_split_violin_sd(split_mapping, data = missing_data, split = negation) +
  labs(x = NULL, y = "Judgment (rescaled -2/+2)")
#> Warning: geom_split_violin_sd(): thin or one-sided x-levels - critical (missing
#> one side entirely)
```

![The same split violins with the critical/with cell dropped from the
data. The first three scenarios are unchanged. Critical now renders as a
lone left-side half violin - the teal without half, its mass at the
floor of the scale - with nothing drawn on the right, rather than the
whole x position
failing.](geoms-and-theme_files/figure-html/split-violin-missing-1.png)

### `scale = "count"` vs. `"area"`

`scale` only normalizes a side against itself, not against the other
side —
[`geom_split_violin_sd()`](https://mkthalmann.github.io/emptyviz/reference/geom_split_violin_sd.md)’s
two sides are separate `Stat` computations, so `scale` can only compare
an x-level against *its own side’s* other x-levels, never against the
other side’s counts. The real cells above are all ~100 trials, so the
effect needs an example: subsampling `with` down across `scenario`
(holding `without` fixed) engineers the imbalance while keeping every
plotted judgment a real trial, rather than fabricating ratings —
`"count"` (left, default) lets the shrinking `with` N narrow that side’s
violin; `"area"` (right) hides it entirely.

``` r

set.seed(42)
with_fracs <- c(true = 1, false = .7, undefined = .45, critical = .25)
unbalanced_data <- bind_rows(
  balanced_data |> filter(negation == "without"),
  balanced_data |>
    filter(negation == "with") |>
    group_by(scenario) |>
    group_modify(~ slice_sample(.x, prop = with_fracs[[as.character(.y$scenario)]])) |>
    ungroup()
)

p_scale_count <- ggplot(unbalanced_data, split_mapping) +
  geom_split_violin_sd(split_mapping, data = unbalanced_data, split = negation) +
  labs(x = NULL, y = "Judgment (rescaled -2/+2)")

p_scale_area <- ggplot(unbalanced_data, split_mapping) +
  geom_split_violin_sd(
    split_mapping,
    data = unbalanced_data, split = negation, scale = "area"
  ) +
  labs(x = NULL, y = NULL) +
  guides(fill = "none")

p_scale_count + p_scale_area
```

![Two panels of the same back-to-back split violins, with the with side
subsampled to progressively smaller fractions across scenarios (all of
true, then 70, 45 and 25 percent for false, undefined and critical).
Left, scale = count (the default): each half's width is proportional to
its own side's counts, so the shrinking with side narrows across the
panel. Right, scale = area: every half is normalised to the same area,
so the widths no longer carry that sample-size information at
all.](geoms-and-theme_files/figure-html/split-violin-scale-1.png)
