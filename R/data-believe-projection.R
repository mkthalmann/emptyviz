#' Raw judgment data from Thalmann & Matticchio (2024)
#'
#' Truth-value judgment data from the `believe-projection` experiment on
#' whether presuppositions triggered under attitude predicates like *believe*
#' project universally. One row per trial. Restricted to `sub_exp == "1"`
#' (the main judgment task; training and filler trials excluded) reproduces
#' the 1,577-row dataset the model behind [believe_projection_draws] was fit
#' on, via `dplyr::filter(believe_projection, sub_exp == "1")`.
#'
#' Anonymized before shipping: `payment_code` (participants' real payment
#' identifiers), `handed`, `lang`, `study`, and `caff` are dropped entirely,
#' and `id` (originally an MD5 hash of the participant's IP address) has
#' been replaced with a fresh `"p01"`-`"p34"` code assigned via a random
#' permutation, unlinkable to the original hash or enrollment order.
#'
#' @format A tibble with 2,179 rows and 16 variables:
#' \describe{
#'   \item{id}{Anonymized participant code, `"p01"`-`"p34"`.}
#'   \item{age}{Participant age in years.}
#'   \item{gender}{Participant gender (self-reported, German response
#'     options).}
#'   \item{group}{Latin-square list assignment (`"training"` or `"a"`-`"h"`).}
#'   \item{sub_exp}{Sub-experiment: `"training"`, `"1"` (the analyzed
#'     judgment task), or `"world"` (a separate world-knowledge norming
#'     task).}
#'   \item{item}{Item number within `group`.}
#'   \item{cond}{Item condition code within the Latin square.}
#'   \item{trigger}{Presupposition trigger: `"again"` or `"stop"` (`"none"`
#'     for training items).}
#'   \item{negation}{Whether the attitude predicate was negated: `"pos"` or
#'     `"neg"` (`"training"` for training items).}
#'   \item{scenario}{Discourse scenario relative to the presupposition:
#'     `"true"`, `"false"`, `"undef"`, or `"critical"` (mixed case for
#'     training items).}
#'   \item{item_text}{The target sentence, in German.}
#'   \item{item_context}{The preceding context sentence, in German.}
#'   \item{item_image}{Identifier for the accompanying scenario image.}
#'   \item{judgment}{Truth-value judgment on a continuous 0-100 slider.}
#'   \item{submit_time}{Response time in seconds.}
#'   \item{which}{Self-reported languages understood during the debrief.}
#' }
#' @source Thalmann, Maik & Matticchio, Andrea (2024). On Being Certain that
#'   Presuppositions don't Project Universally. *Proceedings of the
#'   Amsterdam Colloquium*, 378-385.
#'   <https://platform.openjournals.nl/PAC/article/view/21865>. Prepared by
#'   `data-raw/believe-projection.R`.
#' @seealso [believe_projection_draws], [believe_projection_coef_draws],
#'   [believe_projection_bf], `vignette("geoms-and-theme")`,
#'   `vignette("bayesian-plots")`.
"believe_projection"

