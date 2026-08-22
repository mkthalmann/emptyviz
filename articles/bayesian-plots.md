# Plotting Bayesian posteriors: halfeye, location-scale, and BF forest plots

``` r

library(emptyviz)
library(ggplot2)
library(dplyr)
library(tidyr)
library(forcats)
library(patchwork)
use_theme_mt()
```

## The model behind `believe_projection_draws`

This vignette’s data comes from the distributional `brms` model
Thalmann/Matticchio fit to `believe_projection` (see
[`vignette("geoms-and-theme")`](https://mkthalmann.github.io/emptyviz/articles/geoms-and-theme.md)
for the same data’s raw-observation plots). Both the judgment mean *and*
its spread are modeled as a function of condition — the kind of model
this package’s Bayesian plot builders exist for:

``` r

# not run here - 8 chains x 10,000 iterations is well beyond what a vignette
# should fit live. The draws used below were extracted from this exact
# cached model by data-raw/believe-projection-posteriors.R; see
# ?believe_projection_draws et al. for how.
mod <- brm(
  bf(
    judgment ~ negation * scenario * trigger +
      (1 + scenario * negation * trigger | id) +
      (1 + scenario * negation | item),
    sigma ~ negation * scenario + trigger
  ),
  data = d, # the cleaned believe_projection from vignette("geoms-and-theme")
  family = gaussian(),
  prior = c(
    prior(normal(0, .5), class = Intercept, lb = -2, ub = 2),
    prior(normal(0, .5), class = Intercept, dpar = sigma),
    prior(normal(0, 1), class = b, lb = -3, ub = 3),
    prior(normal(0, .25), class = b, dpar = sigma),
    prior(normal(0, .5), class = sd)
  ),
  iter = 10000,
  chains = 8
)
```

## `plot_ridge_hdi()` / `plot_coef_grid_hdi()`

Two layout wrappers around one shared layer builder,
[`layer_halfeye_hdi()`](https://mkthalmann.github.io/emptyviz/reference/layer_halfeye_hdi.md)
(a
[`ggdist::stat_slab()`](https://mjskay.github.io/ggdist/reference/stat_slab.html) +
[`ggdist::stat_pointinterval()`](https://mjskay.github.io/ggdist/reference/stat_pointinterval.html)
“halfeye” block: an HDI-shaded density plus a multi-width ETI
point-interval per category). Both expect long-format posterior draws —
one row per draw per category, as produced by
[`tidybayes::gather_emmeans_draws()`](https://mjskay.github.io/tidybayes/reference/gather_emmeans_draws.html)
or
[`spread_draws()`](https://mjskay.github.io/tidybayes/reference/spread_draws.html)
— not raw observations, unlike the `_sd` violin geoms in
[`vignette("geoms-and-theme")`](https://mkthalmann.github.io/emptyviz/articles/geoms-and-theme.md).

- [`plot_ridge_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_ridge_hdi.md):
  every category stacked as a row in one shared-scale panel, for when
  the categories themselves are what’s being compared.
- [`plot_coef_grid_hdi()`](https://mkthalmann.github.io/emptyviz/reference/plot_coef_grid_hdi.md):
  each category gets its own free-scale panel in a grid, for coefficient
  posteriors that differ wildly in natural magnitude.

`believe_projection_draws` (see
[`?believe_projection_draws`](https://mkthalmann.github.io/emptyviz/reference/believe_projection_draws.md))
holds exactly this shape already: long-format marginal posterior draws
for `scenario`\*`negation`\*`trigger`, for both the `mu` (judgment) and
`sigma` (spread) submodels, extracted via
`emmeans() |> gather_emmeans_draws()`.

``` r

ridge_draws <- believe_projection_draws |>
  filter(dpar == "mu") |>
  mutate(cond = paste0(scenario, "-", negation))
```

### `plot_ridge_hdi()`

``` r

plot_ridge_hdi(
  ridge_draws,
  category = cond,
  facet = trigger,
  facet_nrow = 2,
  value_limits = c(-2.3, 2.3),
  value_breaks = c(-2, -1, 0, 1, 2)
)
```

![A ridgeline of posterior marginal means for the eight
scenario-by-negation conditions, faceted into a stop panel on top and an
again panel below. Each row is a density curve with a point-interval
underneath it, and rows are sorted by mean. Both panels show the same
ordering: critical-without, false-without and true-with sit around -1.5
at the low end, undef-with and undef-without cluster near -0.5 in the
middle, and critical-with, false-with and true-without run from about
0.7 up to 2. The again panel's densities are slightly narrower and its
extremes slightly further apart than the stop
panel's.](bayesian-plots_files/figure-html/ridge-basic-1.png)

### `category_reorder`

Default `TRUE` sorts rows by mean value (descending); `FALSE` keeps
`category`’s existing factor-level order instead — useful when the order
itself is meaningful (e.g. matching a fixed condition sequence elsewhere
in a paper).

``` r

p_reorder_on <- plot_ridge_hdi(
  ridge_draws |> filter(trigger == "*again*"),
  category = cond,
  value_limits = c(-2.3, 2.3)
) +
  labs(x = "Reordered (default)")

p_reorder_off <- plot_ridge_hdi(
  ridge_draws |> filter(trigger == "*again*"),
  category = cond,
  category_reorder = FALSE,
  value_limits = c(-2.3, 2.3)
) +
  labs(x = "Original factor order")

p_reorder_on + p_reorder_off
```

![The same eight posterior densities drawn twice. Left, labelled
Reordered (default): rows run monotonically from the lowest mean at the
top to the highest at the bottom, so the densities form a clean
staircase. Right, labelled Original factor order: the identical
densities in the category column's own factor order, which interleaves
high and low conditions and leaves the rows scattered across the axis
with no visual
trend.](bayesian-plots_files/figure-html/ridge-reorder-1.png)

### `value_transform`

The `sigma` submodel is fit on the log scale — pass
`value_transform = exp` to back-transform before plotting, matching an
`aes(y = exp(.value))`-style back-transformation done by hand.
`believe_projection_draws`’ `dpar == "sigma"` rows are exactly that
submodel’s marginal draws.

``` r

sigma_draws <- believe_projection_draws |>
  filter(dpar == "sigma") |>
  mutate(cond = paste0(scenario, "-", negation))

plot_ridge_hdi(
  sigma_draws |> filter(trigger == "*again*"),
  category = cond,
  value_transform = exp,
  ylab = "Posterior marginal SD ±HDI<sub>95</sub> ±ETI<sub>50;90;95</sub>"
)
```

![A ridgeline of posterior marginal standard deviations for the eight
conditions, back-transformed from the log scale with value_transform =
exp, so the axis runs in raw SD units from about 0.5 to 1.4. The three
without-negation conditions with the tightest judgments -
critical-without, true-without and false-without - sit lowest, around
0.55 to 0.7 and with narrow densities; undef-with, critical-with and
undef-without sit highest, above 1.0 and with visibly wider
densities.](bayesian-plots_files/figure-html/ridge-transform-1.png)

### `plot_coef_grid_hdi()`

Free-scale small multiples for a set of model coefficients — the real
sum-coded fixed effects from both submodels
(`believe_projection_coef_draws`, see
[`?believe_projection_coef_draws`](https://mkthalmann.github.io/emptyviz/reference/believe_projection_coef_draws.md))
differ wildly enough in natural magnitude that a shared axis would
flatten the small ones, exactly the case this layout is for.

``` r

mu_coef_draws <- believe_projection_coef_draws |> filter(dpar == "mu")
sigma_coef_draws <- believe_projection_coef_draws |> filter(dpar == "sigma")
```

``` r

plot_coef_grid_hdi(mu_coef_draws, category = coef, scale = 1.4)
```

![A four-by-four grid of small posterior density panels, one per fixed
effect of the mu submodel, each with its own free x scale and a dashed
reference line at zero. Because the axes are free, coefficients of very
different magnitude are all legible: Negation:false spans roughly 0.5 to
1.5 while Negation:stop spans only about -0.15 to 0.10. Several panels -
critical, the Intercept, Negation, Negation:critical, Negation:false and
Negation:undef - sit clearly to one side of zero with the reference line
outside or at the edge of the interval; others, such as false:stop,
critical:stop and Negation:undef:stop, straddle
it.](bayesian-plots_files/figure-html/coef-grid-basic-1.png)

The `sigma` submodel’s coefficients (fewer terms - no three-way
interaction in `sigma ~ negation*scenario + trigger`):

``` r

plot_coef_grid_hdi(sigma_coef_draws, category = coef, scale = 1.4, ncol = 3)
```

![The same free-scale grid layout for the sigma submodel's nine
coefficients, arranged three per row. Negation, Negation:critical and
undef sit well away from the dashed zero line on the positive side;
Negation:undef sits well away on the negative side; critical, false and
the Intercept sit just below zero, and Negation:false and stop straddle
it.](bayesian-plots_files/figure-html/coef-grid-sigma-1.png)

`hline` defaults to `0` (a common null-effect reference line for
coefficient grids); pass a different value or `NULL` to move or omit it.

``` r

plot_coef_grid_hdi(mu_coef_draws, category = coef, scale = 1.4, hline = NULL)
```

![The same sixteen mu-submodel coefficient panels as above with hline =
NULL, so the dashed zero reference line is gone from every panel. Each
panel's x range now covers only its own posterior, so several densities
fill the full panel width and zero is no longer marked
anywhere.](bayesian-plots_files/figure-html/coef-grid-no-hline-1.png)

## `plot_location_scale()`

A joint (posterior marginal mean) x (posterior marginal standard
deviation) plot: one point + a shaded bivariate credible ellipse per
condition, plus an optional sigma_max ceiling-effect reference curve —
`y = sqrt((x - lower)(upper - x))`, the maximum SD a bounded response
scale permits at a given mean. Lets a reader check whether a condition’s
spread is close to or far from that ceiling directly, rather than
computing it by hand for one condition at a time.

No custom `Stat` here either — the bivariate region is
[`ggplot2::stat_ellipse()`](https://ggplot2.tidyverse.org/reference/stat_ellipse.html),
already in ggplot2 core.

### Why the draws have to be paired

`data` must contain the location and scale draws already **paired** -
one row per (category\[, shape\], `.draw`), where the location value and
the scale value on that row came from the *same* posterior iteration.
That’s different from independently summarizing the two submodels
(e.g. taking
[`mean_hdi()`](https://mjskay.github.io/ggdist/reference/point_interval.html)
of each separately) - a genuine join is what lets the ellipse reflect
their *joint* uncertainty (including any correlation between a
condition’s location and scale draws) rather than two unrelated marginal
intervals mashed into a fake cross.

In a real analysis, this means calling
[`tidybayes::gather_emmeans_draws()`](https://mjskay.github.io/tidybayes/reference/gather_emmeans_draws.html)
twice - once on the location submodel, once with `dpar = "sigma"` - and
joining the results on `.draw` (plus whatever grouping columns identify
a condition):

``` r

library(brms)
library(emmeans)
library(tidybayes)

mod <- brm(
  bf(rating ~ condition, sigma ~ condition),
  family = gaussian(),
  data = my_data
)

# one row per (condition, .draw)
loc_draws <- mod |>
  emmeans(~condition) |>
  gather_emmeans_draws()

# dpar = "sigma" pulls the scale submodel instead - fit (and so returned)
# on the log scale, hence sigma_transform = exp below
sig_draws <- mod |>
  emmeans(~condition, dpar = "sigma") |>
  gather_emmeans_draws()

# the join is what pairs each location draw with the scale draw from the
# *same* posterior iteration, rather than treating them as independent
paired_draws <- inner_join(
  loc_draws, sig_draws,
  by = c("condition", ".draw"),
  suffix = c("_location", "_sigma")
)

plot_location_scale(
  paired_draws,
  category = condition,
  location = .value_location,
  sigma = .value_sigma,
  sigma_transform = exp,
  bounds = c(1, 7) # e.g. a 1-7 Likert-type response scale
)
```

`believe_projection_draws` already has both submodels’ draws stacked
long (a `dpar` column instead of two separate objects) - pivoting `dpar`
wide recovers exactly the `paired_draws` shape above. This only works
because `data-raw/believe-projection-posteriors.R` thinned `mu`/`sigma`
down to the *same* shared set of `.draw` indices rather than
independently subsampling each - the pairing
[`plot_location_scale()`](https://mkthalmann.github.io/emptyviz/reference/plot_location_scale.md)
depends on is a property of which MCMC iteration a draw came from, so
keeping mismatched indices per submodel would silently produce a fake,
unpaired cross.

``` r

loc_scale_draws <- believe_projection_draws |>
  pivot_wider(names_from = dpar, values_from = .value)
```

`ellipse_level` defaults to `c(.5, .95)` - a narrow “core” credible
ellipse nested inside a wider outer one, told apart by alpha alone
(darker/more opaque core, fainter outer band), the same multi-width idea
[`layer_halfeye_hdi()`](https://mkthalmann.github.io/emptyviz/reference/layer_halfeye_hdi.md)
uses for its point-intervals. Pass a single level
(e.g. `ellipse_level = .95`) to go back to one ellipse per condition.

``` r

plot_location_scale(
  loc_scale_draws,
  category = scenario,
  location = mu,
  sigma = sigma,
  shape = negation,
  facet = trigger,
  bounds = c(-2, 2)
)
```

![A joint location-scale plot, faceted into a stop panel and an again
panel. Posterior marginal mean runs along the x axis from -2 to 2 and
posterior marginal standard deviation up the y axis; each condition is
one point inside a darker 50 percent and a fainter 95 percent credible
ellipse. Colour distinguishes the four scenarios and marker shape the
two negation levels (circle for with, triangle for without). A dashed
arc across the top is the sigma_max ceiling curve - the largest spread
the bounded -2 to 2 response scale allows at each mean. Every condition
sits well below that arc, with the mid-scale undef and critical
conditions highest and the extreme-mean conditions such as true-without
and critical-without
lowest.](bayesian-plots_files/figure-html/location-scale-basic-1.png)

## `plot_bf_forest()` / `prepare_bf_contrasts()` / `layer_bf_evidence_scale()`

A log Bayes Factor forest plot: one row per contrast, point ± optional
SE, colored by sign, with a shaded “weak evidence” region
([`layer_bf_evidence_scale()`](https://mkthalmann.github.io/emptyviz/reference/layer_bf_evidence_scale.md),
bundled in by default) at the Jeffreys/Lee `&plusmn;log(3)`
“weak/anecdotal evidence” convention.
[`layer_bf_evidence_scale()`](https://mkthalmann.github.io/emptyviz/reference/layer_bf_evidence_scale.md)
itself is composable (like
[`layer_halfeye_hdi()`](https://mkthalmann.github.io/emptyviz/reference/layer_halfeye_hdi.md)) -
usable on its own on any plot with a log-BF-valued axis, in either
orientation.

### `pairs`: selecting contrasts without hand-parsing strings

[`bayestestR::bayesfactor_rope()`](https://easystats.github.io/bayestestR/reference/bayesfactor_parameters.html)
computes *every* pairwise contrast in a reference grid and names each
one with an auto-generated `"<left> - <right>"` string. Picking out just
the pairs you actually want to show, and giving them clean labels, is
exactly what’s error-prone about doing this by hand (position-counting
words out of the string, then a long hardcoded
`filter(left == "x" & right == "y" | ...)` chain).
[`plot_bf_forest()`](https://mkthalmann.github.io/emptyviz/reference/plot_bf_forest.md)’s
`pairs` argument takes that off your plate: give it a plain list of
`c(left, right)` pairs, in your own words, and it filters + labels +
reorders for you - and errors, naming the exact pair, if one isn’t
found, instead of the filter silently matching nothing. You don’t need
to know which order `bayesfactor_rope()`’s reference grid happened to
enumerate a given pair in either - a pair matched in the opposite order
gets relabeled *and* sign-flipped to the order you asked for,
automatically.

`believe_projection_bf` (see
[`?believe_projection_bf`](https://mkthalmann.github.io/emptyviz/reference/believe_projection_bf.md))
is real
[`bayestestR::bayesfactor_rope()`](https://easystats.github.io/bayestestR/reference/bayesfactor_parameters.html)
output — one row per pairwise contrast among the 8
`scenario`\*`negation` cells (`trigger` marginalized out, hence each raw
`contrast` string’s trailing `" NA"`), for both submodels. There’s no SE
column at all, which is the normal case for this kind of Bayes Factor
(unlike a repeated bridge-sampling estimate) and needs nothing special
to work. `bf_pairs` below picks out the 9 contrasts of interest among
the 8 cells’ pairwise combinations, as plain `c(left, right)` pairs.

``` r

mu_bf <- believe_projection_bf |> filter(dpar == "mu")

bf_pairs <- list(
  c("with undef", "without undef"),
  c("with undef", "with critical"),
  c("with true", "without true"),
  c("with false", "without false"),
  c("with critical", "without critical"),
  c("with false", "with critical"),
  c("without false", "without critical"),
  c("without true", "with false"),
  c("with true", "without false")
)
```

``` r

plot_bf_forest(mu_bf, contrast = contrast, log_bf = log_BF, pairs = bf_pairs)
```

![A log Bayes factor forest plot with nine contrast rows, sorted from
largest to smallest. The three with-versus-without contrasts for true,
critical and false sit far right at roughly 32, 27 and 25; three more
(with undef vs with critical, with false vs with critical, with true vs
without false) sit between about 4 and 8; and the last three - without
true vs with false, without false vs without critical, with undef vs
without undef - sit just left of zero at about -2 to -3, drawn as
triangles rather than circles to mark their negative sign. A narrow
shaded band around zero marks the weak-evidence region; only those three
negative contrasts come close to it, and none falls
inside.](bayesian-plots_files/figure-html/bf-forest-basic-1.png)

The trailing `" NA"` (emmeans’ placeholder for a reference-grid variable
marginalized out via e.g. `at = list(trigger = NA)`) is stripped
automatically; see
[`prepare_bf_contrasts()`](https://mkthalmann.github.io/emptyviz/reference/prepare_bf_contrasts.md) -
the function
[`plot_bf_forest()`](https://mkthalmann.github.io/emptyviz/reference/plot_bf_forest.md)
calls internally - if you want to inspect the split-and-labeled table
directly, or reuse it outside a plot.

If your data already has one clean, pre-labeled row per contrast (no
`bayestestR`-style string to split), just omit `pairs` and pass that
column straight to `contrast`.

### `direction_labels`

Naming what a positive/negative log-BF supports turns the plot into a
self-contained legend for the sign convention, instead of requiring the
reader to already know which direction means what. The arrows and labels
sit right at the top edge of the panel, out of the way of the data,
adding essentially no extra space to the figure.

``` r

plot_bf_forest(
  mu_bf,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs,
  direction_labels = c("supports difference", "supports equivalence")
)
```

![The same nine-contrast forest plot with direction_labels turned on.
Two arrows now run along the top edge of the panel, one pointing left
labelled supports equivalence and one pointing right labelled supports
difference, each in the colour used for that sign's points. The x range
widens to about -40 to 40 to make room, and the data itself is
unchanged.](bayesian-plots_files/figure-html/bf-forest-arrows-1.png)

### `secondary_axis`

A dual log/linear Bayes Factor axis - opt-in, since a log-only axis is
perfectly fine on its own.

``` r

plot_bf_forest(
  mu_bf,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs,
  direction_labels = c("supports difference", "supports equivalence"),
  secondary_axis = TRUE
)
```

![The same forest plot with secondary_axis = TRUE. A second axis
labelled Bayes factor (BF) runs along the top, giving the linear BF
values 1, 2, 5, 15, 50 and 150 at their log positions - which bunches
them together just right of zero, since the log axis reaches past 30.
The primary log Bayes factor axis, the direction arrows and the data are
otherwise
unchanged.](bayesian-plots_files/figure-html/bf-forest-secaxis-1.png)

### `layer_bf_evidence_scale(orientation = "y")`

The same annotation bundle on a continuous-x sweep (e.g. log-BF as a
function of a prior’s width), with log-BF on the *y*-axis instead - the
rect, arrows, and labels all rotate to hug the right edge of the panel
instead of the top.

``` r

sweep_data <- data.frame(
  prior_sd = seq(0.1, 1.5, by = 0.2),
  log_bf = c(6.2, 5.1, 3.8, 2.5, 1.4, 0.3, -0.6, -1.5)
)

ggplot(sweep_data, aes(x = prior_sd, y = log_bf)) +
  layer_bf_evidence_scale(
    orientation = "y",
    range = c(-3, 8),
    direction_labels = c("supports difference", "supports equivalence")
  ) +
  geom_line(color = mt_colors[1]) +
  geom_point(color = mt_colors[1], size = 3) +
  labs(x = "Prior standard deviation", y = "log Bayes factor") +
  # unlike orientation = "x"'s top edge, the default right-side expansion
  # isn't quite wide enough for orientation = "y"'s rotated label + arrow -
  # this is the caller's own coord/margin choice, not something
  # layer_bf_evidence_scale() should impose on every plot itself.
  coord_cartesian(clip = "off") +
  theme(plot.margin = margin(5.5, 55, 5.5, 5.5, "pt"))
```

![A line-and-point plot of log Bayes factor against prior standard
deviation, showing a smooth monotonic decline from about 6.2 at a prior
SD of 0.1 to about -1.5 at 1.5. The same evidence-scale annotation is
rotated for a y-axis log-BF: the shaded weak-evidence band is now a
horizontal stripe around zero that the curve crosses at a prior SD of
roughly 1.0, and the two direction arrows hug the right edge of the
panel, pointing up for supports difference and down for supports
equivalence.](bayesian-plots_files/figure-html/bf-evidence-scale-y-1.png)
