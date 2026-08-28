# emptyviz (development version)

Fixes from the 2026-08-22 code review (see `CODE_REVIEW.md`), plus the
violin-geom parity fixes below.

* **Breaking (visual):** `theme_mt()`'s type scale, spacing and several
  defaults were reworked, so every figure this package produces changes.
  What did *not* change: the palettes, the black `hjust = 1` axis titles,
  the plain centred strip text, the centred bottom legend, the tick-less
  axes, the always-drawn axis line at `grid_color`, and the hard-blanked
  `panel.grid.major.x`. The individual entries below cover the rest.
* **Breaking (API):** `theme_mt()`'s `show_axis_line` argument is gone - the
  axis line is always drawn, and `axis_line_color` still controls its
  colour. `legend_text_size`, `minor_grid`, `background` and
  `continuous_palette` are new. Anything passing `theme_mt()`'s arguments
  positionally past `dark` shifts by one; named arguments are unaffected.
* **Changed (typography):** the title, subtitle, strip text, axis titles and
  legend text all sat at `base_size + 2`, so `face = "bold"` was the only
  thing distinguishing a plot title from an axis label, and the axis titles
  outranked the tick labels they describe. The title moves to
  `base_size + 4`, that whole tier to `base_size + 1`, and the caption from
  `base_size - 3` (7pt at the default, under the readable floor once a
  journal typesets a 6-inch figure at 3.3 inches) to `base_size - 2`.
  `legend.text`/`legend.title` were pinned at `base_size + 2` in the
  function body with no argument to change them; they are now
  `legend_text_size`, defaulting to `base_size`.
* **Changed (spacing):** `plot.margin` was `0.1` lines - about a point -
  which, with this theme's `hjust = 1` axis titles, clipped the x-axis
  title against the device edge in most figures and left a LaTeX caption
  flush against the figure's descenders. It is now sized off `base_size`
  and biased right and top. `legend.key.size` scales with the legend text
  rather than being pinned at `0.7cm` (roughly twice the cap height of its
  own labels), and the panel-to-legend gap goes through
  `legend.box.spacing` instead of a negative `legend.margin` that could
  clip the legend's top. `strip.text.x`/`.y` carried `margin()` - zero on
  every side - so under `strip.placement = "outside"` a facet label sat
  flush against the panel it labels; they now get a small margin.
* **Changed:** minor gridlines are off by default (`minor_grid = TRUE`
  restores them). At `linewidth = 0.1` they are about 0.1 mm, which is
  where print workflows stop guaranteeing a line, and they doubled the
  grid's ink without adding information. The major grid moves from
  `gray85 @ 0.20` to `gray87 @ 0.25` - the same apparent weight on screen,
  more reliable on paper - and the axis line tracks it, since
  `axis_line_color` still defaults to `grid_color`.
* **Changed:** `plot.caption`'s colour goes from `gray50` (3.94:1 against
  white) to `gray45` (4.74:1). It is the smallest text in the figure and
  the first thing to dissolve when a journal scales the figure down. It is
  the only text colour that changed.
* **Fixed:** `theme_mt()`'s light-mode `plot.background` was
  `alpha("white", .5)`: invisible on a white page and a milky half-wash on
  any other, so a figure dropped onto a tinted slide or a shaded box picked
  up a haze belonging to neither. It is now opaque `"white"`, with the new
  `background` argument taking `"transparent"` (or any colour) for callers
  who really are compositing. `dark = TRUE` stays transparent regardless,
  as the Quarto light/dark toggle needs.
* **Fixed:** the `geom` theme element's `paper` was `alpha("white", 0.3)`
  (`alpha("black", 0.3)` in dark mode and in the dual-render overlay). In
  ggplot2 >= 4, `GeomLabel$default_aes` resolves `fill` from
  `from_theme(fill %||% paper)`, so every `geom_label()` drew a
  30%-transparent background and the marks underneath showed through the
  text. It is now opaque in all three places.
