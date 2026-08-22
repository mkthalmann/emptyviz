# emptyviz (development version)

## Fixes from the 2026-08-22 code review

* **Fixed (dark mode, most user-visible):** `theme_mt(dark = TRUE)` and the
  dual-render dark overlay now set the `geom` theme element's own `ink`, so
  geoms that don't set a color explicitly - `geom_point()`, `geom_line()`,
  `geom_segment()`, `geom_text()`, `geom_errorbar()`, `geom_rug()` - draw in
  a light color. Previously only *text* elements picked up the dark ink
  (`theme_minimal()`'s `ink` argument doesn't reach geom defaults), leaving
  geom colors at ggplot2's factory `"black"`: every dark-mode figure built
  from default-colored geoms rendered its data marks black on a dark page.
  Light mode is unchanged.
* **Fixed:** `geom_violin_sd(drop = FALSE)` no longer fails with ggplot2's
  internal `` `scale_id` must not contain any "NA" ``. Under `drop = FALSE`
  ggplot2's `StatYdensity` keeps groups with fewer than two points while the
  SD-bounds helper still drops them; the mismatch produced all-`NA` rows
  rather than none. Thin groups now keep their slot in the aura sub-layer
  (matching `geom_violin(drop = FALSE)`) and simply get no SD band.
* **Fixed:** `plot_bf_forest()` and `plot_ridge_hdi()` now catch *any*
  category with no non-`NA` ordering value, not only an entirely-`NA`
  column, and name the offending categories. `forcats::fct_reorder()` fails
  per level, so a single `NA` log-Bayes-Factor row still produced the
  cryptic `lvls_reorder()` error these guards exist to replace. Scattered
  `NA`s inside otherwise-populated categories keep working.

## Violin geom parity fixes

Parity fixes for `geom_violin_sd()`/`geom_half_violin_sd()`/
`geom_split_violin_sd()`, found while comparing their output side by side
against plain `geom_violin()`/`gghalves::geom_half_violin()` on zero-variance
and skewed/bimodal data. None of this changes the geoms' API beyond adding
one new argument (`trim`); it changes their *default rendered output*.

* **Breaking (visual):** `trim` now defaults to `TRUE`, matching
  `geom_violin()`'s/`gghalves::geom_half_violin()`'s own default, instead of
  being hardcoded to `FALSE` with no way to override it. The old hardcoded
  `FALSE` made the low-alpha "aura" sub-layer render a spuriously wide,
  tapered shape that could extend well past the actual data - worst on
  zero-variance groups (a constant value could render spanning several units
  in either direction, because `stats::bw.nrd0()`'s bandwidth fallback for
  constant data scales with the value's own magnitude, not its spread) and
  on skewed/bimodal data. `trim = FALSE` is still available for that softer,
  tapered look.
* **Fixed (visual, most user-visible):** the SD-band outline sub-layer's
  color no longer falls back to one flat default for every group when
  `fill` is mapped via `aes(fill = ...)` rather than passed as a literal
  argument - it now tracks each group's resolved fill automatically. This
  affected `geom_half_violin_sd()`'s own `@examples` block, since
  `aes(fill = ...)` is the idiomatic way to use these geoms.
* **Fixed:** the same outline sub-layer also silently broke dodge
  positioning whenever `fill` was dodge-mapped (e.g. two sub-groups sharing
  one x-category) - it collapsed to one outline spanning both dodge slots
  instead of two correctly-positioned ones. Both this and the color issue
  traced back to the same cause: a literal `fill = NA` geom parameter,
  which makes ggplot2 drop `fill` from that layer's own aesthetic-derived
  grouping entirely. Fixed by nulling the fill at draw time instead (a new
  internal `GeomViolinOutline`/`GeomHalfViolinOutline`), after grouping and
  dodging have already run correctly off the real fill values.
* **Fixed:** the legend key for all three geoms no longer shows a
  washed-out double-overlay of the aura's and SD-fill's low-alpha swatches
  (or, for `style = "outline"`, nothing but the faint aura). Only the aura
  sub-layer contributes a key now, rendered at full opacity via a bundled
  `guides()` call - a single clean swatch, matching plain `geom_violin()`.
* **Fixed:** `geom_violin_sd(drop = FALSE)`/`geom_violin_sd(quantiles = ...)`
  (`stat_ydensity()` parameters added to ggplot2 after these geoms were
  first written) no longer silently warn "Ignoring unknown parameters" and
  get dropped on the SD-band sub-layers specifically, while working fine on
  the aura. `StatYdensitySD`/`StatHalfYdensitySD` now forward arbitrary
  stat parameters to their parent stat instead of re-declaring a fixed list,
  so this class of gap shouldn't recur as ggplot2/gghalves add parameters in
  the future; a new `test-stat-parity.R` pins the two stats' accepted
  parameter lists against their parents' as a regression guard.
* **Fixed:** passing `stat = ...` to `geom_violin_sd()`/`geom_half_violin_sd()`
  no longer crashes with an opaque "formal argument matched by multiple
  actual arguments" error - it now warns and is ignored, the same as the
  other reserved arguments (`alpha`/`color`/`colour`/`linewidth`).
* Not fixed, by design: each of these geoms' 2-3 sub-layers independently
  validates/warns on the same underlying data, so a warning that would fire
  once for plain `geom_violin()` (e.g. removed non-finite values, or an
  unknown parameter) fires 2-3 times here - once per sub-layer. Safely
  deduplicating warnings across independently-built `ggplot2` layers has no
  clean hook to hang off of, and this is cosmetic rather than incorrect, so
  it's left as a known, accepted limitation rather than fixed.

A second round of fixes from a broader pass looking for the same *classes*
of risk elsewhere in the package - hardcoded signatures drifting from
upstream, literal aesthetic overrides silently breaking ggplot2 internals,
undocumented reaches into unexported internals, missing regression coverage
for behavior this file already claims is guaranteed.

* **Fixed (crash):** `geom_half_violin_sd()`/`geom_split_violin_sd()` no
  longer crash at render time (`missing value where TRUE/FALSE needed`) on
  a "thin" x-category (fewer than 2 raw points on one side). Traced to a
  `gghalves` 0.1.4 bug in `GeomHalfViolin$setup_params()`'s own `side`
  recycling (against the *count* of groups surviving the density stat's
  `n >= 2` drop, not the highest *original* group id still present) -
  reproduces with plain, unmodified `gghalves::geom_half_violin()` too, not
  something this package's own stat logic introduced. Worked around via a
  new internal `GeomHalfViolinSD`.
* **Breaking (API):** `layer_halfeye_hdi()`'s `fill_colors` argument (2
  distinct hues) is replaced by `fill` (a single base color) and
  `fill_range` (a shading range) - the HDI-width shading is now mapped to
  `fill_ramp` (a dedicated `ggdist` aesthetic for exactly this) instead of
  `fill` directly. The old approach bundled a plot-global
  `scale_fill_manual()` that silently claimed the entire `fill` aesthetic:
  adding *any* other fill-mapped layer to a plot built on this (directly,
  or via `plot_ridge_hdi()`/`plot_coef_grid_hdi()`) crashed with
  `Insufficient values in manual scale`, confirmed reproducible through the
  real exported functions. `fill_ramp` has its own aesthetic slot and can't
  collide with a caller's own `fill` mapping.
