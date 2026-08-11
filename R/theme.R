#' Base two-color palette
#'
#' The package's base discrete palette, and three extensions of it
#' (`mt_colors3`, `mt_colors4`, `mt_colors5`) with one, two, and three additional
#' hues appended. `theme_mt()` uses `mt_colors5` as its default discrete
#' palette (`palette.colour.discrete`/`palette.fill.discrete`).
#'
#' @examples
#' mt_colors
#' mt_colors5
#' @export
mt_colors <- c("#066b8a", "#8a064a")

#' @rdname mt_colors
#' @export
mt_colors3 <- c(mt_colors, "#d56f09")

#' @rdname mt_colors
#' @export
mt_colors4 <- c(mt_colors3, "#9109d5")

#' @rdname mt_colors
#' @export
mt_colors5 <- c(mt_colors4, "#142f8f")

#' Continuous color ramp between the first two base colors
#'
#' A [grDevices::colorRampPalette()] between `mt_colors[1]` and `mt_colors[2]`,
#' for continuous scales that want to match the discrete palette's hue.
#'
#' @param n Number of colors to generate.
#' @return A character vector of `n` hex colors.
#' @examples
#' mt_colors_many(5)
#' @export
mt_colors_many <- colorRampPalette(c(mt_colors[1], mt_colors[2]))

