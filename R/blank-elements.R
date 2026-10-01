#' Hide theme elements together with everything that inherits from them
#'
#' With [theme_mt()], `theme(axis.text.y = element_blank())` does not hide
#' the y tick labels. ggplot2 (as of 4.0.3) resolves axis labels through the
#' position-specific children (`axis.text.y.left`, `axis.text.y.right`), and
#' a child only becomes blank with its parent if it has
#' `inherit.blank = TRUE`. `theme_mt()` has to set those children
#' explicitly with [ggtext::element_markdown()], or markdown would be drawn
#' as literal text, and ggplot2 ignores `inherit.blank` for such S3
#' elements. Blanking the parent therefore leaves them drawn.
#'
#' `blank_elements()` sidesteps this by blanking the named elements and all
#' of their descendants in ggplot2's element tree, so
#' `blank_elements("axis.text.y")` is the `theme_mt()` equivalent of
#' `theme(axis.text.y = element_blank())` under a built-in ggplot2 theme.
#' Native elements such as `panel.grid` or `axis.line` do not need it, since
#' a blank parent reaches them anyway, but they are accepted too.
#'
#' Because the descendants are blanked explicitly, a later
#' `theme(axis.text.y.left = element_markdown(...))` brings that one child
#' back, as it would under any theme.
#'
#' @param ... Names of theme elements, as character strings, e.g.
#'   `"axis.text.y"`, `"axis.title"` or `"strip.text"`.
#' @return A `ggplot2` theme object, to be added to a plot or theme.
#' @seealso [theme_mt()]
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   theme_mt(base_family = "") +
#'   blank_elements("axis.text.y", "axis.title.y")
#' @export
blank_elements <- function(...) {
  elements <- c(...)
  if (!is.character(elements) || length(elements) == 0) {
    stop("blank_elements(): pass one or more element names as strings.",
      call. = FALSE
    )
  }
  # Only drawn elements can be blanked. Settings such as `legend.position`
  # or `panel.spacing` are in the tree too, but with a plain class name, and
  # `geom` holds geom defaults rather than anything drawn.
  tree <- Filter(function(el) {
    inherits(el$class, "S7_class") && el$class@name != "element_geom"
  }, get_element_tree())
  unknown <- setdiff(elements, names(tree))
  if (length(unknown) > 0) {
    stop(
      "blank_elements(): not a theme element that can be blanked: ",
      paste0("`", unknown, "`", collapse = ", "), ".",
      call. = FALSE
    )
  }

  # Walk the tree downward: each pass adds every element that inherits from
  # one already collected, until a pass adds nothing new.
  parents <- lapply(tree, function(el) el$inherit)
  blanked <- unique(elements)
  repeat {
    children <- names(parents)[vapply(
      parents, function(p) any(p %in% blanked), logical(1)
    )]
    new <- setdiff(children, blanked)
    if (length(new) == 0) break
    blanked <- c(blanked, new)
  }

  do.call(theme, stats::setNames(
    rep(list(element_blank()), length(blanked)), blanked
  ))
}
