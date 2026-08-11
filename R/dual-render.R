# Counters avoid filename collisions if a single chunk prints more than one
# ggplot/patchwork object (rare, but each needs a distinct file name).
.dual_render_counters <- new.env(parent = emptyenv())

.next_dual_render_index <- function(label) {
  key <- label %||% "unnamed-chunk"
  n <- (.dual_render_counters[[key]] %||% 0L) + 1L
  .dual_render_counters[[key]] <- n
  n
}

# Color-only theme overlay for the "dark" half of a dual render: overrides
# just the colour/fill of each element (never family/size/margin/etc.), so it
# composes safely on top of a plot that already carries its own
# theme_mt()-plus-chunk-level customizations (e.g. a one-off axis.text family
# override) without clobbering them the way adding a second full
# theme_mt(dark = TRUE) would. Every markdown-aware element here uses
# ggtext::element_markdown() rather than element_text(), matching the class
# theme_mt() itself uses for that slot - ggplot2 4.0's element merging errors
# ("Only elements of the same class can be merged") if the classes disagree.
#
# `plot` is the plot this overlay is about to be added to (for a patchwork
# combo, pass a representative sub-plot, e.g. plot[[1]]) - only used to check
# which elements it has deliberately blanked (e.g. via `+ theme_void()`, used
# by the sitzung-04 orbital diagram for a clean, axis-free look), so those
# stay blank instead of this overlay un-blanking them. A plot's own
# `$theme` only records elements set directly on it, not ones it inherits
# blank via a parent (theme_void() blanks panel.grid/axis.line/axis.ticks by
# blanking the root `line`/`rect` elements, not those specific names) -
# ggplot2:::plot_theme() + calc_element() resolve the full inheritance chain
# (merged with the active default theme) to get the real effective element,
# confirmed empirically against both a theme_void() plot and a normal one.
.dark_mode_overlay <- function(plot) {
  resolved <- tryCatch(ggplot2:::plot_theme(plot), error = function(e) theme_get())
  is_blank <- function(name) inherits(calc_element(name, resolved), "element_blank")

  candidates <- list(
    plot.background = element_rect(fill = NA, colour = NA),
    panel.background = element_rect(fill = NA, colour = NA),
    plot.title = element_markdown(colour = .dark_ink),
    plot.subtitle = element_markdown(colour = .dark_subtitle),
    plot.caption = element_markdown(colour = .dark_caption),
    axis.title = element_markdown(colour = .dark_ink),
    axis.text = element_markdown(colour = .dark_axis_text),
    axis.line = element_line(colour = .dark_grid),
    legend.text = element_markdown(colour = .dark_axis_text),
    legend.title = element_markdown(colour = .dark_axis_text),
    panel.grid = element_line(colour = .dark_grid)
  )
  candidates <- candidates[!vapply(names(candidates), is_blank, logical(1))]

  do.call(theme, c(candidates, list(
    geom = element_geom(paper = alpha("black", 0.3)),
    geom.density = element_geom(fill = alpha(dark_mt_colors[1], .5)),
    geom.bar = element_geom(fill = dark_mt_colors[1]),
    geom.area = element_geom(fill = dark_mt_colors[1]),
    geom.col = element_geom(fill = dark_mt_colors[1]),
    geom.ribbon = element_geom(fill = dark_mt_colors[1]),
    palette.colour.discrete = dark_mt_colors5,
    palette.fill.discrete = dark_mt_colors5
  )))
}

# Dual light/dark knit_print method for ggplot/patchwork objects. Registered
# by use_theme_mt() (only if knitr is installed) as the knit_print method for
# objects of class "ggplot" - which patchwork objects also carry, so this
# covers combined plots too.
#
# For an ordinary chunk (no `dual_render` chunk option set to TRUE), this
# prints x exactly as knitr would with no custom method registered at all.
# For a chunk with `#| dual_render: true` (set directly, or via a project-
# wide `knitr: opts_chunk: dual_render: true` default in _quarto.yml), it
# instead saves two PNGs - one from x completely unchanged, one with a
# color-only dark-mode overlay applied - and emits both wrapped in Quarto's
# .light-content/.dark-content classes, so the browser's light/dark toggle
# shows the right one with no client-side re-rendering.
#
# x: a ggplot/patchwork object. options: the chunk's knitr options, supplied
# automatically by knitr's knit_print dispatch. Returns invisible(NULL) for a
# normal render, or a knitr::asis_output() for a dual-mode render.
knit_print_ggplot_dual <- function(x, options, ...) {
  if (!isTRUE(options$dual_render) || !requireNamespace("knitr", quietly = TRUE)) {
    print(x)
    return(invisible(NULL))
  }

  label <- options$label %||% "unnamed-chunk"
  idx <- .next_dual_render_index(label)
  fig_path <- options$fig.path %||% ""
  width <- options$fig.width %||% 7
  height <- options$fig.height %||% 5
  dpi <- options$dpi %||% 96

  light_path <- paste0(fig_path, label, "-light-", idx, ".png")
  dark_path <- paste0(fig_path, label, "-dark-", idx, ".png")
  dir.create(dirname(light_path), recursive = TRUE, showWarnings = FALSE)

  # patchwork's `+` only applies a theme addition to the last-added
  # sub-plot (it treats `+` as "keep composing the current plot"); `&` is
  # patchwork's own operator for applying an addition to every sub-plot
  # uniformly. Confirmed empirically: without this, only one panel of a
  # combined plot would pick up the dark-mode overlay, leaving the rest
  # still light-themed underneath. The blank-check inside
  # .dark_mode_overlay() uses the first sub-plot as representative - fine
  # for a patchwork built from visually-consistent panels (the only real
  # case in this book), not guaranteed if sub-plots blank differently.
  is_patchwork <- inherits(x, "patchwork")
  overlay <- .dark_mode_overlay(if (is_patchwork) x[[1]] else x)
  x_dark <- if (is_patchwork) x & overlay else x + overlay

  ggsave(light_path, x, width = width, height = height, dpi = dpi, bg = "transparent")
  ggsave(dark_path, x_dark, width = width, height = height, dpi = dpi, bg = "transparent")

  knitr::asis_output(paste0(
    '<div class="light-content">\n![](', light_path, ')\n</div>\n\n',
    '<div class="dark-content">\n![](', dark_path, ')\n</div>'
  ))
}

# Registers knit_print_ggplot_dual() as the knit_print method for "ggplot"
# objects, in knitr's own S3 method table (registerS3method's `envir`
# argument controls where the generic is looked up from, not where the
# method function itself lives) - the standard pattern for a package
# providing a knit_print method for a Suggests-only knitr, since a static
# NAMESPACE S3method() entry can't reference a generic that might not be
# installed. A no-op if knitr isn't installed.
.register_dual_render <- function() {
  if (requireNamespace("knitr", quietly = TRUE)) {
    registerS3method("knit_print", "ggplot", knit_print_ggplot_dual, envir = asNamespace("knitr"))
  }
  invisible(NULL)
}
