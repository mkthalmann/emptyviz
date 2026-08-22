# This package reaches into three unexported upstream objects. Each is
# documented at its call site with a version caveat, and .dark_mode_overlay()
# wraps its own in a tryCatch with a warning - but nothing asserted the
# objects still exist, so an upstream removal would surface as a user's plot
# crashing rather than as a red CI run. These are deliberately cheap
# existence checks, not behavioural ones: they are meant to fail loudly the
# first time a dependency update removes or renames something, which is when
# the version caveats in the comments need revisiting.
#
# Verified against gghalves 0.1.4 and ggplot2 4.0.3.

test_that("the upstream internals this package reaches into still exist", {
  # geom_half_violin_sd()/geom_split_violin_sd()'s density stat subclasses
  # this; gghalves exports no Stat hook the way ggplot2 does for StatYdensity
  expect_true(exists("StatHalfYdensity", envir = asNamespace("gghalves")))
  # StatHalfYdensitySD/StatYdensitySD$parameters() read a stat's own
  # compute_panel formals through this
  expect_true(exists("ggproto_formals", envir = asNamespace("ggplot2")))
  # .dark_mode_overlay() resolves a plot's full theme inheritance chain with
  # this, to leave deliberately-blanked elements blank
  expect_true(exists("plot_theme", envir = asNamespace("ggplot2")))
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

  # plot_theme() must return a theme calc_element() can resolve against
  resolved <- ggplot2:::plot_theme(ggplot(mtcars, aes(wt, mpg)) + geom_point())
  expect_s3_class(resolved, "theme")
  expect_no_error(calc_element("panel.grid", resolved))
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
