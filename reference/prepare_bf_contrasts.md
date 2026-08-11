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

  Optional unquoted column - typically the log-BF/BF column itself - to
  sign-flip on any row matched via a swapped pair (see `pairs`), so a
  positive value still means whatever the caller's first-named condition
  supports. `NULL` (default) leaves every column as-is; if any pair
  needed swapping and no `value` is given, a warning names how many rows
  were affected.

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
  *requested* order regardless of which way `data` actually had it.

## Value

`data`, with `.left`, `.right`, and `.contrast_label` columns added
(and, if `pairs` was given, filtered/reordered/relabeled to match).

## Examples

``` r
bf <- data.frame(
  contrast = c("a - b NA", "c - d NA", "b - a NA"),
  log_BF = c(1.2, -0.3, 0.8)
)
prepare_bf_contrasts(bf)
#>   contrast log_BF .left .right .contrast_label
#> 1 a - b NA    1.2     a      b         a vs. b
#> 2 c - d NA   -0.3     c      d         c vs. d
#> 3 b - a NA    0.8     b      a         b vs. a
prepare_bf_contrasts(bf, value = log_BF, pairs = list(c("a", "b")))
#>   contrast log_BF .left .right .contrast_label
#> 1 a - b NA    1.2     a      b         a vs. b
```
