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
capture_applied_sides <- function(p) {
  key <- paste0(".sd_capture_", as.integer(Sys.time()), "_", sample.int(1e6, 1))
  assign(key, list(), envir = globalenv())
  on.exit(rm(list = key, envir = globalenv()))

  GHV <- environment(gghalves::geom_half_violin)$GeomHalfViolin
  trace(
    what = "draw_group",
    where = GHV,
    tracer = bquote({
      .rows <- get(.(key), envir = globalenv())
      .rows[[length(.rows) + 1]] <- list(
        group = data$group[1],
        side = side[data$group[1]]
      )
      assign(.(key), .rows, envir = globalenv())
    }),
    print = FALSE
  )
  on.exit(untrace(what = "draw_group", where = GHV), add = TRUE)

  render_plot(p)
  dplyr::bind_rows(lapply(get(key, envir = globalenv()), as.data.frame))
}
