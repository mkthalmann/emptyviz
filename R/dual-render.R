# Per-chunk counters, so that a chunk printing several plots gives each a
# distinct file name. Reset at every render by .register_dual_render().
.dual_render_counters <- new.env(parent = emptyenv())

.next_dual_render_index <- function(label) {
  key <- label %||% "unnamed-chunk"
  n <- (.dual_render_counters[[key]] %||% 0L) + 1L
  .dual_render_counters[[key]] <- n
  n
}

# Colour-only theme overlay for the dark half of a dual render. It sets only
# colours and fills, never sizes, families or margins, so it can be added on
# top of a plot's own theme customizations. Text elements use
# element_markdown(), the class theme_mt() uses for them: ggplot2 4 refuses to
# merge elements of different classes.
#
# Every position-specific element that theme_mt() sets is set here as well,
# not only its parent. theme_mt() gives those children a colour of their own,
# and when a plot overrides another property of one of them (say, the family
# of axis.text.x.bottom), merging fills in the colour from theme_mt(), not
# from a parent set by the overlay.
#
# `plot` (for a patchwork, its first sub-plot) is used only to find the
# elements it has blanked, which the overlay must leave blank. Elements can
# be blank by inheritance (theme_void() blanks the root `line` and `rect`),
# so the plot's theme is completed against the active default theme, as
# ggplot2 does when it draws the plot.
.dark_mode_overlay <- function(plot) {
  resolved <- complete_theme(plot$theme)
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
    # Mirrors the colourbar frame of theme_mt(dark = TRUE).
    legend.frame = element_rect(colour = .dark_axis_line),
    strip.text.x = strip_text(),
    strip.text.y = strip_text(),
    strip.text.y.left = strip_text(),
    panel.grid = element_line(colour = .dark_grid),
    panel.grid.major = element_line(colour = .dark_grid),
    panel.grid.minor = element_line(colour = .dark_grid)
  )
  candidates <- candidates[!vapply(names(candidates), is_blank, logical(1))]

  do.call(theme, c(candidates, list(
    # `ink` colours unmapped geoms, and it is what the plot builders' default
    # colours read to choose their dark tints (R/utils-theme-colour.R).
    # `paper` is the #151515 page dark mode is tuned for. Both mirror the
    # `geom` element of theme_mt(dark = TRUE).
    geom = element_geom(paper = "#151515", ink = .dark_ink),
    geom.density = element_geom(fill = alpha(dark_mt_colors[1], .5)),
    geom.bar = element_geom(fill = dark_mt_colors[1]),
    geom.area = element_geom(fill = dark_mt_colors[1]),
    geom.col = element_geom(fill = dark_mt_colors[1]),
    geom.ribbon = element_geom(fill = dark_mt_colors[1]),
    palette.colour.discrete = dark_mt_colors12,
    palette.fill.discrete = dark_mt_colors12,
    # Mirrors theme_mt(dark = TRUE)'s continuous_palette default.
    palette.colour.continuous = c("#13414f", dark_mt_colors[1]),
    palette.fill.continuous = c("#13414f", dark_mt_colors[1])
  )))
}

