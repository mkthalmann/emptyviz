#' Base two-color palette
#'
#' The package's base discrete palette, and four extensions of it
#' (`mt_colors3`, `mt_colors4`, `mt_colors5`, `mt_colors12`) with one, two,
#' three, and ten additional hues appended. `theme_mt()` uses `mt_colors12`
#' as its default discrete palette
#' (`palette.colour.discrete`/`palette.fill.discrete`).
#'
#' @examples
#' mt_colors
#' mt_colors5
#' mt_colors12
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

#' @rdname mt_colors
#' @export
mt_colors12 <- c(
  mt_colors5,
  "#e40add", "#ea280a", "#6e4cf8", "#068a7f", "#b30732", "#ac8307", "#064d8c"
)

#' Dark-mode variant of the base palette
#'
#' Lightened tints of
#' [mt_colors]/[mt_colors3]/[mt_colors4]/[mt_colors5]/[mt_colors12], each
#' hue's HSL lightness raised to keep adequate contrast against a near-black
#' background. Used by `theme_mt(dark = TRUE)` as the discrete palette and
#' geom fill defaults; exported separately so the same tints can be reused
#' directly (e.g. in a hand-written `scale_color_manual()`) without
#' re-deriving them. `dark_mt_colors12[i]` is the dark counterpart of
#' `mt_colors12[i]` at every position.
#'
#' @examples
#' dark_mt_colors
#' dark_mt_colors5
#' dark_mt_colors12
#' @export
dark_mt_colors <- c("#70ceeb", "#eb70af")

#' @rdname dark_mt_colors
#' @export
dark_mt_colors3 <- c(dark_mt_colors, "#ebad70")

#' @rdname dark_mt_colors
#' @export
dark_mt_colors4 <- c(dark_mt_colors3, "#c270eb")

#' @rdname dark_mt_colors
#' @export
dark_mt_colors5 <- c(dark_mt_colors4, "#7b91e0")

#' @rdname dark_mt_colors
#' @export
dark_mt_colors12 <- c(
  dark_mt_colors5,
  "#e755e2", "#e76855", "#9f8bef", "#8befe6", "#ef8ba4", "#efd68b", "#55a3e7"
)