#' A markdown-aware ggplot2 theme
#'
#' Extends [ggplot2::theme_minimal()] with markdown/HTML-aware text (via
#' [ggtext::element_markdown()]) on every text element, a bottom legend, and
#' the package's discrete color palette ([mt_colors5]) wired into the theme
#' itself. Also sets `geom.*` defaults (a translucent global "paper" aura,
#' plus fill defaults for `geom_bar()`/`geom_area()`/`geom_col()`/
#' `geom_ribbon()`/`geom_density()`) so plots look consistent without
#' repeating `fill = ...` on every layer.
#'
#' Call [use_theme_mt()] to make this the session's active theme -
#' `library(emptyviz)` does not do this automatically.
#'
#' `base_family` (and every other `*_family` argument, which default to it)
#' defaults to `"Roboto Condensed"`, a font this package does not install or
#' register - it must already be present on the system (and discoverable by
#' the graphics device in use) for text to render as intended. If it isn't
#' installed, most graphics devices silently substitute a fallback font
#' rather than erroring, so a plot can look subtly different across machines
#' with no warning. Install it (e.g. via a system font manager, or
#' `sysfonts::font_add_google("Roboto Condensed")` + `showtext::showtext_auto()`
#' for device-independent rendering), or pass a `base_family` you know is
#' available, if reproducing a plot's exact appearance matters.
#'
#' @param base_size Base font size, in points.
#' @param base_family,plot_title_family,subtitle_family,strip_text_family,axis_title_family,axis_text_family,caption_family
#'   Font families for each text element; all default to `base_family`. See
#'   Details for the `"Roboto Condensed"` default's system requirement.
#' @param plot_title_size,axis_text_size,strip_text_size,subtitle_size,caption_size,axis_title_size
#'   Font sizes for each text element, all derived from `base_size` by
#'   default.
#' @param grid_color Color of the panel grid lines (and the axis line, when
#'   `show_axis_line` is `TRUE`).
#' @param show_axis_line Whether to draw the axis line at all (`TRUE`) or
#'   make it transparent (`FALSE`).
#' @param axis_text_color Color of the axis tick labels.
#'
#' @return A `ggplot2` theme object.
#' @seealso [use_theme_mt()]
#' @examples
#' library(ggplot2)
#' # a system-available family sidesteps the "Roboto Condensed" requirement
#' # described in Details, so this renders identically everywhere
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   theme_mt(base_family = "")
#' @export
theme_mt <- function(
  base_size = 19,
  base_family = "Roboto Condensed",
  plot_title_family = base_family,
  subtitle_family = base_family,
  strip_text_family = base_family,
  axis_title_family = base_family,
  axis_text_family = base_family,
  caption_family = base_family,
  plot_title_size = base_size + 2,
  axis_text_size = base_size,
  strip_text_size = base_size + 2,
  subtitle_size = base_size + 2,
  caption_size = base_size - 3,
  axis_title_size = base_size + 2,
  grid_color = "gray85",
  show_axis_line = TRUE,
  axis_text_color = "gray30"
) {
  theme_minimal(
    paper = alpha("white", .5),
    base_family = base_family,
    header_family = plot_title_family,
    base_size = base_size
  ) %+replace%
    theme(
      axis.line = element_line(
        color = if (show_axis_line) grid_color else "transparent",
        linewidth = 0.6
      ),
      axis.text.x = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(t = 0)
      ),
      axis.text.y = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(r = 0)
      ),
      # ggplot2 >= 4.0 resolves axis labels through position-suffixed
      # elements (e.g. axis.text.y.left) rather than axis.text.y/.x
      # directly. Its new S7 theme engine loses the element_markdown
      # subclass when inheriting into those (still S3-typed) slots, so
      # they must be set explicitly or markdown/HTML in axis text is
      # rendered as literal text. See ggplot2 combine_elements().
      axis.text.x.bottom = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(t = 0)
      ),
      axis.text.x.top = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(b = 0)
      ),
      axis.text.y.left = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(r = 0)
      ),
      axis.text.y.right = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(l = 0)
      ),
      axis.ticks = element_blank(),
      axis.ticks.x = element_blank(),
      axis.ticks.y = element_blank(),
      axis.title.x = element_markdown(
        hjust = 1,
        size = axis_title_size,
        family = axis_title_family,
        face = "plain"
      ),
      # see the axis.text.x.bottom/.top comment above - same S7
      # combine_elements() issue affects axis.title.x.top.
      axis.title.x.top = element_markdown(
        hjust = 1,
        size = axis_title_size,
        family = axis_title_family,
        face = "plain"
      ),
      axis.title.y = element_markdown(
        hjust = 1,
        vjust = 1.5,
        size = axis_title_size,
        angle = 90,
        family = axis_title_family,
        face = "plain"
      ),
      axis.title.y.right = element_markdown(
        hjust = 1,
        size = axis_title_size,
        angle = 90,
        family = axis_title_family,
        face = "plain"
      ),
      legend.background = element_blank(),
      legend.direction = "horizontal",
      legend.key = element_blank(),
      legend.key.size = unit(0.7, "cm"),
      legend.margin = margin(-base_size, 0, 0, 0, "pt"),
      legend.position = "bottom",
      legend.text = element_markdown(size = base_size + 2),
      legend.title = element_markdown(size = base_size + 2),
      panel.grid = element_line(color = grid_color, linewidth = 0.2),
      panel.grid.major = element_line(
        color = grid_color,
        linewidth = 0.2
      ),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_line(
        color = grid_color,
        linewidth = 0.1
      ),
      panel.grid.minor.x = element_blank(),
      panel.spacing = unit(1, "lines"),
      panel.spacing.y = unit(1, "lines"),
      plot.margin = margin(.1, .1, .1, .1, "lines"),
      plot.caption = element_markdown(
        hjust = 1,
        color = "gray50",
        size = caption_size,
        margin = margin(t = 10),
        family = caption_family,
        face = "plain"
      ),
      plot.subtitle = element_markdown(
        hjust = 0,
        size = subtitle_size,
        margin = margin(b = 10),
        color = "gray40",
        family = subtitle_family,
        face = "plain"
      ),
      plot.title = element_markdown(
        hjust = 0,
        size = plot_title_size,
        margin = margin(b = 5),
        family = plot_title_family,
        face = "bold"
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      strip.background = element_blank(),
      strip.placement = "outside",
      strip.text.x = element_markdown(
        margin = margin(),
        size = strip_text_size,
        face = "plain",
        family = strip_text_family
      ),
      strip.text.y = element_markdown(
        margin = margin(),
        size = strip_text_size,
        face = "plain",
        family = strip_text_family,
        angle = 270
      ),
      # see the axis.text.x.bottom/.top comment above - same S7
      # combine_elements() issue affects strip.text.y.left. angle = 90
      # (not 270) to match ggplot2's own left/right convention, so text
      # reads bottom-to-top on both sides of a facet_grid()/switch = "y"
      # plot instead of upside-down on the left.
      strip.text.y.left = element_markdown(
        margin = margin(),
        size = strip_text_size,
        face = "plain",
        family = strip_text_family,
        angle = 90
      ),
      # global geom-level "aura" (keeps your previous geom paper look)
      geom = element_geom(paper = alpha("white", 0.3)),
      geom.density = element_geom(
        fill = alpha(mt_colors[1], .5),
        color = NA
      ),
      geom.bar = element_geom(fill = mt_colors[1]),
      geom.area = element_geom(fill = mt_colors[1]),
      geom.col = element_geom(fill = mt_colors[1]),
      geom.ribbon = element_geom(fill = mt_colors[1]),
      geom.text = element_geom(family = base_family, fontsize = 5),
      geom.label = element_geom(family = base_family, fontsize = 5),
      # theme-level palettes (used by scales internally)
      palette.colour.discrete = mt_colors5,
      palette.fill.discrete = mt_colors5
    )
}

#' Activate `theme_mt()` as the session's default theme
#'
#' Calls [ggplot2::theme_set()] with `theme_mt(base_size = base_size)` and
#' sets `geom_density()`'s default `adjust` to 5 (a heavier smoothing
#' bandwidth than ggplot2's own default, matching how `geom_density()` is
#' used throughout this package's plots). Call this once per session/script
#' after `library(emptyviz)` - loading the package does not do this
#' automatically, since a package silently mutating global `ggplot2` state
#' on load is a bad default.
#'
#' @param base_size Passed to `theme_mt()`.
#' @return `invisible(NULL)`, called for its side effect.
#' @seealso [theme_mt()]
#' @examples
#' old <- ggplot2::theme_get() # so the example can restore it afterward
#' use_theme_mt()
#' ggplot2::theme_set(old) # not required in a real script/session
#' @export
use_theme_mt <- function(base_size = 10) {
  theme_set(theme_mt(base_size = base_size))
  update_geom_defaults("density", list(adjust = 5))
  invisible(NULL)
}
