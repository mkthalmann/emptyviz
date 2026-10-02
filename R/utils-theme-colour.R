# Default colours for the plot builders that follow the theme a plot is drawn
# with. A colour passed to a layer as a literal parameter is fixed when the
# layer is constructed, so neither theme_mt(dark = TRUE) nor the dual-render
# overlay can change it. Mapping the colour through ggplot2's from_theme()
# defers the choice to build time, where the expression is evaluated against
# the properties of the active theme's `geom` element.

# Whether a theme's `ink` (its foreground colour) is light, i.e. whether the
# theme is meant for a dark background. theme_mt(dark = TRUE) and the
# dual-render overlay both set a light ink.
.is_dark_ink <- function(ink) {
  if (length(ink) != 1 || is.na(ink)) {
    return(FALSE)
  }
  channels <- grDevices::col2rgb(ink)[, 1] / 255
  sum(c(0.2126, 0.7152, 0.0722) * channels) > 0.5
}

.pick_by_ink <- function(ink, light, dark) {
  if (.is_dark_ink(ink)) dark else light
}

# Text colour for layer_bf_evidence_scale()'s weak-evidence label on a light
# page. mt_colors12[3] itself reaches only 2.74:1 against the shaded band the
# label sits on; this darker shade of the same hue reaches 4.75:1.
.weak_label_light <- "#9a5007"

# A colour specification for one aesthetic of a builder's layer: the caller's
# literal `value` as a layer parameter, or, if `value` is NULL, a mapping that
# picks `light` or `dark` from the theme at build time. Returns
# list(mapping = <aes>, params = <list>).
.colour_spec <- function(value, aesthetic, light, dark) {
  if (!is.null(value)) {
    return(list(mapping = aes(), params = stats::setNames(list(value), aesthetic)))
  }
  force(light)
  force(dark)
  mapping <- aes(colour = from_theme(.pick_by_ink(.data$ink, light, dark)))
  names(mapping) <- aesthetic
  list(mapping = mapping, params = list())
}

# Mapping for the theme's `paper`, used where a builder needs the page
# colour (outlines that separate a shape from what lies behind it).
.paper_aes <- function(aesthetic) {
  mapping <- aes(colour = from_theme(.data$paper))
  names(mapping) <- aesthetic
  mapping
}

# Combines aes() mappings, later ones winning, keeping the "uneval" class that
# layer() checks for (modifyList() would drop it).
.merge_aes <- function(...) {
  mappings <- list(...)
  out <- mappings[[1]] %||% aes()
  for (mapping in mappings[-1]) {
    for (name in names(mapping)) out[[name]] <- mapping[[name]]
  }
  out
}

# A layer drawn from its own data, ignoring the plot's mapping and legend, as
# annotate() builds one. annotate() takes its colours only as literal
# parameters, so the builders use this instead.
.annotation_layer <- function(geom, data, mapping, params = list()) {
  layer(
    geom = geom,
    stat = "identity",
    position = "identity",
    data = data,
    mapping = mapping,
    inherit.aes = FALSE,
    show.legend = FALSE,
    params = params
  )
}
