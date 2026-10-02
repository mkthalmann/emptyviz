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

# Names that R CMD check reports as undefined globals but that are resolved at
# run time: `.value` is a default column name captured with ensym(), and
# `level` is computed by a stat (after_stat(level)).
utils::globalVariables(c(".value", "level"))

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
