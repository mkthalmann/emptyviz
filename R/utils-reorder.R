# Shared eager guard for the two plot builders that order their categorical
# axis with forcats::fct_reorder() (plot_ridge_hdi() via `category_reorder`,
# plot_bf_forest() via `contrast_reorder`).
#
# What actually fails, and why the check has to be per-category:
# fct_reorder() drops the rows whose ordering value is NA, then summarises
# what's left per level. When `.f` is a *character* vector - which is what
# both builders hand it, since they pass the raw category column straight
# through rather than pre-converting it to a factor - the levels are derived
# from the surviving rows, so any category left with no non-NA value simply
# disappears from the summary. forcats then calls lvls_reorder() with an
# index vector shorter than the level count and errors with "`idx` must
# contain one integer for each level of `f`" - a message naming a forcats
# internal the caller never invoked, raised deep inside ggplot2's aesthetic
# evaluation at build/print time rather than at the call to this package.
# (Confirmed against forcats 1.0.1. A *factor* `.f` behaves differently -
# fixed levels mean fct_reorder()'s `.default = Inf` fills the gap and it
# succeeds - which is why this is easy to miss when probing by hand.)
#
# An entirely-NA `value` is only the most extreme instance of that condition,
# not the condition itself: for plot_bf_forest(), where each contrast is a
# single row, "a category with no non-NA value" is just "any NA row". An
# earlier version of this guard tested `all(is.na(value))` and so passed
# through exactly the common case it existed to catch. Scattered NAs inside
# an otherwise-populated category are fine - forcats drops them (with its own
# message) and the level survives, so they're deliberately not flagged here.
#
# `values`/`categories` must be already-materialized, equal-length vectors
# (both call sites eval_tidy() them first). If either couldn't be resolved,
# the check is skipped rather than guessed at - a genuinely missing column
# has its own, clearer downstream error.
# `value_note` is appended after the value argument's name in both messages
# (e.g. " (after `value_transform`)"), for a caller whose ordering values
# aren't the raw column the user passed.
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
