# Test files below use ggplot2/dplyr functions unqualified (ggplot(), aes(),
# theme(), group_by(), bind_rows(), ...) - both are already hard Imports of
# emptyviz itself, attached here purely for test-file convenience.
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

# Fixture with 3 groups deliberately NOT in alphabetical order, so any code
# that (re-)introduces the old side/group-order confusion between
# first-appearance order and ggplot's internal (sorted-factor-level) group
# order gets caught immediately.
sd_fixture <- (function() {
  set.seed(1)
  data.frame(
    grp = rep(c("c", "a", "b"), each = 30),
    y = rnorm(90)
  )
})()

# ggplot_build() alone doesn't execute Geom$draw_group() (grid drawing only
# happens on render), which is where gghalves resolves `side` against the
# real internal group ids. Some regressions (e.g. the side/group-order bug)
# are only observable by actually rendering. Route through pdf(NULL) to
# render without a display and without writing a file, and silence the
# unrelated "font family not found" warnings this machine's PostScript
# device emits for fonts not installed in the CI/dev environment.
render_plot <- function(p) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  withCallingHandlers(
    grid::grid.draw(ggplot2::ggplotGrob(p)),
    warning = function(w) {
      if (grepl("font family", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )
  invisible(TRUE)
}

# Counts how many separate legend boxes ggplot2 actually rendered - the
# ground truth for "did two aesthetics mapped to the same variable merge
# into one legend, or stay split apart". Each guide-box-* cell in the
# built gtable is itself a gtable whose rows are named "guides", one per
# rendered legend; two rows there means two visually separate legends even
# if their titles happen to look similar.
n_legend_boxes <- function(p) {
  gt <- ggplot2::ggplotGrob(p)
  box_idx <- grep("^guide-box", gt$layout$name)
  sum(vapply(box_idx, function(i) {
    g <- gt$grobs[[i]]
    if (inherits(g, "gtable")) sum(g$layout$name == "guides") else 0L
  }, integer(1)))
}

# All text drawn inside the guide-box area (legend titles and key labels
# together) - used to check which strings actually made it into a
# legend's title, without depending on ggplot2-internal guide/title grob
# naming that might shift across versions.
legend_texts <- function(p) {
  gt <- ggplot2::ggplotGrob(p)
  box_idx <- grep("^guide-box", gt$layout$name)
  find_text <- function(g) {
    out <- character(0)
    if (inherits(g, "text")) out <- c(out, as.character(g$label))
    if (!is.null(g$children)) for (ch in g$children) out <- c(out, find_text(ch))
    if (inherits(g, "gtable")) for (gr in g$grobs) out <- c(out, find_text(gr))
    out
  }
  unique(unlist(lapply(gt$grobs[box_idx], find_text)))
}

# Records, for each internal draw group, which `side` gghalves actually
# applied — the ground truth for side-assignment regression tests.
#
# trace()'s tracer expression executes inside draw_group()'s own execution
# frame, whose lexical parent is the gghalves package namespace, not this
# function's frame — so a plain `<<-` into a local variable here can't
# reach it (confirmed: it raises "object not found" rather than silently
# writing to the wrong scope). Route through an explicit global-environment
# accumulator instead, which is safe: draw_group() can reach it because
# `assign()`/`get()`/`globalenv()` are base functions, resolvable from any
# package namespace regardless of lexical scoping, and we always know the
# exact key we stashed it under.
#
# Traces BOTH gghalves::GeomHalfViolin$draw_group (the aura and SD-fill
# sub-layers, which now construct as emptyviz:::GeomHalfViolinSD - a thin
# subclass overriding only setup_params(), for the thin-cell/side-recycling
# fix documented on that ggproto - and inherit draw_group() unchanged, so
# the function object actually executing is still the one bound on
# GeomHalfViolin itself) AND emptyviz:::GeomHalfViolinOutline$draw_group
# (the SD-band outline sub-layer, a separate ggproto subclassing
# GeomHalfViolinSD in turn - see R/geom-violin-sd.R's own comments) -
# tracing only the former would silently stop covering the outline layer's
# own `side` resolution.
#
# GeomHalfViolinOutline$draw_group itself calls
# ggproto_parent(GeomHalfViolinSD, self)$draw_group(...) internally (to do
# the actual half-violin geometry, after nulling fill), which resolves to
# that same GeomHalfViolin-bound draw_group() - so without the
# class(self)[1] guard below, tracing both classes would double-count every
# outline draw: once at the outline's own entry, once again when it
# delegates into the (also traced) parent method, since `self` keeps
# referring to the original GeomHalfViolinOutline instance throughout, even
# while executing inherited parent code.
capture_applied_sides <- function(p) {
  key <- paste0(".sd_capture_", as.integer(Sys.time()), "_", sample.int(1e6, 1))
  assign(key, list(), envir = globalenv())
  on.exit(rm(list = key, envir = globalenv()))

  tracer_for <- function(expected_class) {
    bquote({
      if (identical(class(self)[1], .(expected_class))) {
        .rows <- get(.(key), envir = globalenv())
        .rows[[length(.rows) + 1]] <- list(
          group = data$group[1],
          side = side[data$group[1]]
        )
        assign(.(key), .rows, envir = globalenv())
      }
    })
  }

  half_violin_geom <- environment(gghalves::geom_half_violin)$GeomHalfViolin
  trace(what = "draw_group", where = half_violin_geom, tracer = tracer_for("GeomHalfViolinSD"), print = FALSE)
  on.exit(untrace(what = "draw_group", where = half_violin_geom), add = TRUE)

  half_violin_outline_geom <- emptyviz:::GeomHalfViolinOutline
  trace(what = "draw_group", where = half_violin_outline_geom, tracer = tracer_for("GeomHalfViolinOutline"), print = FALSE)
  on.exit(untrace(what = "draw_group", where = half_violin_outline_geom), add = TRUE)

  render_plot(p)
  dplyr::bind_rows(lapply(get(key, envir = globalenv()), as.data.frame))
}

# WCAG 2.x relative-luminance contrast ratio between two colors, per
# https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio. Used by the palette and
# dark-mode tests to state contrast claims as numbers rather than prose -
# the specific habit finding #14 of the code review asked for.
wcag_contrast <- function(a, b) {
  relative_luminance <- function(hex) {
    channels <- grDevices::col2rgb(hex)[, 1] / 255
    linear <- ifelse(
      channels <= 0.03928,
      channels / 12.92,
      ((channels + 0.055) / 1.055)^2.4
    )
    sum(c(0.2126, 0.7152, 0.0722) * linear)
  }
  lums <- c(relative_luminance(a), relative_luminance(b))
  (max(lums) + 0.05) / (min(lums) + 0.05)
}
