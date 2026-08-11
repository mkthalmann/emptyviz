# Raw judgment data from Thalmann & Matticchio (2024)

Truth-value judgment data from the `believe-projection` experiment on
whether presuppositions triggered under attitude predicates like
*believe* project universally. One row per trial. Restricted to
`sub_exp == "1"` (the main judgment task; training and filler trials
excluded) reproduces the 1,577-row dataset the model behind
[believe_projection_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_draws.md)
was fit on, via `dplyr::filter(believe_projection, sub_exp == "1")`.

## Usage

``` r
believe_projection
```

## Format

A tibble with 2,179 rows and 16 variables:

- id:

  Anonymized participant code, `"p01"`-`"p34"`.

- age:

  Participant age in years.

- gender:

  Participant gender (self-reported, German response options).

- group:

  Latin-square list assignment (`"training"` or `"a"`-`"h"`).

- sub_exp:

  Sub-experiment: `"training"`, `"1"` (the analyzed judgment task), or
  `"world"` (a separate world-knowledge norming task).

- item:

  Item number within `group`.

- cond:

  Item condition code within the Latin square.

- trigger:

  Presupposition trigger: `"again"` or `"stop"` (`"none"` for training
  items).

- negation:

  Whether the attitude predicate was negated: `"pos"` or `"neg"`
  (`"training"` for training items).

- scenario:

  Discourse scenario relative to the presupposition: `"true"`,
  `"false"`, `"undef"`, or `"critical"` (mixed case for training items).

- item_text:

  The target sentence, in German.

- item_context:

  The preceding context sentence, in German.

- item_image:

  Identifier for the accompanying scenario image.

- judgment:

  Truth-value judgment on a continuous 0-100 slider.

- submit_time:

  Response time in seconds.

- which:

  Self-reported languages understood during the debrief.

## Source

Thalmann, Maik & Matticchio, Andrea (2024). On Being Certain that
Presuppositions don't Project Universally. *Proceedings of the Amsterdam
Colloquium*, 378-385.
<https://platform.openjournals.nl/PAC/article/view/21865>. Prepared by
`data-raw/believe-projection.R`.

## Details

Anonymized before shipping: `payment_code` (participants' real payment
identifiers), `handed`, `lang`, `study`, and `caff` are dropped
entirely, and `id` (originally an MD5 hash of the participant's IP
address) has been replaced with a fresh `"p01"`-`"p34"` code assigned
via a random permutation, unlinkable to the original hash or enrollment
order.

## See also

[believe_projection_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_draws.md),
[believe_projection_coef_draws](https://mkthalmann.github.io/emptyviz/reference/believe_projection_coef_draws.md),
[believe_projection_bf](https://mkthalmann.github.io/emptyviz/reference/believe_projection_bf.md),
[`vignette("geoms-and-theme")`](https://mkthalmann.github.io/emptyviz/articles/geoms-and-theme.md),
[`vignette("bayesian-plots")`](https://mkthalmann.github.io/emptyviz/articles/bayesian-plots.md).
