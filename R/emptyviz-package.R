#' @keywords internal
#' @import ggplot2
#' @importFrom ggtext element_markdown
#' @importFrom scales alpha
#' @importFrom gghalves geom_half_violin
#' @importFrom dplyr group_by summarise filter ungroup bind_rows
#' @importFrom rlang %||% .data
#' @importFrom stats sd
#' @importFrom grDevices colorRampPalette
#' @importFrom grid unit
#' @importFrom utils globalVariables
"_PACKAGE"

# `.value` (a bare default-argument symbol standing for an assumed column
# name, captured unevaluated via rlang::ensym() - see plot_ridge_hdi()/
# plot_coef_grid_hdi()) and `level` (a stat-computed column referenced via
# after_stat(level) in layer_halfeye_hdi()) are both genuinely resolved at
# runtime through tidy evaluation, not global variables - but neither is
# visible to R CMD check's static analysis, which flags both as "no visible
# binding for global variable". This is the standard appeasement for that
# well-known tidyeval false positive. `group`/`y`/`n` are the same story for
# .sd_bounds()'s own group_by(group)/summarise(n=, ...) pipe (both are
# columns present in a StatYdensitySD/StatHalfYdensitySD compute_panel()'s
# `data` at runtime, not globals) - only flagged once that pipe became a
# standalone top-level function; the identical pipe inline inside a
# ggproto()-nested closure wasn't flagged by the same static analysis.
utils::globalVariables(c(".value", "level", "group", "y", "n"))

# gghalves is NOT on CRAN: it was archived on 2025-12-04 ("issues were not
# corrected despite reminders"), so install.packages()/pak can no longer
# resolve it from a CRAN mirror and DESCRIPTION's `Remotes:` pin on
# erocoar/gghalves is load-bearing, not a leftover from development. Do not
# drop it without checking https://cran.r-project.org/package=gghalves
# first. The pinned SHA is the last 0.1.4 commit, which is what the
# `gghalves (>= 0.1.4)` bound in Imports refers to.
#
# This note lives here rather than in DESCRIPTION because DCF has no comment
# syntax. read.dcf() does skip lines starting with #, which is why R CMD
# build tolerated them, but pak resolves the source tree with pkgdepends'
# own stricter parser: a `# ...:` line reads as a field name, the next
# `#` line is neither a new field nor an indented continuation, and
# dependency resolution dies with "Line ... is malformed!" before any
# checking runs. That took out the oldrel-1 CI job on 2026-08-22.
