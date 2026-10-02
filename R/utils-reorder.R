# Checks, before the plot is built, the values plot_ridge_hdi() and
# plot_bf_forest() order their categorical axis by with forcats::fct_reorder().
# When `.f` is a character vector, fct_reorder() drops rows whose value is NA
# and derives the levels from what remains. A category with no non-NA value
# then has no level, and forcats fails at build time with "`idx` must contain
# one integer for each level of `f`", an error that names neither the builder
# nor its argument. The condition is per category: for plot_bf_forest(), with
# one row per contrast, any NA row triggers it. Scattered NAs within a
# category are dropped by forcats and are not flagged.
#
# `values` and `categories` are evaluated, equal-length vectors; if either
# could not be evaluated, the check is skipped and the missing column fails
# with its own error later. `value_note` follows the argument name in the
# message, e.g. " (after `value_transform`)".
.check_reorder_values <- function(values, categories, fn, value_arg,
                                  reorder_arg, value_note = "") {
  if (is.null(values) || is.null(categories) ||
        length(values) != length(categories)) {
    return(invisible(NULL))
  }

  reorder_hint <- paste0("pass `", reorder_arg, " = FALSE`")

  if (all(is.na(values))) {
    stop(
      fn, "(): `", value_arg, "`", value_note, " is entirely NA - ",
      "forcats::fct_reorder() ",
      "can't order by it. Check your data, or ", reorder_hint, ".",
      call. = FALSE
    )
  }

  empty <- tapply(values, as.character(categories), function(v) all(is.na(v)))
  bad <- names(empty)[!is.na(empty) & empty]
  if (length(bad) > 0) {
    stop(
      fn, "(): ",
      if (length(bad) == 1) "category " else "categories ",
      paste(sQuote(bad, q = FALSE), collapse = ", "),
      if (length(bad) == 1) " has " else " have ",
      "no non-NA `", value_arg, "`", value_note,
      " - forcats::fct_reorder() can't order by ",
      if (length(bad) == 1) "it. " else "them. ",
      "Drop those rows, or ", reorder_hint, ".",
      call. = FALSE
    )
  }

  invisible(NULL)
}
