
# emptyviz

A `ggplot2` theme (`theme_mt()`) plus a set of composable geoms and plot
builders used across the author’s experimental projects: mean ± 1 SD
violin/half-violin/split-violin geoms for raw observations, and
`ggdist`-based halfeye/ridge/coefficient-grid, location-scale, and log
Bayes Factor forest plot builders for posterior draws from Bayesian
models (typically fit with `brms`).

This package is not intended for general audiences - it’s published so
that the specific analyses that depend on it are reproducible by anyone
who installs the tagged version they were built with.

## Installation

``` r
# install.packages("pak")
pak::pak("mkthalmann/emptyviz")
```

To pin the exact version a given analysis was built with (recommended
for reproducing a specific plot), install a tag or commit instead of the
default branch:

``` r
pak::pak("mkthalmann/emptyviz@v0.1.0")
```

## Usage

``` r
library(emptyviz)
library(ggplot2)

# Sets theme_mt() as the active ggplot2 theme, and geom_density()'s default
# adjust to 5 - not automatic on library(emptyviz), unlike the old
# source("theme.R") workflow this package replaces.
use_theme_mt()
```

``` r
set.seed(42)
demo_data <- rbind(
  data.frame(group = "A", value = rnorm(80, 0, 1)),
  data.frame(group = "B", value = rnorm(80, 1.5, 0.6)),
  data.frame(group = "C", value = rnorm(80, -0.5, 1.8))
)

ggplot(demo_data, aes(x = group, y = value, fill = group)) +
  geom_violin_sd() +
  labs(
    title = "geom_violin_sd()",
    subtitle = "aura (full density) + mean &plusmn;1 SD band",
    x = NULL, y = NULL
  ) +
  guides(fill = "none")
```

<img src="man/figures/README-violin-example-1.png" alt="" width="100%" />

``` r
bf_data <- data.frame(
  contrast = c("A vs. B", "C vs. D", "E vs. F"),
  log_bf = c(8.2, 1.1, -0.4)
)

plot_bf_forest(
  bf_data,
  contrast = contrast,
  log_bf = log_bf,
  direction_labels = c("supports difference", "supports equivalence")
)
```

<img src="man/figures/README-bf-example-1.png" alt="" width="100%" />

See `vignette("geoms-and-theme")` for the theme and the three `_sd`
violin geoms, and `vignette("bayesian-plots")` for the
halfeye/ridge/coefficient-grid, location-scale, and Bayes Factor forest
plot builders.

## Development

``` r
devtools::load_all()
devtools::test()
devtools::check()
```