#' Posterior marginal draws from the believe-projection model
#'
#' Long-format posterior draws from the distributional `brms` model fit to
#' [believe_projection] (`judgment ~ negation*scenario*trigger`,
#' `sigma ~ negation*scenario + trigger`), one row per posterior draw per
#' `scenario` x `negation` x `trigger` cell x submodel. Extracted via
#' `emmeans(mod, ~scenario*negation*trigger)` (and again with
#' `dpar = "sigma"`) piped through `tidybayes::gather_emmeans_draws()`, then
#' thinned to 2,000 draws per cell per submodel - see
#' `data-raw/believe-projection-posteriors.R`.
#'
#' `dpar == "sigma"` draws are on the log scale (the model's own link
#' function for that submodel); back-transform with `exp()` before plotting,
#' e.g. via `plot_ridge_hdi()`'s `value_transform = exp`.
#'
#' Pivoting `dpar` wide and joining on `.draw` (plus the condition columns)
#' recovers the *paired* location/scale draws [plot_location_scale()]
#' requires - the same pairing `vignette("bayesian-plots")` builds by hand.
#'
#' @format A tibble with 64,000 rows and 6 variables:
#' \describe{
#'   \item{scenario}{`"true"`, `"false"`, `"undef"`, or `"critical"`.}
#'   \item{negation}{`"with"` or `"without"`.}
#'   \item{trigger}{`"*again*"` or `"*stop*"` (markdown-italicized).}
#'   \item{dpar}{`"mu"` (the judgment submodel) or `"sigma"` (the
#'     distributional scale submodel, log scale).}
#'   \item{.draw}{Posterior draw index.}
#'   \item{.value}{The draw's value.}
#' }
#' @source See [believe_projection]. Model fit in
#'   `believe-projection/scripts/belproj-paper.R`; draws extracted by
#'   `data-raw/believe-projection-posteriors.R`.
#' @seealso [believe_projection], [believe_projection_coef_draws],
#'   [believe_projection_bf], `vignette("bayesian-plots")`.
"believe_projection_draws"

#' Posterior fixed-effect coefficient draws from the believe-projection model
#'
#' Long-format posterior draws for the same model's named (sum-coded)
#' fixed-effect coefficients, one row per posterior draw per coefficient per
#' submodel. Extracted via `tidybayes::spread_draws()` on the model's `b_*`
#' parameters, pivoted long, then thinned to 2,000 draws per coefficient per
#' submodel - see `data-raw/believe-projection-posteriors.R`.
#'
#' Coefficient labels are markdown-formatted (e.g. `"Negation<sub>GM</sub>"`,
#' `"false<sub>GM</sub>"` for a level-vs-grand-mean sum-coding contrast),
#' ready for `plot_coef_grid_hdi()`'s markdown-aware facet strips.
#'
#' @format A tibble with 50,000 rows and 4 variables:
#' \describe{
#'   \item{dpar}{`"mu"` (16 coefficients) or `"sigma"` (9 coefficients).}
#'   \item{coef}{Coefficient label (markdown-formatted).}
#'   \item{.draw}{Posterior draw index.}
#'   \item{.value}{The draw's value.}
#' }
#' @source See [believe_projection_draws].
#' @seealso [believe_projection], [believe_projection_draws],
#'   [believe_projection_bf], `vignette("bayesian-plots")`.
"believe_projection_coef_draws"

#' Bayes Factor ROPE contrasts from the believe-projection model
#'
#' `bayestestR::bayesfactor_rope()` output for the same model: one row per
#' pairwise contrast (trigger marginalized out) among the 8
#' `scenario` x `negation` cells, for both the mu and sigma submodels.
#' Requires prior draws from the same model structure (`update(mod,
#' sample_prior = "only")`, refit once for this extraction, not otherwise
#' cached) - see `data-raw/believe-projection-posteriors.R`.
#'
#' `contrast` is bayestestR's own auto-generated `"<left> - <right> NA"`
#' string (the trailing `" NA"` marks `trigger` as marginalized out) -
#' unchanged, ready for [prepare_bf_contrasts()]/[plot_bf_forest()]'s
#' `pairs` argument the way `vignette("bayesian-plots")` uses it.
#'
#' @format A tibble with 56 rows and 3 variables:
#' \describe{
#'   \item{contrast}{Raw bayestestR contrast label.}
#'   \item{log_BF}{Log Bayes Factor for the region of practical equivalence
#'     (ROPE), \eqn{0 \pm 0.1 \times SD(Y)}.}
#'   \item{dpar}{`"mu"` or `"sigma"`.}
#' }
#' @source See [believe_projection_draws].
#' @seealso [believe_projection], [believe_projection_draws],
#'   [believe_projection_coef_draws], `vignette("bayesian-plots")`.
"believe_projection_bf"
