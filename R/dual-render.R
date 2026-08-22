# Counters avoid filename collisions if a single chunk prints more than one
# ggplot/patchwork object (rare, but each needs a distinct file name).
# Reset per render by .register_dual_render() below - see the comment there
# for why the counter's lifetime can't be the R session.
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
# Every position-suffixed element theme_mt() itself sets explicitly
# (axis.text.x/.y/.x.bottom/.x.top/.y.left/.y.right, axis.title.x/.x.top/
# .y/.y.right, strip.text.x/.y/.y.left) is set explicitly here too, not just
# the parent (axis.text, axis.title, strip.text) - confirmed empirically
# that a plain parent-level override doesn't reliably reach these children.
# The active default theme (theme_mt(), light) already sets these specific
# elements' `colour` explicitly, and ggplot2's element merging resolves a
# same-named element against the default *before* falling back to the
# parent's inheritance chain - so a plot with any chunk-level partial
# override on one of these exact names (e.g. this book's
# `axis.text.x.bottom = element_markdown(family = "Cascadia Code")`, used to
# render condition-name tick labels in a monospace font) keeps the light
# theme's colour there even after `+ .dark_mode_overlay()`, since merging
# that partial override against the (colour-bearing) default fills in the
# missing colour from the default, not from this overlay's parent-level
# axis.text. That produced dark, low-contrast tick labels on dark-themed
# pages - only on axes that happened to have such a chunk-level override,
# which is why it looked inconsistent rather than uniformly broken.
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
# Verified against ggplot2 4.0.3; if a future release renames/restructures
# plot_theme(), the tryCatch below falls back to theme_get() (the *global*
# active theme, not this specific plot's own resolved one) rather than
# erroring outright - deliberately, so a dual-render chunk still emits
# something instead of failing the whole knit - but that fallback can
# silently un-blank elements a plot deliberately hid (e.g. theme_void()'s
# panel.grid/axis.line), confirmed by simulating plot_theme()'s failure
# directly. A warning surfaces that instead of letting it pass silently.
.dark_mode_overlay <- function(plot) {
  resolved <- tryCatch(
    ggplot2:::plot_theme(plot),
    error = function(e) {
      warning(
        ".dark_mode_overlay(): ggplot2:::plot_theme() failed (", conditionMessage(e),
        ") - falling back to the global active theme, which may not reflect ",
        "this plot's own theme and can un-blank elements (e.g. from ",
        "theme_void()) it deliberately hid. Likely means this internal ",
        "ggplot2 function changed shape; see the comment above this function.",
        call. = FALSE
      )
      theme_get()
    }
  )
  is_blank <- function(name) inherits(calc_element(name, resolved), "element_blank")

  axis_text <- function() element_markdown(colour = .dark_axis_text)
  axis_title <- function() element_markdown(colour = .dark_ink)
  strip_text <- function() element_markdown(colour = .dark_ink)

  candidates <- list(
    plot.background = element_rect(fill = NA, colour = NA),
    panel.background = element_rect(fill = NA, colour = NA),
    plot.title = element_markdown(colour = .dark_ink),
    plot.subtitle = element_markdown(colour = .dark_subtitle),
    plot.caption = element_markdown(colour = .dark_caption),
    axis.title = axis_title(),
    axis.title.x = axis_title(),
    axis.title.x.top = axis_title(),
    axis.title.y = axis_title(),
    axis.title.y.right = axis_title(),
    axis.text = axis_text(),
    axis.text.x = axis_text(),
    axis.text.y = axis_text(),
    axis.text.x.bottom = axis_text(),
    axis.text.x.top = axis_text(),
    axis.text.y.left = axis_text(),
    axis.text.y.right = axis_text(),
    axis.line = element_line(colour = .dark_axis_line),
    legend.text = element_markdown(colour = .dark_axis_text),
    legend.title = element_markdown(colour = .dark_axis_text),
    strip.text.x = strip_text(),
    strip.text.y = strip_text(),
    strip.text.y.left = strip_text(),
    panel.grid = element_line(colour = .dark_grid),
    panel.grid.major = element_line(colour = .dark_grid),
    panel.grid.minor = element_line(colour = .dark_grid)
  )
  candidates <- candidates[!vapply(names(candidates), is_blank, logical(1))]

  do.call(theme, c(candidates, list(
    # `ink` here is what makes unmapped geoms (geom_point/line/segment/
    # text/errorbar/rug) draw in a light color on the dark page - without
    # it they inherit ggplot2's factory "black" default and vanish against
    # the dark background. Mirrors the same `ink` on theme_mt(dark = TRUE)'s
    # own `geom` element; the two must stay in sync.
    geom = element_geom(paper = alpha("black", 0.3), ink = .dark_ink),
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

  # Raw <img> tags, not markdown `![]()` - confirmed by direct comparison that
  # a chunk with a `fig-` prefixed label + fig-cap gets its output re-parsed
  # as markdown by Quarto's crossref/figure filter (so `![]()` there becomes
  # a real <img>), but an ordinary chunk (any other label, no fig-cap - like
  # this book's plot-crit/plot-control/plot-subsamples chunks) does not: the
  # `<div>...![]()...</div>` this used to emit came through completely
  # unprocessed, showing the literal "![](path)" text on the page instead of
  # the image. Raw HTML <img> tags render correctly either way, sidestepping
  # that dependency on which processing path a given chunk happens to hit.
  # class + width replicate what Quarto's own figure output uses (confirmed
  # by comparing against a plain out.width-driven image), since bypassing
  # markdown parsing means those aren't added automatically anymore.
  # Hand-built <img> tags mean nothing adds the accessibility attributes
  # knitr/Quarto would normally add for us, so `fig.alt`/`fig.cap` have to be
  # read out of the chunk options explicitly. They used to be ignored
  # entirely: the emitted tag carried no `alt` attribute at all (worse than
  # alt="", since screen readers then commonly fall back to announcing the
  # file name), and an author's `fig.cap` vanished with no warning.
  #
  # Falling back to fig.cap for the alt text mirrors knitr's own documented
  # behaviour for a normal chunk (`fig.alt` defaults to `fig.cap`), so a
  # dual-rendered chunk and an ordinary one treat the same options the same
  # way. Both are recycled across plots by index, also matching knitr, for
  # the multi-plot-per-chunk case the counter above exists for.
  alt <- .chunk_option_at(options$fig.alt %||% options$fig.cap, idx)
  caption <- .chunk_option_at(options$fig.cap, idx)

  # Surface the omission at knit time rather than shipping a figure with no
  # text equivalent. Only on the chunk's first plot, so a multi-plot chunk
  # warns once.
  if (idx == 1L && !nzchar(alt)) {
    warning(
      "knit_print_ggplot_dual(): chunk '", label, "' has dual_render = TRUE ",
      "but sets neither `fig.alt` nor `fig.cap`, so both rendered images ",
      "get an empty alt attribute - which tells assistive technology to ",
      "skip them entirely. Set `fig.alt` to a description of what the ",
      "figure shows.",
      call. = FALSE
    )
  }

  # Raw <img> tags, not markdown `![]()` - confirmed by direct comparison that
  # a chunk with a `fig-` prefixed label + fig-cap gets its output re-parsed
  # as markdown by Quarto's crossref/figure filter (so `![]()` there becomes
  # a real <img>), but an ordinary chunk (any other label, no fig-cap - like
  # this book's plot-crit/plot-control/plot-subsamples chunks) does not: the
  # `<div>...![]()...</div>` this used to emit came through completely
  # unprocessed, showing the literal "![](path)" text on the page instead of
  # the image. Raw HTML <img> tags render correctly either way, sidestepping
  # that dependency on which processing path a given chunk happens to hit.
  # class + width replicate what Quarto's own figure output uses (confirmed
  # by comparing against a plain out.width-driven image), since bypassing
  # markdown parsing means those aren't added automatically anymore.
  #
  # Everything interpolated into an attribute goes through .escape_html()
  # first: a figure path or an out.width containing a quote or an ampersand
  # would otherwise break the markup, and alt/caption text is free-form prose
  # where that's likely rather than hypothetical.
  width_style <- if (!is.null(options$out.width)) {
    sprintf(' style="width:%s"', .escape_html(options$out.width))
  } else {
    ""
  }
  img_tag <- function(path) {
    sprintf(
      '<img src="%s" class="img-fluid figure-img" alt="%s"%s>',
      .escape_html(path), .escape_html(alt), width_style
    )
  }

  # No `id` on the <figure>: the same figure is emitted twice (once per
  # colour scheme) and duplicate element ids are invalid HTML. Quarto's
  # light/dark CSS hides the inactive half with display:none, so only one
  # copy of the caption reaches the accessibility tree at a time.
  fig_wrap <- function(inner) {
    if (!nzchar(caption)) {
      return(inner)
    }
    paste0(
      '<figure class="figure">\n', inner,
      '\n<figcaption class="figure-caption">', .escape_html(caption),
      "</figcaption>\n</figure>"
    )
  }

  knitr::asis_output(paste0(
    '<div class="light-content">\n', fig_wrap(img_tag(light_path)), '\n</div>\n\n',
    '<div class="dark-content">\n', fig_wrap(img_tag(dark_path)), '\n</div>'
  ))
}

# Minimal HTML-attribute escaping for values interpolated into the hand-built
# tags above. `&` has to come first or it re-escapes the entities the later
# substitutions introduce.
.escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

# knitr lets fig.alt/fig.cap be a vector, one entry per plot in a chunk,
# recycled if shorter. Mirrors that, and normalizes NULL/NA/non-character to
# "" so callers can treat the result as a plain string.
.chunk_option_at <- function(value, idx) {
  if (is.null(value) || length(value) == 0) {
    return("")
  }
  value <- as.character(value)
  out <- value[[((idx - 1L) %% length(value)) + 1L]]
  if (is.na(out)) "" else out
}

# Registers knit_print_ggplot_dual() as the knit_print method for "ggplot"
# objects, in knitr's own S3 method table (registerS3method's `envir`
# argument controls where the generic is looked up from, not where the
# method function itself lives) - the standard pattern for a package
# providing a knit_print method for a Suggests-only knitr, since a static
# NAMESPACE S3method() entry can't reference a generic that might not be
# installed. A no-op if knitr isn't installed. `asNamespace("knitr")` (not
# `:::`) is used only to get a namespace *environment* to pass as
# registerS3method()'s `envir` - both are base R, not reaching into any
# unexported knitr object/internal, so this is far less fragile than the
# gghalves/ggplot2 internals this package reaches into elsewhere; still
# worth flagging as "if S3 method registration for Suggests-only packages
# ever changes recommended shape, revisit this."
.register_dual_render <- function() {
  # Clearing the counters here is what makes dual-render filenames
  # deterministic. They're keyed by chunk label and were never reset, so
  # their lifetime was the whole R session rather than one render - and
  # repeated renders in one session are the normal workflow (quarto
  # preview, RStudio's Knit button, devtools::build_vignettes()). Every
  # render therefore wrote a fresh pair of PNGs under a new name, nothing
  # was overwritten and nothing cleaned up: a book with 40 dual-rendered
  # figures previewed ten times left ~800 orphaned files, and each render's
  # HTML pointed at different ones, defeating asset caching, incremental
  # deploys and content-hash diffing. use_theme_mt() calls this at the top
  # of a document's setup chunk, which is exactly one reset per render.
  rm(
    list = ls(.dual_render_counters, all.names = TRUE),
    envir = .dual_render_counters
  )
  if (requireNamespace("knitr", quietly = TRUE)) {
    registerS3method("knit_print", "ggplot", knit_print_ggplot_dual, envir = asNamespace("knitr"))
  }
  invisible(NULL)
}
