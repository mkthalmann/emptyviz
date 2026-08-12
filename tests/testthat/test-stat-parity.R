# Signature-parity tests: StatYdensitySD/StatHalfYdensitySD are meant to
# accept every parameter their wrapped parent stat does, now and as
# ggplot2/gghalves evolve (see R/geom-violin-sd.R's own comments on
# StatYdensitySD/StatHalfYdensitySD for the mechanism - compute_panel()
# forwards `...` to the parent, and parameters() is overridden to read the
# parent's own compute_panel formals directly, sidestepping a gap where
# ggplot2's default introspection fallback loses `scale`, which is
# inherently panel-level and so never appears in compute_group()'s
# formals for any density stat). These tests are the concrete regression
# guard for that: if a future ggplot2/gghalves release adds, removes, or
# renames a stat_ydensity()/StatHalfYdensity parameter, this file should
# fail before a user discovers the gap by a silent "Ignoring unknown
# parameters" warning.

test_that("StatYdensitySD accepts every parameter StatYdensity itself does", {
  expect_setequal(StatYdensitySD$parameters(), StatYdensity$parameters())
})

test_that("StatHalfYdensitySD accepts every parameter gghalves:::StatHalfYdensity itself does", {
  expect_setequal(StatHalfYdensitySD$parameters(), gghalves:::StatHalfYdensity$parameters())
})

test_that("scale doesn't warn as an unknown parameter on the SD-band layers specifically", {
  # Regression test for the exact gap found during development: the naive
  # `...`-forwarding fallback (introspecting compute_group()'s formals)
  # doesn't include `scale`, so this would warn from the fill/outline
  # sub-layers (though not the aura, which uses the plain, unmodified
  # stat) without the parameters() override above.
  expect_no_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), scale = "count")
  )
  expect_no_warning(
    geom_half_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), scale = "count")
  )
})

test_that("drop/quantiles - added to stat_ydensity() after this file was first written - pass through without warning", {
  expect_no_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), drop = FALSE)
  )
  expect_no_warning(
    geom_violin_sd(data = sd_fixture, mapping = aes(x = grp, y = y), quantiles = c(0.25, 0.75))
  )
})