* **Fixed:** `plot_ridge_hdi()`/`plot_bf_forest()` gave a cryptic,
  emptyviz-unattributed error (`` `idx` must contain one integer for each
  level of `f` ``, from deep inside `forcats::fct_reorder()`) when `value`/
  `log_bf` was entirely `NA` with the default `category_reorder`/
  `contrast_reorder = TRUE`. Both now raise a clear error naming the actual
  problem and the `category_reorder`/`contrast_reorder = FALSE` workaround.
* **Fixed:** `plot_ridge_hdi()`, `plot_coef_grid_hdi()`, `plot_location_scale()`,
  and `plot_bf_forest()` leaked R's raw, internal `argument "category_sym"
  is missing` (the `rlang::ensym()`-renamed variable, not the documented
  parameter name) when a required argument was omitted. All four now raise
  a clear `"function_name(): \`arg\` is required."` error instead.
* **Hardened:** the `Remotes: erocoar/gghalves` dependency is now pinned to
  the exact commit this package's `gghalves`-internals-reaching code was
  verified against (previously unpinned - a fresh install could silently
  pull a different `gghalves` than what the code comments claimed
  compatibility with). `ggdist`/`ggtext`/`ggarrow`/`gghalves` also gain
  explicit minimum versions in `DESCRIPTION`.
* **Hardened:** `.dark_mode_overlay()` now warns (instead of silently
  falling back to the *global* active theme, which can un-blank elements a
  plot deliberately hid via e.g. `theme_void()`) if the internal
  `ggplot2:::plot_theme()` it depends on ever fails - confirmed via a
  simulated failure that this path had no test coverage before.
* Docs: clarified that `sd_alpha` only controls the SD-band *fill*
  sub-layer, not the outline (always drawn at full opacity, by design -
  it's the one element meant to reliably mark the SD band regardless of
  other alpha settings) - the previous wording ("Alpha of the aura and
  SD-band sub-layers") implied broader coverage than it actually has. No
  behavior change.
* Internal cleanup: the mean ± SD bounds computation, previously
  near-duplicated between `StatYdensitySD`/`StatHalfYdensitySD`, is now a
  single shared helper; the package's other unexported-internals reaches
  (`ggplot2:::ggproto_formals`, `asNamespace("knitr")`) gain the same
  "verified against version X" comments already used for the `gghalves`
  reach; `.claude` is excluded from `R CMD check`.

# emptyviz 0.2.0

* `theme_mt()` gains a `dark` argument. `theme_mt(dark = TRUE)` swaps in a
  dark-mode-appropriate variant: a transparent plot/panel background instead
  of the translucent white "paper", light ink/grid/axis-text colors, and
  [dark_mt_colors5] in place of [mt_colors5] as the discrete palette and geom
  fill default. `theme_mt()`'s output with `dark = FALSE` (the default) is
  unchanged - verified pixel-identical against the previous release.
* New `dark_mt_colors`/`dark_mt_colors3`/`dark_mt_colors4`/`dark_mt_colors5`,
  lightened tints of the `mt_colors` family for use against dark backgrounds.
* `use_theme_mt()` now also registers (only if `knitr` is installed) a
  `knit_print` method for `ggplot`/`patchwork` objects that renders a chunk
  twice - once normally, once with a dark-mode color overlay - whenever that
  chunk's `dual_render` chunk option is `TRUE` (settable per chunk, or as a
  project-wide `knitr: opts_chunk: dual_render: true` default), emitting
  both images wrapped for Quarto's `.light-content`/`.dark-content` toggle.
  Chunks that don't set the option, and every other output type (tables,
  console output, base R plots), are unaffected - the plotting code itself
  never has to change to pick this up, only the chunk's metadata does.

# emptyviz 0.1.0

Initial package release, migrated from the `theme.R` / `theme_bayes.R`
scripts previously copy-pasted into each project.

* **Breaking:** theme activation is no longer automatic on `library(emptyviz)`.
  Call `use_theme_mt()` explicitly to set `theme_mt()` as the active
  `ggplot2` theme and apply the package's `geom_density()` default.
* All functions are namespaced under `emptyviz::` instead of being sourced
  from a local copy of `theme.R`/`theme_bayes.R`.
* `geom_half_violin_sd()` (and, through it, `geom_split_violin_sd()`) call
  `gghalves:::StatHalfYdensity`, an unexported object of the `gghalves`
  package. This has been verified to work against `gghalves` 0.1.4; if a
  future `gghalves` release restructures that internal ggproto, these two
  geoms may need an update. See the comment above `StatHalfYdensitySD` in
  `R/geom-violin-sd.R`.
* The former `demo/demo.qmd` walkthrough is now two package vignettes,
  `vignette("geoms-and-theme")` and `vignette("bayesian-plots")`, plus a
  short README.
* Both vignettes now use real data (`believe_projection` and the
  `believe_projection_draws`/`believe_projection_coef_draws`/
  `believe_projection_bf` posterior summaries) from Thalmann & Matticchio
  (2024) instead of fabricated examples; see `?believe_projection`.
* **Fixed:** `plot_location_scale()`'s `location`/`sigma` arguments no
  longer default to same-named bare symbols (`location = location`,
  `sigma = sigma`). That self-referential default crashed with a cryptic
  "promise already under evaluation: recursive default argument reference"
  error whenever the caller's data lacked columns literally named
  `location`/`sigma` and didn't pass those arguments explicitly - which was
  every realistic use case, since posterior draws are never naturally named
  that way. `location`/`sigma` are now required arguments with no default.
* **Breaking:** `colors`/`colors3`/`colors4`/`colors5`/`colors_many` are
  renamed to `mt_colors`/`mt_colors3`/`mt_colors4`/`mt_colors5`/
  `mt_colors_many`. The old names shadowed `grDevices::colors()`, a base R
  function, once the package was attached - confusing enough (ambiguous
  `?colors`, noisy autocomplete, a surprising break if calling code ever
  did `colors <- colors[1:2]` and later called `colors()`) to fix before
  the API has any real installed base to break.
* Every exported function now has a runnable `@examples` block.
* `theme_mt()`'s default `base_family = "Roboto Condensed"` is not
  installed by this package; its docs and the README now say so
  explicitly, since a missing font degrades silently (a fallback font, no
  error) rather than failing loudly - exactly the kind of thing that
  breaks the "reproduce this exact plot" promise silently.
* **Fixed:** `geom_split_violin_sd()`'s fill legend no longer ignores
  `labs(fill = ...)`/`guides(fill = guide_legend(title = ...))`. The
  internal `scale_fill_manual()` used to hardcode its `name` argument to
  the `split` column's name, which permanently pinned the fill guide's title
  and kept it from merging with `color`/`shape` legends mapped to the
  same column - producing two separate legends (one correctly retitled,
  one stuck showing the raw column name) with no way to avoid it short of
  renaming the column or overriding its label. The scale now leaves
  `name` as the ggplot2 default, so it follows normal `labs()`/`guides()`
  conventions like every other scale.