* **New:** `theme_mt()` sets `palette.colour.continuous`/
  `palette.fill.continuous` to a lightness ramp of `mt_colors[1]` (of
  `dark_mt_colors[1]` in dark mode), and the dual-render dark overlay
  mirrors it. These were unset, so a mapped continuous variable fell
  through to ggplot2's factory blue gradient: a hue outside this palette
  entirely, running *dark to light*, so the largest values drew the
  faintest marks. `continuous_palette = NULL` restores ggplot2's default.
  `mt_colors_many()` is unchanged and still exported.
* **New:** `plot.tag`/`plot.tag.position` are styled to match the title.
  patchwork's `plot_annotation(tag_levels = "A")` previously fell back to
  ggplot2's grey `1.2 * base_size` default, and the tag landed on top of
  the y-axis.
* **New:** continuous colourbars get a hairline `legend.frame` and no
  `legend.ticks`. An unframed gradient bar has no edges against the page,
  which shows up most in print.

* **New:** `mt_colors12`/`dark_mt_colors12` extend the discrete palette from
  five colors to twelve, and `theme_mt()` now uses them as its default
  discrete palette (`dark = TRUE` and the dual-render dark overlay use the
  dark set). The first five positions are `mt_colors5`/`dark_mt_colors5`
  unchanged, so plots with five or fewer categories render as before. The
  shorter constants remain exported.

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
* **Fixed (accessibility):** `knit_print_ggplot_dual()` now honours the
  chunk's `fig.alt` and `fig.cap`. It previously read only `out.width`, so
  the `<img>` tags it hand-builds carried no `alt` attribute at all - worse
  than `alt=""`, since screen readers then fall back to announcing the file
  name - and an author's `fig.cap` was discarded silently. Alt text falls
  back to `fig.cap` (matching knitr's own default for an ordinary chunk), a
  caption is rendered in a `<figure>`/`<figcaption>` wrapper, both options
  are recycled across multiple plots in one chunk, and every interpolated
  value is HTML-escaped. A chunk with `dual_render = TRUE` and neither
  option set now warns once at knit time instead of shipping a figure with
  no text equivalent.
* **Docs (accessibility):** every figure in the README and both vignettes -
  20 chunks - now has `fig.alt` describing what the figure shows. Re-knitting
  `README.md` also refreshed `man/figures/README-violin-example-1.png`, which
  was stale: its SD-band outlines predate the fix that made them track each
  group's resolved fill.
* **Breaking (visual):** `plot_location_scale()` now maps `category` to the
  point glyph as well as to colour when no `shape` column is given, and to
  the ellipse outline style when `ellipse_geom = "path"`. The plot's whole
  job is telling conditions apart, and it previously encoded them by hue
  alone - with a palette whose pairs all fall below the 3:1 WCAG 1.4.11
  threshold, so overlapping ellipses were undecodable in grayscale or for
  readers with reduced colour discrimination. Colour, fill, shape and
  linetype name the same variable and merge into one legend. Opt out with
  `category_shape = FALSE` / `category_linetype = FALSE`. The palettes
  themselves are unchanged.
* **Breaking (visual, dark mode only):** `.dark_axis_line` lightened from
  `#545b63` to `#5f666e`. The axis line is documented as a real boundary -
  a meaningful graphical object - and measured 2.655:1 against the
  `#151515` page background the dark constants are tuned for, just under
  WCAG 1.4.11's 3:1 floor. It now measures 3.14:1. The grid line stays at
  1.19:1 deliberately: it is decorative.
* **Removed:** `use_theme_mt()` no longer calls
  `update_geom_defaults("density", list(adjust = 5))`. It never worked -
  `adjust` is a stat parameter, not a geom aesthetic, so the call only
  injected a phantom `adjust` entry into `GeomDensity$default_aes`,
  session-wide and unremovable short of restarting R, while bandwidth
  stayed at ggplot2's default. Pass `adjust` to `geom_density()` directly
  for heavier smoothing.
* **Fixed:** `layer_halfeye_hdi()` no longer suppresses the caller's colour
  legend. It returned `guides(color = "none")`, and `guides()` is
  plot-global rather than layer-scoped, so composing this bundle into a plot
  silently killed the colour key of every other layer in it. The bundle
  never maps `color` (it sets `interval_color` as a literal parameter), so
  there was nothing to suppress; `fill_ramp` and `pch` are genuinely its own
  and stay hidden.
* **Fixed:** `plot_bf_forest()` errors on a `log_bf` column with no finite
  values instead of building a plot with `±Inf` arrow geometry. The NA guard
  used to live inside the `contrast_reorder` branch, so
  `contrast_reorder = FALSE` - which the guard's own message recommended -
  bypassed it. The evidence-scale extent now also ignores infinite values
  rather than only `NA`, so a single infinite Bayes Factor no longer
  stretches the arrows to infinity.
* **Fixed:** `plot_location_scale()` validates `bounds`. Reversed bounds
  produced an all-`NaN` sigma_max curve that built with no error and no
  warning - the reference curve simply wasn't drawn - and a scalar surfaced
  as `seq()`'s error naming an argument the caller never passed.
* **Fixed:** `plot_location_scale()`'s `shape` and `facet` accept an inline
  expression, not just a bare column name, matching every other tidyeval
  argument in the package. `shape` also keeps the caller's environment, so a
  local variable resolves against the caller rather than the data frame.
* **Fixed:** `plot_location_scale()` warns, naming the condition, when a
  group has fewer than the 4 paired draws `stat_ellipse()` needs. Previously
  the only signal was ggplot2's own "Too few points to calculate an ellipse"
  - repeated once per ellipse layer and naming neither the condition nor
  this function.
* **Fixed:** dual-render figure counters reset per render. Keyed by chunk
  label and never cleared, their lifetime was the whole R session, so every
  re-render (`quarto preview`, the Knit button, `build_vignettes()`) wrote a
  fresh pair of PNGs under a new name - nothing overwritten, nothing cleaned
  up, and each render's HTML pointing at different files.
* **Docs:** `theme_mt()` now documents that the discrete palette separates
  categories by hue with almost no lightness difference, and recommends a
  redundant non-colour channel beyond about three categories. The palette
  constants also gained test coverage (they had none), pinning their values
  and recording where their pairwise contrast actually stands.
* **Breaking (visual):** `theme_mt()`'s `base_size` default drops from 19 to
  10, matching `use_theme_mt()`'s. The two disagreed by nearly 2x with
  neither docstring mentioning the other, so a plot themed directly with
  `theme_mt()` looked nothing like the same theme applied via the session
  default. Pass `base_size = 19` to keep the old size. This ends the
  "`theme_mt(dark = FALSE)` is pixel-identical to 0.1.0" property recorded in
  0.2.0's notes; the theme snapshot test is the record from here on.
* **Fixed:** `prepare_bf_contrasts()` warns when two requested `pairs`
  resolve to the same row of `data` - either an outright repeat, or the two
  directions of one contrast. Both are still allowed, but the same estimate
  then appears as several output rows, which on a forest plot reads as
  several independent ones. This used to happen silently.
* **Docs:** `theme_mt()` documents that dark mode is tuned for a page
  background of about `#151515`, quotes the resulting contrast ratios, and
  says what to do when a host site's dark background differs - the theme sets
  `paper = NA` on purpose, so the real background is the page's and nothing
  validates the assumption.
* **Tests/infra:** the `R CMD check` matrix now covers macOS, Windows, and
  R devel/release/oldrel-1 rather than one Ubuntu runner on release only,
  and a `lint` workflow runs `lintr` on every push against a repo-level
  `.lintr`. New tests assert the three upstream `:::` objects this package
  reaches into still exist and still have the shape the call sites assume,
  so an upstream removal shows up as a red CI run rather than a user's plot
  crashing. Several load-bearing prose invariants became executable checks:
  that `aes(weight = )` reaches the density but deliberately not the SD
  bounds, that `show.legend` reaches only the aura sub-layer, and that
  `fill` is a real formal rather than a reserved `...` argument.
* `Rplots.pdf` is now ignored by git and by `R CMD build`. `DESCRIPTION`'s
  `Remotes:` pin gained a comment recording *why* it is load-bearing:
  gghalves is not on CRAN - it was archived on 2025-12-04 - so the pin is
  the only way to resolve the dependency, not a leftover from development.

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
