# This package reaches into two unexported upstream objects. These cheap
# existence checks make an upstream removal or rename show up as a failing CI
# run rather than as a user's plot failing. Verified against gghalves 0.1.4
# and ggplot2 4.0.3.

test_that("the upstream internals this package reaches into still exist", {
  # geom_half_violin_sd()/geom_split_violin_sd()'s density stat subclasses
  # this; gghalves exports no Stat hook the way ggplot2 does for StatYdensity
  expect_true(exists("StatHalfYdensity", envir = asNamespace("gghalves")))
  # StatHalfYdensitySD/StatYdensitySD$parameters() read a stat's own
  # compute_panel formals through this
  expect_true(exists("ggproto_formals", envir = asNamespace("ggplot2")))
})

test_that("the upstream internals are still the kind of object we use them as", {
  # An object that survives a rename but changes shape would pass the
  # existence check above and still break at use. These pin the one property
  # each call site actually depends on.
  expect_s3_class(gghalves:::StatHalfYdensity, "ggproto")
  expect_true(is.function(gghalves:::StatHalfYdensity$compute_panel))

  # ggproto_formals() must return something with names to setdiff() over
  formals_out <- ggplot2:::ggproto_formals(gghalves:::StatHalfYdensity$compute_panel)
  expect_false(is.null(names(formals_out)))
  expect_true(all(c("data", "scales") %in% names(formals_out)))
})

test_that("`scale` is why StatHalfYdensitySD overrides parameters() at all", {
  # The override exists because ggplot2's own fallback (compute_group's
  # formals, when compute_panel uses a bare `...`) never includes `scale` -
  # it's inherently panel-level. If a future ggplot2 changed that fallback,
  # or gghalves moved `scale`, the override would be quietly unnecessary or
  # quietly wrong; this pins the premise rather than leaving it as prose.
  panel_args <- names(ggplot2:::ggproto_formals(gghalves:::StatHalfYdensity$compute_panel))
  group_args <- names(ggplot2:::ggproto_formals(gghalves:::StatHalfYdensity$compute_group))
  expect_true("scale" %in% panel_args)
  expect_false("scale" %in% group_args)

  # ...and that the override really does surface it
  expect_true("scale" %in% StatHalfYdensitySD$parameters())
})
