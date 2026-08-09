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
# well-known tidyeval false positive.
utils::globalVariables(c(".value", "level"))