# Non-palette dark-mode colors (ink/grid/text), shared between
# theme_mt(dark = TRUE) and the color-only overlay in R/dual-render.R so the
# two can't drift out of sync. Not exported - `dark_mt_colors12` is the
# public-facing constant; these are text/line tints, not the data palette.
# grid/axis_line are deliberately two different brightnesses (measured
# contrast 1.19:1 and 3.14:1 against the #151515 page background
# respectively) - grid lines should stay a barely-there hint, while the axis
# line is a real boundary and reads as too faint at the same brightness as
# the grid.
#
# The axis line is a meaningful graphical object, so it meets the 3:1 floor
# of WCAG 1.4.11; the grid is decorative and stays well below it.
.dark_ink <- "#e4e4e4"
.dark_grid <- "#22252a"
.dark_axis_line <- "#5f666e"
.dark_axis_text <- "#d3d7da"
.dark_subtitle <- "#c8ccd0"
.dark_caption <- "#9aa0a6"

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
#' the package's color palettes ([mt_colors12] for discrete scales, a
#' lightness ramp of `mt_colors[1]` for continuous ones) wired into the
#' theme itself. Also sets `geom.*` defaults (an opaque "paper" for
#' label backgrounds, plus fill defaults for `geom_bar()`/`geom_area()`/
#' `geom_col()`/`geom_ribbon()`/`geom_density()`) so plots look consistent
#' without repeating `fill = ...` on every layer.
#'
#' Call [use_theme_mt()] to make this the session's active theme -
#' `library(emptyviz)` does not do this automatically.
#'
#' Only the title stands above the rest of the type scale, at
#' `base_size + 4`. Subtitle, strip text and axis titles are `base_size + 1`,
#' tick labels and legend text `base_size`, and the caption `base_size - 2`.
#' Every size is an argument.
#'
#' Margins, legend keys and the gap between panel and legend are sized off
#' `base_size`, so they scale with the type. The plot margin is wider on the
#' right and top, where the right-aligned axis titles and the title would
#' otherwise touch the device edge.
#'
#' Minor gridlines are off by default (`minor_grid`): at `linewidth = 0.1`
#' they are about 0.1 mm, which is where print workflows stop guaranteeing
#' a line, and they double the grid's ink without adding information.
#'
#' `dark = TRUE` is tuned for a page background of about `#151515`. It sets
#' `paper = NA` and a transparent `plot.background`, deliberately - the
#' figure then sits directly on whatever the host page uses, which is what
#' makes a Quarto light/dark toggle work without re-rendering. The
#' consequence is that the *real* background is the host's, not this
#' theme's, and every contrast decision in dark mode is made against
#' `#151515`: the grid line at 1.19:1, the axis line at 3.14:1, the ink at
#' 14.4:1. Nothing validates the assumption, and a host theme at, say,
#' `#2b2b2b` or `#1e1e2e` shifts all three - far enough that the
#' near-invisible grid could invert against a light-ish "dark" background.
#' If your site's dark background differs much from `#151515`, either match
#' it or pass `grid_color`/`axis_text_color`/`axis_line_color` explicitly.
#' `geom.paper` follows the same assumption: it is that same `#151515`, so
#' a `geom_label()` on a dark page has an opaque background. The default
#' colours of this package's plot builders ([plot_bf_forest()],
#' [plot_ridge_hdi()], ...) follow the theme as well: under a dark theme
#' they switch from [mt_colors12] to the matching [dark_mt_colors12] tints.
#'
#' The discrete palette separates categories by **hue**, with very little
#' lightness difference between them: every pair in [mt_colors5] falls below
#' the 3:1 WCAG 1.4.11 contrast threshold for distinguishable graphical
#' objects, and eight of the ten pairs below 2:1 (teal `#066b8a` and purple
#' `#9109d5` sit at 1.09:1 - effectively the same shade of gray). Each color
#' has adequate contrast against a white background, so text and outlines
#' are fine; the limitation is strictly category-vs-category. Under
#' grayscale printing, a monochrome projector, or reduced color
#' discrimination, categories can merge. Beyond about three categories, give
#' the plot a redundant non-color channel - `shape`, `linetype`, or direct
#' labels - rather than relying on hue alone. [plot_location_scale()] does
#' this by default (see its `category_shape`/`category_linetype`), and
#' [plot_bf_forest()]'s `positive_shape`/`negative_shape` are the same idea.
#'
#' [mt_colors12]'s first five positions are [mt_colors5], so plots with five
#' or fewer categories are unaffected by the extension to twelve. The
#' advice above applies with more force past five categories, not less:
#' the worst pair sits at 1.02:1 against [mt_colors5]'s 1.09:1.
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
#' @section Hiding elements:
#' Native elements (lines, rectangles, plain text) are hidden the usual
#' way: `theme(panel.grid = element_blank())` also hides
#' `panel.grid.major.y`, as under ggplot2's built-in themes. The markdown
#' text elements are an exception. ggplot2 4 draws axis labels through the
#' position-specific children (`axis.text.y.left`, `axis.text.x.bottom`,
#' ...), which this theme has to set explicitly with
#' [ggtext::element_markdown()], and ggplot2 ignores `inherit.blank` for
#' such elements. `theme(axis.text.y = element_blank())` therefore leaves
#' the y tick labels drawn. Use [blank_elements()] instead, which blanks an
#' element together with all of its children, or blank the
#' position-specific child directly. The same applies to `strip.text` and
#' its children, to the parent `axis.title`, and to the secondary-axis
#' titles (`axis.title.x.top`, `axis.title.y.right`). Blanking
#' `axis.title.x`, `axis.title.y`, `legend.text` or `legend.title` directly
#' works as usual.
#'
#' @param base_size Base font size, in points. Every other size argument
#'   derives from it by default. [use_theme_mt()] has the same default.
#' @param base_family,plot_title_family,subtitle_family,strip_text_family,axis_title_family,axis_text_family,caption_family
#'   Font families for each text element; all default to `base_family`. See
#'   Details for the `"Roboto Condensed"` default's system requirement.
#' @param plot_title_size,axis_text_size,strip_text_size,subtitle_size,caption_size,axis_title_size,legend_text_size
#'   Font sizes for each text element, all derived from `base_size` by
#'   default. See Details for how the scale is laid out. `legend_text_size`
#'   covers both `legend.text` and `legend.title`.
#' @param grid_color Color of the panel grid lines, and of the axis line
#'   unless `axis_line_color` says otherwise. Defaults to a near-invisible
#'   light gray, or a near-invisible dark gray when `dark = TRUE`.
#' @param minor_grid Whether to draw minor gridlines (on the major axis
#'   only, matching the major grid). `FALSE` by default. See Details.
#' @param background Fill for `plot.background` in light mode: `"white"`
#'   (the default), `"transparent"`, or any opaque color. A semi-transparent
#'   fill would tint whatever page the figure is placed on. With
#'   `dark = TRUE` the background is always transparent; see Details.
#' @param axis_text_color Color of the axis tick labels. Defaults to a dark
#'   gray, or a light gray when `dark = TRUE`.
#' @param axis_line_color Color of the axis line, which is always drawn.
#'   Defaults to `grid_color` in light mode; in dark mode it defaults to
#'   something brighter than `grid_color`, since the axis line is a real
#'   boundary (drawn thicker than the grid) and reads as too faint at the
#'   grid's own brightness.
#' @param continuous_palette Colors for continuous `colour`/`fill` scales,
#'   as the two ends of a ramp. Defaults to a lightness ramp of
#'   `mt_colors[1]` (or of `dark_mt_colors[1]` when `dark = TRUE`) - a
#'   single-hue sequential scale in the palette's own teal, running from
#'   light (low values) to dark (high values). `NULL` leaves ggplot2's own
#'   default gradient.
#' @param dark Build a dark-mode-appropriate variant instead: transparent
#'   plot/panel background (rather than the opaque white "paper" used in
#'   light mode), light text/gridline/ink colors, and [dark_mt_colors12]
#'   in place of [mt_colors12] as the discrete palette and geom fill default.
#'   Meant for rendering the same plot a second time for a dark-themed page,
#'   alongside a `dark = FALSE` (default) render for the light-themed page.
#'   `grid_color`/`axis_text_color`/`axis_line_color`/`background`/
#'   `continuous_palette` still default off of `dark` but can be overridden
#'   individually either way.
#'
#' @return A `ggplot2` theme object.
#' @seealso [use_theme_mt()], [blank_elements()]
#' @examples
#' library(ggplot2)
#' # a system-available family sidesteps the "Roboto Condensed" requirement
#' # described in Details, so this renders identically everywhere
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   theme_mt(base_family = "")
#' @export
theme_mt <- function(
  base_size = 10,
  base_family = "Roboto Condensed",
  plot_title_family = base_family,
  subtitle_family = base_family,
  strip_text_family = base_family,
  axis_title_family = base_family,
  axis_text_family = base_family,
  caption_family = base_family,
  # The type scale; see Details.
  plot_title_size = base_size + 4,
  axis_text_size = base_size,
  strip_text_size = base_size + 1,
  subtitle_size = base_size + 1,
  # 8pt at the default base_size; 7pt would fall below the readable minimum
  # once a journal reduces a 6-inch figure to a 3.3-inch column.
  caption_size = base_size - 2,
  axis_title_size = base_size + 1,
  legend_text_size = base_size,
  dark = FALSE,
  minor_grid = FALSE,
  background = if (dark) "transparent" else "white",
  grid_color = if (dark) .dark_grid else "gray87",
  axis_text_color = if (dark) .dark_axis_text else "gray30",
  axis_line_color = if (dark) .dark_axis_line else grid_color,
  continuous_palette = if (dark) {
    c("#13414f", dark_mt_colors[1])
  } else {
    c("#b7d4e0", mt_colors[1])
  }
) {
  ink <- if (dark) .dark_ink else "black"
  paper <- if (dark || identical(background, "transparent")) NA else background
  subtitle_color <- if (dark) .dark_subtitle else "gray40"
  # gray45 measures 4.74:1 against white: the caption is the smallest text in
  # the figure, so it still meets the 4.5:1 text minimum.
  caption_color <- if (dark) .dark_caption else "gray45"
  geom_fill <- if (dark) dark_mt_colors[1] else mt_colors[1]
  # geom_label() takes its fill from `geom.paper` (ggplot2 >= 4). It is
  # opaque so that marks behind a label do not show through the text. Dark
  # mode uses the #151515 page colour it is tuned for; .dark_mode_overlay()
  # in R/dual-render.R mirrors this.
  geom_paper <- if (dark) "#151515" else "white"
  # A continuous colourbar has no edges against the page. Recessive enough
  # not to compete with the ramp it frames, dark enough to survive print.
  legend_frame_color <- if (dark) .dark_axis_line else "gray70"
  discrete_palette <- if (dark) dark_mt_colors12 else mt_colors12
  # Gap between the tick labels and the axis line, in points.
  axis_text_gap <- 4

  minor_line <- if (minor_grid) {
    element_line(color = grid_color, linewidth = 0.1)
  } else {
    element_blank()
  }

  theme_minimal(
    ink = ink,
    paper = paper,
    base_family = base_family,
    header_family = plot_title_family,
    base_size = base_size
  ) %+replace%
    theme(
      axis.line = element_line(color = axis_line_color, linewidth = 0.6),
      axis.text.x = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(t = axis_text_gap)
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
        margin = margin(t = axis_text_gap)
      ),
      axis.text.x.top = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(b = axis_text_gap)
      ),
      axis.text.y = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(r = axis_text_gap)
      ),
      axis.text.y.left = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(r = axis_text_gap)
      ),
      axis.text.y.right = element_markdown(
        size = axis_text_size,
        color = axis_text_color,
        family = axis_text_family,
        margin = margin(l = axis_text_gap)
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
      # Keys scale with the legend text they sit beside.
      legend.key.size = unit(base_size * 1.1, "pt"),
      legend.key.spacing.x = unit(base_size * 0.7, "pt"),
      # The gap between panel and legend is set by legend.box.spacing; a
      # negative legend.margin would clip the top of the legend.
      legend.margin = margin(0, 0, 0, 0),
      legend.box.spacing = unit(base_size * 0.6, "pt"),
      legend.position = "bottom",
      legend.text = element_markdown(size = legend_text_size),
      legend.title = element_markdown(size = legend_text_size),
      # A colourbar drawn straight onto the page has no edges. Ticks off,
      # hairline frame on - see legend_frame_color above.
      legend.ticks = element_blank(),
      legend.frame = element_rect(colour = legend_frame_color, linewidth = 0.3),
      panel.grid = element_line(color = grid_color, linewidth = 0.25),
      panel.grid.major = element_line(
        color = grid_color,
        linewidth = 0.25
      ),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = minor_line,
      panel.grid.minor.x = element_blank(),
      panel.grid.minor.y = minor_line,
      panel.spacing = unit(1, "lines"),
      panel.spacing.y = unit(1, "lines"),
      # Wider on the right and top, where the right-aligned x-axis title,
      # the last tick label and the title would otherwise reach the device
      # edge.
      plot.margin = margin(
        t = base_size * 0.5,
        r = base_size * 0.7,
        b = base_size * 0.4,
        l = base_size * 0.4,
        unit = "pt"
      ),
      plot.caption = element_markdown(
        hjust = 1,
        color = caption_color,
        size = caption_size,
        margin = margin(t = base_size * 1.2),
        family = caption_family,
        face = "plain"
      ),
      plot.subtitle = element_markdown(
        hjust = 0,
        size = subtitle_size,
        margin = margin(b = base_size * 1.2),
        color = subtitle_color,
        family = subtitle_family,
        face = "plain"
      ),
      plot.title = element_markdown(
        hjust = 0,
        size = plot_title_size,
        margin = margin(b = base_size * 0.5),
        family = plot_title_family,
        face = "bold"
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      # patchwork panel letters (plot_annotation(tag_levels = "A")) had no
      # style here at all, so they fell back to ggplot2's grey
      # 1.2 * base_size default and landed on top of the y-axis. Matching
      # the title, and anchored to the plot rather than the panel, the way
      # plot.title.position = "plot" already anchors the title.
      plot.tag = element_markdown(
        size = plot_title_size,
        face = "bold",
        color = ink,
        family = plot_title_family,
        hjust = 0
      ),
      plot.tag.position = "topleft",
      strip.background = element_blank(),
      strip.placement = "outside",
      # With strip.placement = "outside", these margins keep a facet label
      # off the panel it labels.
      strip.text.x = element_markdown(
        margin = margin(t = base_size * 0.2, b = base_size * 0.5),
        size = strip_text_size,
        face = "plain",
        family = strip_text_family
      ),
      strip.text.y = element_markdown(
        margin = margin(l = base_size * 0.5, r = base_size * 0.2),
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
        margin = margin(l = base_size * 0.5, r = base_size * 0.2),
        size = strip_text_size,
        face = "plain",
        family = strip_text_family,
        angle = 90
      ),
      # global geom-level "paper" (see geom_paper above), plus the geom
      # `ink` the default colour of every unmapped geom is resolved from.
      # `ink` has to be set on this element specifically: theme_minimal()'s
      # own `ink` argument (passed above) only colors *text/line theme
      # elements*, not geom defaults, so leaving it out left geom.ink at
      # ggplot2's factory "black" even in dark mode - geom_point()/
      # geom_line()/geom_text() then drew black-on-black on a dark page.
      # Light mode's ink is "black" anyway, so setting it here explicitly
      # is a no-op there.
      geom = element_geom(paper = geom_paper, ink = ink),
      geom.density = element_geom(
        fill = alpha(geom_fill, .5),
        color = NA
      ),
      geom.bar = element_geom(fill = geom_fill),
      geom.area = element_geom(fill = geom_fill),
      geom.col = element_geom(fill = geom_fill),
      geom.ribbon = element_geom(fill = geom_fill),
      # `fontsize` is in points: geom text and labels are set at base_size,
      # the size of the tick labels by default.
      geom.text = element_geom(family = base_family, fontsize = base_size),
      geom.label = element_geom(family = base_family, fontsize = base_size),
      # theme-level palettes (used by scales internally)
      palette.colour.discrete = discrete_palette,
      palette.fill.discrete = discrete_palette,
      palette.colour.continuous = continuous_palette,
      palette.fill.continuous = continuous_palette,
      # Without this every element above keeps the constructor default
      # inherit.blank = FALSE, so e.g. `theme(panel.grid = element_blank())`
      # could not reach the panel.grid.major set here. ggplot2's own themes
      # are built the same way. It does not help the element_markdown
      # children; see the "Hiding elements" section of the docs.
      complete = TRUE
    )
}

