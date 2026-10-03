# Log Bayes Factor forest plot

One row per contrast, point (+/- optional SE), colored by sign, with
[`layer_bf_evidence_scale()`](https://mkthalmann.github.io/emptyviz/reference/layer_bf_evidence_scale.md)'s
weak-evidence-region annotation bundled in by default.

## Usage

``` r
plot_bf_forest(
  data,
  contrast,
  log_bf,
  se = NULL,
  pairs = NULL,
  negate_reversed = FALSE,
  contrast_strip = " NA$",
  contrast_reorder = TRUE,
  positive_color = NULL,
  negative_color = NULL,
  positive_shape = 16,
  negative_shape = 17,
  point_size = 3,
  evidence_scale = TRUE,
  weak_threshold = log(3),
  weak_label = "Weak evidence region",
  direction_labels = NULL,
  arrow_range = NULL,
  secondary_axis = FALSE,
  secondary_breaks = c(1, 2, 5, 15, 50, 150),
  xlab = NULL,
  ylab = "Contrast"
)
```

## Arguments

- data:

  A data frame with one row per contrast.

- contrast:

  Unquoted column with the contrast label. If `pairs` is given, this is
  treated as bayestestR's raw `"<left> - <right>"` string and run
  through
  [`prepare_bf_contrasts()`](https://mkthalmann.github.io/emptyviz/reference/prepare_bf_contrasts.md)
  first; otherwise used directly as the display label, unchanged.

- log_bf:

  Unquoted column of log Bayes Factors.

- se:

  Optional unquoted column of standard errors (`NULL` omits the
  errorbar - a Bayes Factor from a single `bayesfactor_rope()` call,
  unlike a repeated bridge-sampling estimate, has no natural
  per-contrast SE at all, and that's a fully supported, first-class case
  here, not a fallback).

- pairs:

  Optional list of `c(left, right)` pairs; see
  [`prepare_bf_contrasts()`](https://mkthalmann.github.io/emptyviz/reference/prepare_bf_contrasts.md).
  A pair matched in reversed order is relabeled to the requested order;
  whether its `log_bf` changes sign is set by `negate_reversed`.

- negate_reversed:

  Whether `log_bf` is negated for a pair that `pairs` matches in
  reversed order. `FALSE` (default) is correct for Bayes factors whose
  hypotheses are symmetric in the two conditions, such as a ROPE test
  ([`bayestestR::bayesfactor_rope()`](https://easystats.github.io/bayestestR/reference/bayesfactor_parameters.html))
  or a two-sided point null: reversing the contrast does not change
  them. Set `TRUE` only when reversing the contrast swaps the two
  hypotheses, as for an order-restricted test of H1: A \> B against H2:
  A \< B.

- contrast_strip:

  Passed to
  [`prepare_bf_contrasts()`](https://mkthalmann.github.io/emptyviz/reference/prepare_bf_contrasts.md)'s
  `strip` when `pairs` is given.

- contrast_reorder:

  `TRUE` (default) sorts rows by `log_bf`; `FALSE` keeps `pairs`' own
  order (or `data`'s own order, if `pairs` wasn't used).

- positive_color, negative_color:

  Colors for positive/negative contrasts. `NULL` (default) uses
  `mt_colors[1]`/`mt_colors[2]`, or
  `dark_mt_colors[1]`/`dark_mt_colors[2]` under a dark theme such as
  `theme_mt(dark = TRUE)`.

- positive_shape, negative_shape:

  Point shapes for positive/negative contrasts. Color and shape both
  carry sign, redundantly, so direction stays legible under grayscale
  printing or for red/green-blind readers.

- point_size:

  Size of the contrast points.

- evidence_scale:

  `TRUE` (default) bundles
  [`layer_bf_evidence_scale()`](https://mkthalmann.github.io/emptyviz/reference/layer_bf_evidence_scale.md)
  in automatically, with `arrow_range` computed from `data` itself;
  `FALSE` for a bare forest plot with no annotation.

- weak_threshold, weak_label:

  Passed to
  [`layer_bf_evidence_scale()`](https://mkthalmann.github.io/emptyviz/reference/layer_bf_evidence_scale.md)
  when `evidence_scale = TRUE`.

- direction_labels, secondary_axis, secondary_breaks:

  Passed through to
  [`layer_bf_evidence_scale()`](https://mkthalmann.github.io/emptyviz/reference/layer_bf_evidence_scale.md)
  when `evidence_scale = TRUE`.

- arrow_range:

  `c(min, max)` the direction arrows span, with `min < 0 < max`; only
  used when `direction_labels` is given. `NULL` (default) makes the
  range symmetric around zero, reaching 15% past the largest absolute
  log Bayes factor (or `weak_threshold`, whichever is larger). Pass an
  asymmetric range when the log Bayes factors lie mostly on one side of
  zero, so that the arrows do not widen the axis on the other.

- xlab, ylab:

  Axis labels.

## Value

A `ggplot` object.

## Examples

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
