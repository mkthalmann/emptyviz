# Split a bayestestR-style contrast string into left/right columns

Splits
[`bayestestR::bayesfactor_rope()`](https://easystats.github.io/bayestestR/reference/bayesfactor_parameters.html)'s
auto-generated `contrast` column (format: `"<left> - <right>"`, reliably
delimited by `" - "` regardless of how many crossed factors make up each
side) into separate `.left`/`.right` columns, and optionally filters +
reorders down to just the pairs the caller actually wants to show.

## Usage

``` r
prepare_bf_contrasts(
  data,
  contrast = contrast,
  value = NULL,
  strip = " NA$",
  pairs = NULL
)
```

## Arguments

- data:

  `bayesfactor_rope()` output coerced to a data frame (or any data frame
  with a `contrast` column in that `"<left> - <right>"` format).

- contrast:

  Unquoted column holding that raw string (default `contrast`, matching
  bayestestR's own column name).

- value:

  Optional column(s) to negate on any row matched via a swapped pair
  (see `pairs`), so that a positive value still favours the caller's
  first-named condition. Takes a bare column name or a tidyselect
  selection such as `c(estimate, log_BF)`. Select only columns whose
  sign depends on the direction of the contrast: an estimated
  difference, or the log Bayes factor of an order-restricted test (H1: A
  \> B against H2: A \< B). Do *not* select the log Bayes factor of a
  ROPE test
  ([`bayestestR::bayesfactor_rope()`](https://easystats.github.io/bayestestR/reference/bayesfactor_parameters.html))
  or of a two-sided point null: their hypotheses are symmetric in the
  two conditions, so reversing the contrast leaves the Bayes factor
  unchanged. A ratio-scale Bayes factor is inverted, not negated, by a
  reversal; take its [`log()`](https://rdrr.io/r/base/Log.html) first.
  Interval bounds need swapping as well as negating, so negating them
  here would produce a reversed interval. Columns not selected keep
  their values. `NULL` (default) selects nothing.

- strip:

  A regular expression removed from each side after splitting (default
  `" NA$"`, since a reference grid that marginalizes over a grouping
  variable leaves a literal trailing "NA" token in emmeans' generated
  label). `NULL` disables this.

- pairs:

  Optional list of `c(left, right)` character pairs (matched, after
  trimming whitespace, against the split `.left`/`.right` columns). When
  given: keeps only matching rows, *in the order `pairs` lists them*,
  and errors - naming exactly which pair - if any requested pair isn't
  found. `NULL` (default) keeps every row, unfiltered and in `data`'s
  own order.

  A pair's order does NOT have to match bayestestR's own
  `"<left> - <right>"` order for that contrast - a pair that only
  matches once `.left`/`.right` are swapped is accepted the same as a
  direct match; `.left`/`.right`/`.contrast_label` are then set to the
  *requested* order regardless of which way `data` actually had it, and
  the columns selected by `value` are negated.

  Two entries can therefore resolve to the *same* row of `data` - either
  as an outright repeat, or as the two directions of one contrast
  (`c("a", "b")` and `c("b", "a")`, the second relabeled, with its
  `value` columns negated). Both are allowed and warn: each becomes its
  own output row, so a forest plot built from the result shows one
  estimate as several, which reads as several independent ones. Drop the
  duplicate if that wasn't the intent.

## Value

`data`, with `.left`, `.right`, and `.contrast_label` columns added
(and, if `pairs` was given, filtered/reordered/relabeled to match).

## Examples

``` r
bf <- data.frame(
  contrast = c("a - b NA", "c - d NA"),
  estimate = c(0.9, -0.2),
  log_BF = c(1.2, -0.3)
)
prepare_bf_contrasts(bf)
#>   contrast estimate log_BF .left .right .contrast_label
#> 1 a - b NA      0.9    1.2     a      b         a vs. b
#> 2 c - d NA     -0.2   -0.3     c      d         c vs. d
# "b vs. a" matches "a - b" reversed: the estimated difference is negated,
# the ROPE log Bayes factor is not
prepare_bf_contrasts(bf, value = estimate, pairs = list(c("b", "a")))
#>   contrast estimate log_BF .left .right .contrast_label
#> 1 a - b NA     -0.9    1.2     b      a         b vs. a
```