#' Activate `theme_mt()` as the session's default theme
#'
#' Calls [ggplot2::theme_set()] with `theme_mt(base_size = base_size)`. Call
#' this once per session/script after `library(emptyviz)` - loading the
#' package does not do this automatically, since a package silently mutating
#' global `ggplot2` state on load is a bad default.
#'
#' It changes no geom defaults. For heavier density smoothing, pass `adjust`
#' to `geom_density()`/`stat_density()` directly.
#'
#' If `knitr` is installed, this also registers a `knit_print` method for
#' `ggplot`/`patchwork` objects that renders a chunk twice - once normally,
#' once with a dark-mode color overlay - whenever that chunk sets the
#' `dual_render` chunk option to `TRUE` (directly, or via a project-wide
#' `knitr: opts_chunk: dual_render: true` default), emitting both images
#' wrapped for Quarto's light/dark toggle. This applies only to HTML output
#' rendered by Quarto. For PDF or Word output, figures are rendered normally;
#' for HTML not rendered by Quarto they are too, with a warning. Chunks
#' that don't set the option are unaffected. Pass `dual_render = FALSE` to
#' leave knitr's printing of ggplot objects untouched; this also removes the
#' method if an earlier call registered it.
#'
#' A dual-rendered chunk's `fig.alt` becomes the alt text of both images. A
#' `fig.cap` is shown as plain text: markdown and math in it are not
#' rendered, unless the chunk has a `fig-` label, in which case Quarto
#' captions the figure itself.
#'
#' @param base_size Passed to `theme_mt()`, whose own default is the same
#'   value.
#' @param ... Passed to `theme_mt()` as well - e.g. `base_family` or `dark`,
#'   for callers that want an activated theme other than the plain default.
#' @param dual_render Whether to register the dual light/dark `knit_print`
#'   method described in Details (default `TRUE`).
#' @return `invisible(NULL)`, called for its side effect.
#' @seealso [theme_mt()]
#' @examples
#' old <- ggplot2::theme_get() # so the example can restore it afterward
#' use_theme_mt()
#' ggplot2::theme_set(old) # not required in a real script/session
#' @export
use_theme_mt <- function(base_size = 10, ..., dual_render = TRUE) {
  theme_set(theme_mt(base_size = base_size, ...))
  if (isTRUE(dual_render)) {
    .register_dual_render()
  } else {
    .unregister_dual_render()
  }
  invisible(NULL)
}