# knit_print method for ggplot objects (patchwork objects are ggplots too),
# registered by use_theme_mt(). Chunks without `dual_render: true` print as
# they would without the method. With it, and for HTML output from Quarto,
# the plot is saved twice, unchanged and with .dark_mode_overlay() added, and
# both images are emitted inside Quarto's .light-content/.dark-content
# classes, so the page's light/dark toggle shows the matching one. Returns
# invisible(NULL) or a knitr::asis_output().
knit_print_ggplot_dual <- function(x, options, ...) {
  if (!isTRUE(options$dual_render)) {
    print(x)
    return(invisible(NULL))
  }
  # The output below is raw HTML that relies on Quarto's light/dark CSS.
  # Pandoc drops raw HTML when writing LaTeX or Word, so for those formats
  # the plot is rendered the ordinary way; that is the expected behaviour of
  # a project-wide `dual_render` default in a multi-format project, so it is
  # silent. HTML without Quarto would show both images, which points to a
  # misconfiguration, so that case warns.
  if (!knitr::is_html_output()) {
    print(x)
    return(invisible(NULL))
  }
  if (is.null(knitr::opts_knit$get("quarto.version"))) {
    .warn_no_quarto()
    print(x)
    return(invisible(NULL))
  }

  label <- options$label %||% "unnamed-chunk"
  idx <- .next_dual_render_index(label)
  fig_path <- options$fig.path %||% ""
  width <- options$fig.width %||% 7
  height <- options$fig.height %||% 5
  # For HTML output knitr has already applied `fig.retina`: `dpi` arrives
  # multiplied by it, and `out.width` set to the figure's nominal width in
  # pixels.
  dpi <- options$dpi %||% 96
  device <- .dual_render_device(options$dev)

  # For a patchwork, `&` adds the overlay to every sub-plot (`+` would reach
  # only the last). Blanked elements are read from the first sub-plot, which
  # assumes the sub-plots blank the same elements.
  is_patchwork <- inherits(x, "patchwork")
  overlay <- .dark_mode_overlay(if (is_patchwork) x[[1]] else x)
  x_dark <- if (is_patchwork) x & overlay else x + overlay

  save_pair <- function(device) {
    paths <- paste0(fig_path, label, c("-light-", "-dark-"), idx, ".", device$ext)
    dir.create(dirname(paths[1]), recursive = TRUE, showWarnings = FALSE)
    unlink(paths) # so that a file left by an earlier render cannot mask a failure
    for (i in 1:2) {
      ggsave(
        paths[i], if (i == 1) x else x_dark,
        device = device$fun,
        width = width, height = height, dpi = dpi,
        bg = "transparent"
      )
    }
    paths
  }
  paths <- save_pair(device)
  # A device can fail without an error: R's svg() only warns when its cairo
  # library cannot be loaded (e.g. CRAN's macOS build without XQuartz). An
  # image tag pointing at a missing file would show nothing, so fall back to
  # PNG instead.
  if (!all(file.exists(paths))) {
    warning(
      "knit_print_ggplot_dual(): chunk '", label, "' could not be saved with ",
      "dev = \"", options$dev[[1]], "\"; using PNG instead.",
      call. = FALSE
    )
    paths <- save_pair(list(fun = NULL, ext = "png"))
  }
  light_path <- paths[1]
  dark_path <- paths[2]

  # The <img> tags are built by hand, so `fig.alt` and `fig.cap` are read
  # here. As in knitr, the alt text falls back to the caption, and vector
  # values are recycled across the plots of a chunk.
  alt <- .chunk_option_at(options$fig.alt %||% options$fig.cap, idx)
  caption <- .chunk_option_at(options$fig.cap, idx)

  # Without alt text the images would be skipped by assistive technology;
  # warn once per chunk.
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

  # Raw <img> tags rather than markdown `![]()`: Quarto parses the output of
  # an ordinary chunk (no `fig-` label and caption) as raw HTML, where
  # markdown image syntax would appear as literal text. The classes match
  # Quarto's own figure output. Every interpolated value is HTML-escaped.
  # A bare number (as knitr sets for retina figures) is a width in pixels;
  # CSS needs the unit.
  out_width <- .chunk_option_at(options$out.width, idx)
  if (grepl("^[0-9.]+$", out_width)) out_width <- paste0(out_width, "px")
  width_style <- if (nzchar(out_width)) {
    sprintf(' style="width:%s"', .escape_html(out_width))
  } else {
    ""
  }
  img_tag <- function(path) {
    sprintf(
      '<img src="%s" class="img-fluid figure-img" alt="%s"%s>',
      .escape_html(path), .escape_html(alt), width_style
    )
  }

  # The figure is emitted twice, so the <figure> carries no `id` (ids must be
  # unique); Quarto hides the inactive copy with display: none. Quarto wraps
  # a chunk with a `fig-` label in its own numbered figure with the caption,
  # so a caption is added here only for other chunks.
  quarto_captions <- startsWith(label, "fig-")
  fig_wrap <- function(inner) {
    if (!nzchar(caption) || quarto_captions) {
      return(inner)
    }
    paste0(
      '<figure class="figure">\n', inner,
      '\n<figcaption class="figure-caption">', .escape_html(caption),
      "</figcaption>\n</figure>"
    )
  }

  knitr::asis_output(paste0(
    '<div class="light-content">\n', fig_wrap(img_tag(light_path)), "\n</div>\n\n",
    '<div class="dark-content">\n', fig_wrap(img_tag(dark_path)), "\n</div>"
  ))
}

# The graphics device for a dual-rendered figure: the chunk's own `dev` when
# it is one a browser can display, the same device knitr would use for it,
# and PNG otherwise (e.g. for `dev = "pdf"`). `fun = NULL` lets ggsave()
# choose by file extension.
.dual_render_device <- function(dev) {
  dev <- if (is.character(dev) && length(dev) > 0) dev[[1]] else "png"
  installed <- function(pkg) requireNamespace(pkg, quietly = TRUE)
  switch(dev,
    png = list(fun = grDevices::png, ext = "png"),
    ragg_png = if (installed("ragg")) {
      list(fun = getExportedValue("ragg", "agg_png"), ext = "png")
    },
    jpeg = list(fun = grDevices::jpeg, ext = "jpeg"),
    svg = list(fun = grDevices::svg, ext = "svg"),
    svglite = if (installed("svglite")) {
      list(fun = getExportedValue("svglite", "svglite"), ext = "svg")
    }
  ) %||% list(fun = NULL, ext = "png")
}

# Warns once per render (the flag is reset by .register_dual_render()). Quarto
# sets the `quarto.version` knitr option when it knits a document.
.warn_no_quarto <- function() {
  if (isTRUE(.dual_render_counters$.warned_unsupported)) {
    return(invisible(NULL))
  }
  assign(".warned_unsupported", TRUE, envir = .dual_render_counters)
  warning(
    "knit_print_ggplot_dual(): `dual_render` needs HTML output rendered by ",
    "Quarto; rendering figures normally instead.",
    call. = FALSE
  )
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

# Registers knit_print_ggplot_dual() as knitr's knit_print method for ggplot
# objects. knitr is only suggested, so the method cannot be declared in
# NAMESPACE; registerS3method() with knitr's namespace as `envir` is the
# usual way to register it at run time. A no-op if knitr is not installed.
.register_dual_render <- function() {
  # Resetting the counters (and the once-per-render warning) here, at the
  # start of each render, keeps figure file names the same across repeated
  # renders in one session, so earlier files are overwritten rather than
  # accumulating.
  rm(
    list = ls(.dual_render_counters, all.names = TRUE),
    envir = .dual_render_counters
  )
  if (requireNamespace("knitr", quietly = TRUE)) {
    registerS3method("knit_print", "ggplot", knit_print_ggplot_dual, envir = asNamespace("knitr"))
  }
  invisible(NULL)
}

# Removes the method .register_dual_render() added, and only that one: a
# knit_print method for ggplot objects registered by anything else is left
# alone.
.unregister_dual_render <- function() {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    return(invisible(NULL))
  }
  methods <- asNamespace("knitr")[[".__S3MethodsTable__."]]
  if (identical(methods[["knit_print.ggplot"]], knit_print_ggplot_dual)) {
    rm("knit_print.ggplot", envir = methods)
  }
  invisible(NULL)
}
