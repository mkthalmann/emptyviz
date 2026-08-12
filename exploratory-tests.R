# exploratory-tests.R
#
# NOT a testthat file - a human-run, human-reviewed exploratory script for
# emptyviz. Run it section by section (RStudio "Run Section" / manually
# selecting a `# ==== N. ... ====` block), inspect each plot visually, and
# report back per section as one of:
#   - BUG: something clearly broken (unexpected error, visibly wrong output).
#   - ROUGH EDGE: works, but surprising, easy to misuse, or worth smoothing
#     over in a future release.
#   - SPEC GAP: current behavior is defensible but undocumented, or a
#     combination of arguments has no clearly "right" answer yet.
#
# Do NOT `Rscript` this end-to-end as your primary way of using it - some
# sections deliberately loop/tryCatch through many small plots meant to be
# inspected one at a time. (A full end-to-end `source()` is still useful as
# a one-time smoke test that nothing throws an unintended hard error - see
# the PR/commit history for that check.)
#
# Sections are self-contained: real-data helper functions are called fresh
# wherever needed instead of relying on a variable set by an earlier
# section, so you can run sections out of order.

# ==== 1. SETUP ====

if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all(quiet = TRUE)
} else {
  library(emptyviz)
}
library(ggplot2)
library(dplyr)
library(forcats)
library(tidyr)
library(gghalves)
library(scales)
library(patchwork)

stopifnot(utils::packageVersion("ggplot2") >= "4.0.0")
cat("ggplot2 version:", as.character(utils::packageVersion("ggplot2")), "\n")

use_theme_mt()

## ---- font resolution probe (see also Section 23) ----
installed_families <- if (requireNamespace("systemfonts", quietly = TRUE)) {
  fonts <- systemfonts::match_fonts("Roboto Condensed")
  cat("systemfonts::match_fonts('Roboto Condensed') resolved to:\n")
  print(fonts[, intersect(c("family", "path"), names(fonts))])
  unique(systemfonts::system_fonts()$family)
} else {
  message("systemfonts not installed - skipping the font-resolution probe.")
  character(0)
}
cat(
  "NOTE: this signal is necessarily incomplete - font resolution is",
  "per-device. A base pdf()/postscript() device can fail to find a font",
  "systemfonts reports as resolved. The real verdict is visual, in",
  "Section 23, under the device you actually render with.\n"
)

pick_family <- function(i) {
  if (length(installed_families) >= i) installed_families[i] else ""
}

## ---- reusable helpers: error/warning demo printers (used from Section 2 on) ----

demo_error <- function(label, expr) {
  msg <- tryCatch(
    {
      force(expr)
      "(no error raised)"
    },
    error = function(e) paste0("ERROR: ", conditionMessage(e))
  )
  cat("== ", label, " ==\n", msg, "\n\n", sep = "")
  invisible(NULL)
}

demo_warning <- function(label, expr) {
  seen <- character(0)
  withCallingHandlers(
    tryCatch(
      force(expr),
      error = function(e) {
        seen <<- c(seen, paste0("ERROR: ", conditionMessage(e)))
      }
    ),
    warning = function(w) {
      seen <<- c(seen, paste0("WARNING: ", conditionMessage(w)))
      invokeRestart("muffleWarning")
    }
  )
  msg <- if (length(seen) == 0) {
    "(no warning raised)"
  } else {
    paste(seen, collapse = "\n")
  }
  cat("== ", label, " ==\n", msg, "\n\n", sep = "")
  invisible(NULL)
}

## ---- reusable helpers: real-data cleaning / extraction ----
## Each is called fresh wherever a later section needs it, rather than
## relying on a variable another section happened to set.

clean_projection_data <- function() {
  believe_projection |>
    filter(sub_exp == "1") |>
    mutate(
      judgment = (judgment - 50) / 25,
      scenario = gsub("undef", "undefined", scenario),
      scenario = factor(
        scenario,
        levels = c("true", "false", "undefined", "critical")
      ),
      negation = factor(negation, levels = c("pos", "neg")),
      negation = fct_recode(negation, without = "pos", with = "neg"),
      trigger = paste0("*", trigger, "*"),
      trigger = factor(trigger, levels = c("*again*", "*stop*"))
    )
}

mu_ridge_draws <- function() {
  believe_projection_draws |>
    filter(dpar == "mu") |>
    mutate(cond = paste0(scenario, "-", negation))
}

sigma_ridge_draws <- function() {
  believe_projection_draws |>
    filter(dpar == "sigma") |>
    mutate(cond = paste0(scenario, "-", negation))
}

mu_coef_draws <- function() filter(believe_projection_coef_draws, dpar == "mu")
sigma_coef_draws <- function() {
  filter(believe_projection_coef_draws, dpar == "sigma")
}

loc_scale_draws <- function() {
  pivot_wider(believe_projection_draws, names_from = dpar, values_from = .value)
}

mu_bf <- function() filter(believe_projection_bf, dpar == "mu")
sigma_bf <- function() filter(believe_projection_bf, dpar == "sigma")

# same 9 contrasts vignette("bayesian-plots") demonstrates, reused across
# several sections below
bf_pairs_default <- list(
  c("with undef", "without undef"),
  c("with undef", "with critical"),
  c("with true", "without true"),
  c("with false", "without false"),
  c("with critical", "without critical"),
  c("with false", "with critical"),
  c("without false", "without critical"),
  c("without true", "with false"),
  c("with true", "without false")
)

## ---- reusable helpers: synthetic data generators (defined here, used from
## Section 7 on) - each seeds internally so it's reproducible in isolation
## regardless of run order ----

gen_groups <- function(n_groups, n_per_group, seed = 1) {
  set.seed(seed)
  means <- seq(0, n_groups - 1) * 0.8
  data.frame(
    group = factor(rep(paste0("g", seq_len(n_groups)), each = n_per_group)),
    y = unlist(lapply(seq_len(n_groups), function(i) {
      rnorm(n_per_group, means[i], 1)
    }))
  )
}

gen_unbalanced <- function(ns, seed = 1) {
  set.seed(seed)
  groups <- paste0("g", seq_along(ns))
  data.frame(
    group = factor(rep(groups, times = ns)),
    y = unlist(lapply(seq_along(ns), function(i) rnorm(ns[i], i, 1)))
  )
}

gen_zero_variance <- function(
  n_groups,
  const_groups,
  n_per_group = 30,
  seed = 1
) {
  set.seed(seed)
  groups <- paste0("g", seq_len(n_groups))
  data.frame(
    group = factor(rep(groups, each = n_per_group)),
    y = unlist(lapply(seq_len(n_groups), function(i) {
      if (i %in% const_groups) rep(5, n_per_group) else rnorm(n_per_group, i, 1)
    }))
  )
}

gen_with_na <- function(
  n_groups = 3,
  n_per_group = 40,
  prop_na_y = 0,
  prop_na_group = 0,
  seed = 1
) {
  set.seed(seed)
  groups <- paste0("g", seq_len(n_groups))
  df <- data.frame(
    group = rep(groups, each = n_per_group),
    y = unlist(lapply(seq_len(n_groups), function(i) rnorm(n_per_group, i, 1)))
  )
  if (prop_na_y > 0) {
    idx <- sample(nrow(df), floor(nrow(df) * prop_na_y))
    df$y[idx] <- NA
  }
  if (prop_na_group > 0) {
    idx <- sample(nrow(df), floor(nrow(df) * prop_na_group))
    df$group[idx] <- NA
  }
  df$group <- factor(df$group)
  df
}

gen_skewed <- function(n_groups = 3, n_per_group = 200, seed = 1) {
  set.seed(seed)
  groups <- paste0("g", seq_len(n_groups))
  data.frame(
    group = factor(rep(groups, each = n_per_group)),
    y = unlist(lapply(seq_len(n_groups), function(i) {
      rgamma(n_per_group, shape = i + 1, rate = 1)
    }))
  )
}

gen_bimodal <- function(n_groups = 3, n_per_group = 200, seed = 1) {
  set.seed(seed)
  groups <- paste0("g", seq_len(n_groups))
  data.frame(
    group = factor(rep(groups, each = n_per_group)),
    y = unlist(lapply(seq_len(n_groups), function(i) {
      c(rnorm(n_per_group / 2, -2 - i, .5), rnorm(n_per_group / 2, 2 + i, .5))
    }))
  )
}

gen_outliers <- function(
  n_groups = 3,
  n_per_group = 60,
  n_outliers = 3,
  outlier_mult = 8,
  seed = 1
) {
  set.seed(seed)
  groups <- paste0("g", seq_len(n_groups))
  data.frame(
    group = factor(rep(groups, each = n_per_group)),
    y = unlist(lapply(seq_len(n_groups), function(i) {
      core <- rnorm(n_per_group - n_outliers, i, 1)
      outliers <- i +
        outlier_mult * sample(c(-1, 1), n_outliers, replace = TRUE)
      c(core, outliers)
    }))
  )
}

gen_mixed_sign <- function(n_groups = 3, n_per_group = 100, seed = 1) {
  set.seed(seed)
  groups <- paste0("g", seq_len(n_groups))
  data.frame(
    group = factor(rep(groups, each = n_per_group)),
    y = unlist(lapply(seq_len(n_groups), function(i) {
      rnorm(n_per_group, (i - 2) * 5, 2)
    }))
  )
}

gen_extreme_scale <- function(seed = 1) {
  set.seed(seed)
  data.frame(
    group = factor(rep(c("tiny", "huge"), each = 100)),
    y = c(rnorm(100, 0, 1e-6), rnorm(100, 0, 1e6))
  )
}

# `missing_cells`/`thin_cells`: character vectors of "<group> <split>" keys,
# e.g. c("g4 B"), naming cells to drop entirely / shrink to n = 1
gen_split_data <- function(
  n_groups = 4,
  n_per_cell = 40,
  missing_cells = character(0),
  thin_cells = character(0),
  seed = 1
) {
  set.seed(seed)
  groups <- paste0("g", seq_len(n_groups))
  splits <- c("A", "B")
  grid <- expand.grid(group = groups, split = splits, stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(grid)), function(i) {
    g <- grid$group[i]
    s <- grid$split[i]
    key <- paste(g, s)
    if (key %in% missing_cells) {
      return(NULL)
    }
    n <- if (key %in% thin_cells) 1 else n_per_cell
    data.frame(group = g, split = s, y = rnorm(n, match(g, groups), 1))
  })
  do.call(rbind, rows)
}

gen_split_bad_levels <- function(n_levels, seed = 1) {
  set.seed(seed)
  levels_vec <- if (n_levels == 1) "only" else paste0("lvl", seq_len(n_levels))
  data.frame(
    group = factor(rep(c("g1", "g2"), each = 20)),
    split = sample(levels_vec, 40, replace = TRUE),
    y = rnorm(40)
  )
}

## ---- first look at the 4 bundled real datasets ----

cat("\n== believe_projection (raw) ==\n")
str(believe_projection)
cat("\nsub_exp counts (raw):\n")
print(table(believe_projection$sub_exp))
cat("\nscenario counts (raw, mixed case for training rows):\n")
print(table(believe_projection$scenario))
cat("\nnegation counts (raw):\n")
print(table(believe_projection$negation))

cat(
  "\n== believe_projection, sub_exp == '1' only (the shape clean_projection_data() produces) ==\n"
)
clean_check <- clean_projection_data()
print(table(clean_check$scenario, clean_check$negation))
str(clean_check)

cat("\n== believe_projection_draws ==\n")
str(believe_projection_draws)
cat(
  "negation levels here:",
  paste(
    unique(as.character(believe_projection_draws$negation)),
    collapse = ", "
  ),
  "\n"
)
cat(
  "trigger levels here:",
  paste(
    unique(as.character(believe_projection_draws$trigger)),
    collapse = ", "
  ),
  "\n"
)

cat("\n== believe_projection_coef_draws ==\n")
str(believe_projection_coef_draws)
cat("sample coef labels:\n")
print(head(unique(believe_projection_coef_draws$coef), 6))

cat("\n== believe_projection_bf ==\n")
str(believe_projection_bf)
print(head(believe_projection_bf))

# ==== 2. COLORS & PALETTES ====
# gap: mt_colors_many() has zero existing test coverage.

show_col(mt_colors)
show_col(dark_mt_colors)
show_col(mt_colors3)
show_col(dark_mt_colors3)
show_col(mt_colors4)
show_col(dark_mt_colors4)
show_col(mt_colors5)
show_col(dark_mt_colors5)

show_col(mt_colors_many(3))
show_col(mt_colors_many(8))
show_col(mt_colors_many(20))
show_col(mt_colors_many(100))

# the ramp as an actual continuous fill scale, not just swatches
heat_data <- expand.grid(x = 1:20, y = 1:20)
heat_data$z <- with(heat_data, sin(x / 3) + cos(y / 3))
p_ramp <- ggplot(heat_data, aes(x, y, fill = z)) +
  geom_tile() +
  scale_fill_gradientn(colours = mt_colors_many(256)) +
  labs(title = "mt_colors_many() as a continuous fill ramp")
print(p_ramp)

# edge cases - confirmed live during planning: n=1 -> first anchor color,
# n=0 -> character(0), n=-1 -> a hard error
demo_error("mt_colors_many(1)", print(mt_colors_many(1)))
demo_error("mt_colors_many(0)", print(mt_colors_many(0)))
demo_error("mt_colors_many(-1)", print(mt_colors_many(-1)))

# ==== 3. theme_mt() BASICS - LIGHT VS. DARK, INDIVIDUAL ARGUMENTS ====

theme_demo_data <- data.frame(
  category = factor(rep(c("Alpha", "Beta", "Gamma"), times = 2)),
  facet = rep(c("Group 1", "Group 2"), each = 3),
  value = c(5.2, 6.8, 4.1, 5.9, 6.2, 4.7)
)

build_theme_demo_plot <- function(theme_obj) {
  ggplot(theme_demo_data, aes(x = category, y = value, fill = category)) +
    geom_col() +
    facet_wrap(vars(facet)) +
    labs(
      title = "**Theme** demo plot",
      subtitle = "Comparing theme_mt() arguments",
      x = "Category",
      y = "Mean value",
      caption = "Synthetic data, exploratory-tests.R Section 3"
    ) +
    guides(fill = "none") +
    theme_obj
}

print(build_theme_demo_plot(theme_mt()))

print(
  build_theme_demo_plot(theme_mt(dark = TRUE)) +
    theme(plot.background = element_rect(fill = "#151515", color = NA))
)

print(build_theme_demo_plot(theme_mt(show_axis_line = FALSE)))

print(build_theme_demo_plot(theme_mt(
  grid_color = "orange",
  axis_text_color = "purple",
  axis_line_color = "red"
)))

print(
  build_theme_demo_plot(theme_mt(
    dark = TRUE,
    grid_color = "orange",
    axis_text_color = "purple",
    axis_line_color = "red"
  )) +
    theme(plot.background = element_rect(fill = "#151515", color = NA))
)

## ---- every individual *_family / *_size argument, set to a visibly
## distinct value at once, so each element's font/size is independently
## confirmable (gap: no test covers these beyond defaults) ----
print(build_theme_demo_plot(theme_mt(
  plot_title_family = pick_family(1),
  subtitle_family = pick_family(2),
  strip_text_family = pick_family(3),
  axis_title_family = pick_family(4),
  axis_text_family = pick_family(5),
  caption_family = pick_family(6),
  plot_title_size = 30,
  subtitle_size = 8,
  strip_text_size = 24,
  axis_title_size = 6,
  axis_text_size = 20,
  caption_size = 4
)))

# ==== 4. use_theme_mt() GLOBAL STATE ====

use_theme_mt() # base_size = 10 default
p_default_active <- ggplot(
  theme_demo_data,
  aes(category, value, fill = category)
) +
  geom_col() +
  guides(fill = "none") +
  labs(
    title = "Active theme after use_theme_mt() - base_size = 10, no explicit + theme_mt()"
  )
print(p_default_active)

use_theme_mt(base_size = 19) # matches theme_mt()'s own default, for apples-to-apples vs. Section 3
p_size19_active <- ggplot(
  theme_demo_data,
  aes(category, value, fill = category)
) +
  geom_col() +
  guides(fill = "none") +
  labs(title = "Active theme after use_theme_mt(base_size = 19)")
print(p_size19_active)

# geom_density()'s adjust = 5 default, set by use_theme_mt()
density_data <- data.frame(x = c(rnorm(300), rnorm(300, 4)))
p_density_default_adjust <- ggplot(density_data, aes(x)) +
  geom_density() +
  labs(title = "geom_density() default (use_theme_mt()'s adjust = 5)")
p_density_adjust1 <- ggplot(density_data, aes(x)) +
  geom_density(adjust = 1) +
  labs(title = "geom_density(adjust = 1), explicit override")
print(p_density_default_adjust + p_density_adjust1)

# The dual light/dark knit_print feature (R/dual-render.R) only activates
# inside a knitr/Quarto chunk with the `dual_render` chunk option set to
# TRUE - it is not exercisable from a plain script. See
# tests/testthat/test-dual-render.R for that coverage; nothing to demo here.

use_theme_mt() # reset to the default base_size = 10 before later sections

# ==== 5. REAL DATASET ACQUAINTANCE - SANITY PLOT ====

d_sanity <- clean_projection_data()
str(d_sanity)
print(summary(d_sanity$judgment))
print(table(d_sanity$scenario, d_sanity$negation))

p_sanity <- ggplot(d_sanity, aes(x = scenario, y = judgment, fill = scenario)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(
    title = "Sanity check: clean_projection_data() + geom_violin_sd()",
    x = NULL,
    y = "Judgment (rescaled -2/+2)"
  )
print(p_sanity)

# ==== 6. SYNTHETIC DATA GENERATOR BATTERY ====
# The generators themselves (gen_groups(), gen_unbalanced(), etc.) were
# already defined in Section 1, alongside the real-data helpers, so every
# later section can call them without depending on this section having run.
# This section is just a visual roll call of what each one produces, before
# they're thrown at the geoms in Sections 7-9.

str(gen_groups(3, 10))
str(gen_unbalanced(c(2, 5, 50)))
str(gen_zero_variance(4, const_groups = c(2, 4)))
str(gen_with_na(prop_na_y = 0.2))
str(gen_skewed())
str(gen_bimodal())
str(gen_outliers())
str(gen_mixed_sign())
str(gen_extreme_scale())
str(gen_split_data(missing_cells = "g4 B", thin_cells = "g2 A"))
str(gen_split_bad_levels(n_levels = 1))
str(gen_split_bad_levels(n_levels = 3))

# ==== 7. geom_violin_sd() ====

## ---- baseline: plain vs. _sd, real data (a sanity anchor before stress tests) ----
d <- clean_projection_data()
demo_data <- transmute(d, group = scenario, value = judgment)

p_violin_plain <- ggplot(demo_data, aes(group, value, fill = group)) +
  geom_violin(trim = FALSE) +
  guides(fill = "none") +
  labs(title = "geom_violin() (plain)", x = NULL, y = NULL)
p_violin_sd_baseline <- ggplot(demo_data, aes(group, value, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd()", x = NULL, y = NULL)
print(p_violin_plain + p_violin_sd_baseline)

## ---- group-count sweep ----
for (ng in c(2, 3, 8)) {
  p <- ggplot(gen_groups(ng, 50), aes(group, y, fill = group)) +
    geom_violin_sd() +
    guides(fill = "none") +
    labs(title = sprintf("geom_violin_sd(): %d groups", ng))
  print(p)
}

## ---- n boundary cases ----
p_n2 <- ggplot(gen_groups(3, 2), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): n = 2 per group (SD-band floor)")
p_n500 <- ggplot(gen_groups(3, 500), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): n = 500 per group")
print(p_n2 + p_n500)

## ---- unbalanced / zero-variance ----
p_unbalanced <- ggplot(
  gen_unbalanced(c(2, 5, 50, 300)),
  aes(group, y, fill = group)
) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): unbalanced groups (n = 2/5/50/300)")
print(p_unbalanced)

p_zerovar <- ggplot(
  gen_zero_variance(4, const_groups = c(2, 4)),
  aes(group, y, fill = group)
) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): groups 2 & 4 have zero variance")
print(p_zerovar)

## ---- untested distribution shapes (existing fixtures are all rnorm()) ----
p_skewed <- ggplot(gen_skewed(), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): skewed (gamma) data")
p_bimodal <- ggplot(gen_bimodal(), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): bimodal data")
print(p_skewed + p_bimodal)

p_outliers <- ggplot(gen_outliers(), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): normal core + injected outliers")
print(p_outliers)

p_mixed_sign <- ggplot(gen_mixed_sign(), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): mixed-sign data (negative to positive)")
print(p_mixed_sign)

p_extreme_scale <- ggplot(gen_extreme_scale(), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(
    title = "geom_violin_sd(): extreme scale mismatch (1e-6 vs. 1e6) - watch the axis labels"
  )
print(p_extreme_scale)

p_with_na_y <- ggplot(
  gen_with_na(prop_na_y = 0.15),
  aes(group, y, fill = group)
) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): 15% NA in y")
p_with_na_group <- ggplot(
  gen_with_na(prop_na_group = 0.1),
  aes(group, y, fill = group)
) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd(): 10% NA in the grouping column")
print(p_with_na_y + p_with_na_group)

## ---- style variants ----
p_style_both <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd(style = "both") +
  guides(fill = "none") +
  labs(title = "style = both")
p_style_fill <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd(style = "fill") +
  guides(fill = "none") +
  labs(title = "style = fill")
p_style_outline <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd(style = "outline") +
  guides(fill = "none") +
  labs(title = "style = outline")
print(p_style_both + p_style_fill + p_style_outline)

## ---- real data, faceted (gap: the vignette never facets this geom) ----
p_real_faceted <- ggplot(d, aes(scenario, judgment, fill = scenario)) +
  geom_violin_sd() +
  facet_wrap(vars(trigger)) +
  guides(fill = "none") +
  labs(
    title = "geom_violin_sd() on real data, faceted by trigger",
    x = NULL,
    y = "Judgment"
  )
print(p_real_faceted)

## ---- orientation: coord_flip() on real data, horizontal mapping on
## asymmetric synthetic data (stresses the flip_data() bookkeeping the
## source comments call out at length) ----
p_coord_flip <- ggplot(d, aes(scenario, judgment, fill = scenario)) +
  geom_violin_sd() +
  coord_flip() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd() + coord_flip(), real data")
print(p_coord_flip)

p_horizontal <- ggplot(gen_bimodal(), aes(x = y, y = group, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_violin_sd() horizontal aes(x=value,y=group), bimodal data")
print(p_horizontal)

## ---- sd_linewidth / base_alpha / sd_alpha extremes ----
p_lw0 <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd(sd_linewidth = 0) +
  guides(fill = "none") +
  labs(title = "sd_linewidth = 0")
p_lw5 <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd(sd_linewidth = 5) +
  guides(fill = "none") +
  labs(title = "sd_linewidth = 5")
print(p_lw0 + p_lw5)

p_alpha0 <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd(base_alpha = 0, sd_alpha = 0) +
  guides(fill = "none") +
  labs(title = "base_alpha = sd_alpha = 0")
p_alpha1 <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd(base_alpha = 1, sd_alpha = 1) +
  guides(fill = "none") +
  labs(title = "base_alpha = sd_alpha = 1")
print(p_alpha0 + p_alpha1)

# ==== 8. geom_half_violin_sd() ====

## ---- baseline: plain vs. _sd, real data ----
d <- clean_projection_data()
demo_data <- transmute(d, group = scenario, value = judgment)

p_half_plain <- ggplot(demo_data, aes(group, value, fill = group)) +
  geom_half_violin(side = "r", trim = FALSE) +
  guides(fill = "none") +
  labs(title = "geom_half_violin() (plain)", x = NULL, y = NULL)
p_half_sd_baseline <- ggplot(demo_data, aes(group, value, fill = group)) +
  geom_half_violin_sd(side = "r") +
  guides(fill = "none") +
  labs(title = "geom_half_violin_sd()", x = NULL, y = NULL)
print(p_half_plain + p_half_sd_baseline)

## ---- group-count / n / unbalanced / zero-variance / style sweeps
## (mirroring Section 7) ----
for (ng in c(2, 3, 8)) {
  p <- ggplot(gen_groups(ng, 50), aes(group, y, fill = group)) +
    geom_half_violin_sd() +
    guides(fill = "none") +
    labs(title = sprintf("geom_half_violin_sd(): %d groups", ng))
  print(p)
}

p_half_n2 <- ggplot(gen_groups(3, 2), aes(group, y, fill = group)) +
  geom_half_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_half_violin_sd(): n = 2 per group")
print(p_half_n2)

p_half_unbalanced <- ggplot(
  gen_unbalanced(c(2, 5, 50, 300)),
  aes(group, y, fill = group)
) +
  geom_half_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_half_violin_sd(): unbalanced groups")
print(p_half_unbalanced)

p_half_zerovar <- ggplot(
  gen_zero_variance(4, const_groups = c(2, 4)),
  aes(group, y, fill = group)
) +
  geom_half_violin_sd() +
  guides(fill = "none") +
  labs(title = "geom_half_violin_sd(): zero-variance groups")
print(p_half_zerovar)

p_half_style_both <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_half_violin_sd(style = "both") +
  guides(fill = "none") +
  labs(title = "style = both")
p_half_style_fill <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_half_violin_sd(style = "fill") +
  guides(fill = "none") +
  labs(title = "style = fill")
p_half_style_outline <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_half_violin_sd(style = "outline") +
  guides(fill = "none") +
  labs(title = "style = outline")
print(p_half_style_both + p_half_style_fill + p_half_style_outline)

## ---- side scalar vs. vector, out-of-alphabetical group labels ----
side_data <- data.frame(
  group = factor(rep(c("c", "a", "b"), each = 40), levels = c("c", "a", "b")),
  y = c(rnorm(40, 1), rnorm(40, 2), rnorm(40, 3))
)
p_side_l <- ggplot(side_data, aes(group, y, fill = group)) +
  geom_half_violin_sd(side = "l") +
  guides(fill = "none") +
  labs(title = "side = 'l' (scalar)")
p_side_r <- ggplot(side_data, aes(group, y, fill = group)) +
  geom_half_violin_sd(side = "r") +
  guides(fill = "none") +
  labs(title = "side = 'r' (scalar)")
print(p_side_l + p_side_r)

# side is indexed by SORTED factor-level order (a, b, c), not data row order
# or the plotted axis order (c, a, b)
p_side_vec <- ggplot(side_data, aes(group, y, fill = group)) +
  geom_half_violin_sd(side = c("l", "r", "l")) +
  guides(fill = "none") +
  labs(
    title = "side = c('l','r','l') applies to sorted levels a,b,c - not plotted order c,a,b"
  )
print(p_side_vec)

## ---- real data, faceted (gap: not done in the vignette) ----
p_half_real_faceted <- ggplot(d, aes(scenario, judgment, fill = scenario)) +
  geom_half_violin_sd(side = "r") +
  facet_wrap(vars(negation)) +
  guides(fill = "none") +
  labs(
    title = "geom_half_violin_sd() on real data, faceted by negation",
    x = NULL,
    y = "Judgment"
  )
print(p_half_real_faceted)

## ---- dedicated, UNWRAPPED misbehavior probe (documented, expected) ----
# gghalves has no orientation/flipped_aes concept at all; horizontal mapping
# or coord_flip() silently mispositions the halves and throws repeated
# position_dodge() warnings. Left unwrapped so you see the real warnings and
# the visibly wrong rendering - this is the KNOWN baseline. If this looks
# meaningfully different from what you see today on a future run, that's
# worth reporting; the misbehavior itself is not a new bug.
p_half_horizontal_misbehaving <- ggplot(
  gen_bimodal(),
  aes(x = y, y = group, fill = group)
) +
  geom_half_violin_sd() +
  guides(fill = "none") +
  labs(
    title = "KNOWN LIMITATION: geom_half_violin_sd() horizontal aes(x=value,y=group)"
  )
print(p_half_horizontal_misbehaving)

p_half_coord_flip_misbehaving <- ggplot(
  d,
  aes(scenario, judgment, fill = scenario)
) +
  geom_half_violin_sd() +
  coord_flip() +
  guides(fill = "none") +
  labs(
    title = "KNOWN LIMITATION: geom_half_violin_sd() + coord_flip(), real data"
  )
print(p_half_coord_flip_misbehaving)

# ==== 9. geom_split_violin_sd() ====

d <- clean_projection_data()
balanced <- filter(d, trigger == "*again*")
split_mapping <- aes(x = scenario, y = judgment)

p_split_balanced <- ggplot(balanced, split_mapping) +
  geom_split_violin_sd(split_mapping, data = balanced, split = negation) +
  labs(title = "geom_split_violin_sd(): balanced", x = NULL, y = "Judgment")
p_split_flip <- ggplot(balanced, split_mapping) +
  geom_split_violin_sd(
    split_mapping,
    data = balanced,
    split = negation,
    flip = TRUE
  ) +
  labs(title = "flip = TRUE (same data, sides swapped)", x = NULL, y = NULL)
print(p_split_balanced + p_split_flip)

## ---- style variants ----
p_split_both <- ggplot(balanced, split_mapping) +
  geom_split_violin_sd(
    split_mapping,
    data = balanced,
    split = negation,
    style = "both"
  ) +
  labs(title = "style = both", x = NULL, y = NULL)
p_split_fill <- ggplot(balanced, split_mapping) +
  geom_split_violin_sd(
    split_mapping,
    data = balanced,
    split = negation,
    style = "fill"
  ) +
  labs(title = "style = fill", x = NULL, y = NULL)
p_split_outline <- ggplot(balanced, split_mapping) +
  geom_split_violin_sd(
    split_mapping,
    data = balanced,
    split = negation,
    style = "outline"
  ) +
  labs(title = "style = outline", x = NULL, y = NULL)
print(p_split_both + p_split_fill + p_split_outline)

## ---- scale = "count" vs. "area" (engineered imbalance, from the vignette:
## scale only normalizes a side against ITSELF, never against the other side) ----
set.seed(42)
with_fracs <- c(true = 1, false = .7, undefined = .45, critical = .25)
unbalanced_split <- bind_rows(
  filter(balanced, negation == "without"),
  balanced |>
    filter(negation == "with") |>
    group_by(scenario) |>
    group_modify(
      ~ slice_sample(.x, prop = with_fracs[[as.character(.y$scenario)]])
    ) |>
    ungroup()
)
p_scale_count <- ggplot(unbalanced_split, split_mapping) +
  geom_split_violin_sd(
    split_mapping,
    data = unbalanced_split,
    split = negation
  ) +
  labs(title = "scale = 'count' (default)", x = NULL, y = "Judgment")
p_scale_area <- ggplot(unbalanced_split, split_mapping) +
  geom_split_violin_sd(
    split_mapping,
    data = unbalanced_split,
    split = negation,
    scale = "area"
  ) +
  labs(title = "scale = 'area'", x = NULL, y = NULL)
print(p_scale_count + p_scale_area)

## ---- missing-cell warning vs. thin-cell warning (distinct code paths,
## both left UNWRAPPED so you see R's real default warning output) ----
split_missing <- gen_split_data(n_groups = 4, missing_cells = "g4 B")
mapping_missing <- aes(x = group, y = y)
p_split_missing <- ggplot(split_missing, mapping_missing) +
  geom_split_violin_sd(mapping_missing, data = split_missing, split = split) +
  labs(title = "Missing-cell warning: g4 has no 'B' data", x = NULL, y = NULL)
print(p_split_missing)

split_thin <- gen_split_data(n_groups = 4, thin_cells = "g2 A")
mapping_thin <- aes(x = group, y = y)
p_split_thin <- ggplot(split_thin, mapping_thin) +
  geom_split_violin_sd(mapping_thin, data = split_thin, split = split) +
  labs(
    title = "Thin-cell warning: g2/A has n=1 (below the SD-band n>=2 minimum)",
    x = NULL,
    y = NULL
  )
print(p_split_thin)

## ---- mapping = NULL: x inherited from the plot's own top-level aes()
## rather than the layer's own - the thin/one-sided-cell diagnostic is
## documented to stay silent (not false-positive) in this case ----
p_split_inherited_x <- ggplot(split_thin, mapping_thin) +
  geom_split_violin_sd(data = split_thin, split = split) +
  labs(
    title = "mapping = NULL (x inherited from plot aes) - thin-cell diagnostic should stay silent here",
    x = NULL,
    y = NULL
  )
print(p_split_inherited_x)

## ---- labs()/guides() legend-title interplay ----
p_split_labs <- ggplot(balanced, split_mapping) +
  geom_split_violin_sd(split_mapping, data = balanced, split = negation) +
  labs(
    title = "labs(fill = ...) controls the merged legend title",
    fill = "Custom Title via labs()"
  )
print(p_split_labs)

p_split_guides <- ggplot(balanced, split_mapping) +
  geom_split_violin_sd(split_mapping, data = balanced, split = negation) +
  guides(fill = guide_legend(title = "Custom Title via guides()")) +
  labs(title = "guides(fill = guide_legend(title = ...)) also controls it")
print(p_split_guides)

## ---- NA rows in the split column (UNWRAPPED) ----
split_na <- gen_split_data(n_groups = 3)
split_na$split[1:5] <- NA
mapping_na <- aes(x = group, y = y)
p_split_na <- ggplot(split_na, mapping_na) +
  geom_split_violin_sd(mapping_na, data = split_na, split = split) +
  labs(
    title = "NA rows in split column - dropped with a warning",
    x = NULL,
    y = NULL
  )
print(p_split_na)

# ==== 10. layer_halfeye_hdi() STANDALONE ====

halfeye_synth <- data.frame(
  cond = rep(c("a", "b", "c"), each = 500),
  value = c(rnorm(500), rnorm(500, 1, 1.3), rnorm(500, -1, 0.6))
)

p_halfeye_baseline <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi() +
  coord_flip() +
  labs(title = "layer_halfeye_hdi(): baseline")
print(p_halfeye_baseline)

p_halfeye_single_widths <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(slab_widths = .95, interval_widths = .9) +
  coord_flip() +
  labs(title = "single slab_widths/interval_widths (vs. multi-width default)")
print(p_halfeye_single_widths)

p_halfeye_scale_small <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(scale = 0.3) +
  coord_flip() +
  labs(title = "scale = 0.3")
p_halfeye_scale_large <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(scale = 3) +
  coord_flip() +
  labs(title = "scale = 3")
print(p_halfeye_scale_small + p_halfeye_scale_large)

p_halfeye_dodge_narrow <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(dodge_width = 0.1) +
  coord_flip() +
  labs(title = "dodge_width = 0.1")
p_halfeye_dodge_wide <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(dodge_width = 1) +
  coord_flip() +
  labs(title = "dodge_width = 1")
print(p_halfeye_dodge_narrow + p_halfeye_dodge_wide)

p_halfeye_gap0 <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(gap = 0) +
  coord_flip() +
  labs(title = "gap = 0 (touching)")
p_halfeye_gap_big <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(gap = 0.2) +
  coord_flip() +
  labs(title = "gap = 0.2 (exaggerated)")
print(p_halfeye_gap0 + p_halfeye_gap_big)

p_halfeye_colors <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(
    fill_colors = c("orange", "purple"),
    interval_color = "darkgreen"
  ) +
  coord_flip() +
  labs(title = "custom fill_colors/interval_color")
print(p_halfeye_colors)

p_halfeye_coarse <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(n = 10) +
  coord_flip() +
  labs(title = "n = 10 (coarse density resolution)")
print(p_halfeye_coarse)

p_halfeye_limits <- ggplot(halfeye_synth, aes(x = cond, y = value)) +
  layer_halfeye_hdi(slab_limits = c(-2, 2), pointinterval_limits = c(-2, 2)) +
  coord_flip() +
  labs(title = "slab_limits/pointinterval_limits = c(-2, 2)")
print(p_halfeye_limits)

# ==== 11. plot_ridge_hdi() WITH REAL DATA ====

ridge_mu <- mu_ridge_draws()

p_ridge_baseline <- plot_ridge_hdi(
  ridge_mu,
  category = cond,
  facet = trigger,
  facet_nrow = 2,
  value_limits = c(-2.3, 2.3),
  value_breaks = c(-2, -1, 0, 1, 2)
) +
  labs(title = "plot_ridge_hdi(): vignette baseline")
print(p_ridge_baseline)

p_ridge_nrow_ncol <- plot_ridge_hdi(
  ridge_mu,
  category = cond,
  facet = trigger,
  facet_nrow = 1,
  facet_ncol = 2,
  value_limits = c(-2.3, 2.3)
) +
  labs(title = "facet_nrow + facet_ncol together")
print(p_ridge_nrow_ncol)

p_ridge_free_scales <- plot_ridge_hdi(
  ridge_mu,
  category = cond,
  facet = trigger,
  facet_scales = "free"
) +
  labs(title = "facet_scales = 'free' (vignette only used 'fixed')")
print(p_ridge_free_scales)

p_ridge_no_reorder <- plot_ridge_hdi(
  ridge_mu,
  category = cond,
  category_reorder = FALSE
) +
  labs(title = "category_reorder = FALSE, all 8 cond levels, unfaceted")
print(p_ridge_no_reorder)

ridge_sigma <- sigma_ridge_draws()
p_ridge_sigma_hline <- plot_ridge_hdi(
  filter(ridge_sigma, trigger == "*again*"),
  category = cond,
  value_transform = exp,
  hline = 1,
  hline_color = mt_colors[1],
  ylab = "Posterior marginal SD ±HDI<sub>95</sub>"
) +
  labs(title = "sigma submodel, value_transform = exp, hline = 1")
print(p_ridge_sigma_hline)

p_ridge_narrow_limits <- plot_ridge_hdi(
  ridge_mu,
  category = cond,
  value_limits = c(-0.5, 0.5)
) +
  labs(
    title = "value_limits narrower than the real data range (clipping check)"
  )
print(p_ridge_narrow_limits)

# all 16 scenario x negation x trigger rows in one unfaceted ridge - crowded
# label stress test
ridge_all16 <- mutate(
  mu_ridge_draws(),
  cond_full = paste0(scenario, "-", negation, "-", trigger)
)
p_ridge_crowded <- plot_ridge_hdi(ridge_all16, category = cond_full) +
  labs(title = "All 16 scenario x negation x trigger rows, unfaceted")
print(p_ridge_crowded)

# ==== 12. plot_coef_grid_hdi() WITH REAL DATA ====

coef_mu <- mu_coef_draws()
coef_sigma <- sigma_coef_draws()

p_coef_baseline_mu <- plot_coef_grid_hdi(
  coef_mu,
  category = coef,
  scale = 1.4
) +
  labs(
    title = "plot_coef_grid_hdi(): mu submodel, ncol = 4 (vignette baseline)"
  )
print(p_coef_baseline_mu)

p_coef_baseline_sigma <- plot_coef_grid_hdi(
  coef_sigma,
  category = coef,
  scale = 1.4,
  ncol = 3
) +
  labs(title = "sigma submodel, ncol = 3 (vignette baseline)")
print(p_coef_baseline_sigma)

p_coef_ncol1 <- plot_coef_grid_hdi(
  coef_mu,
  category = coef,
  scale = 1.4,
  ncol = 1
) +
  labs(title = "ncol = 1 (very tall single column, all 16 mu coefficients)")
print(p_coef_ncol1)

p_coef_ncol16 <- plot_coef_grid_hdi(
  coef_mu,
  category = coef,
  scale = 1.4,
  ncol = 16
) +
  labs(title = "ncol = 16 (very wide single row)")
print(p_coef_ncol16)

p_coef_no_hline <- plot_coef_grid_hdi(
  coef_mu,
  category = coef,
  scale = 1.4,
  hline = NULL
) +
  labs(title = "hline = NULL")
print(p_coef_no_hline)

p_coef_custom_hline <- plot_coef_grid_hdi(
  coef_mu,
  category = coef,
  scale = 1.4,
  hline = 0.5,
  hline_color = "darkgreen"
) +
  labs(title = "hline = 0.5, custom hline_color")
print(p_coef_custom_hline)

# markdown <sub> in coefficient labels - the one place strip.text carries
# genuinely markdown-bearing real content; check it renders as a subscript,
# not literal "<sub>...</sub>" text, in the plots above
cat(
  "Sample coefficient labels (should render as HTML <sub> in facet strips):\n"
)
print(head(unique(coef_mu$coef), 10))

# ==== 13. plot_location_scale() - CORRECT PAIRED-DRAWS USAGE ====

ls_data <- loc_scale_draws()

p_ls_baseline <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  shape = negation,
  facet = trigger,
  bounds = c(-2, 2)
) +
  labs(title = "plot_location_scale(): vignette baseline")
print(p_ls_baseline)

p_ls_single_level <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  ellipse_level = .95
) +
  labs(title = "ellipse_level = .95 (single level)")
print(p_ls_single_level)

p_ls_many_levels <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  ellipse_level = c(.5, .8, .95, .99)
) +
  labs(
    title = "ellipse_level = c(.5, .8, .95, .99) - alpha-fade + draw-order check"
  )
print(p_ls_many_levels)

p_ls_ellipse_t <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  ellipse_type = "t"
) +
  labs(title = "ellipse_type = 't'")
p_ls_ellipse_euclid <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  ellipse_type = "euclid"
) +
  labs(title = "ellipse_type = 'euclid'")
print(p_ls_ellipse_t + p_ls_ellipse_euclid)

p_ls_geom_path <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  ellipse_geom = "path"
) +
  labs(title = "ellipse_geom = 'path'")
print(p_ls_geom_path)

p_ls_manual_alpha <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  ellipse_level = c(.5, .95),
  ellipse_alpha = c(.6, .1)
) +
  labs(title = "manual ellipse_alpha = c(.6, .1)")
print(p_ls_manual_alpha)

p_ls_minimal <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma
) +
  labs(title = "minimal call: no shape, no facet")
print(p_ls_minimal)

p_ls_no_bounds <- plot_location_scale(
  ls_data,
  category = scenario,
  location = mu,
  sigma = sigma,
  bounds = NULL
) +
  labs(title = "bounds = NULL (no sigma_max curve)")
print(p_ls_no_bounds)

# ==== 14. plot_location_scale() - DELIBERATE MISUSE (NON-PAIRED DATA) ====

# Shuffling `sigma` within each category breaks the *joint* per-draw pairing
# (same .draw -> same iteration) while leaving each category's marginal mu
# and sigma distributions completely unchanged - so any visible difference
# between the two ellipses below is entirely due to the lost pairing, not a
# difference in the underlying marginals. This is the concrete "correct vs.
# misuse" contrast nothing in the tests or vignette currently shows.
set.seed(7)
ls_unpaired <- loc_scale_draws() |>
  group_by(scenario) |>
  mutate(sigma = sample(sigma)) |>
  ungroup()

p_ls_correct <- plot_location_scale(
  filter(loc_scale_draws(), negation == "with"),
  category = scenario,
  location = mu,
  sigma = sigma
) +
  guides(color = "none", fill = "none") +
  labs(title = "Correct: paired per-draw (location, sigma)")

p_ls_misuse <- plot_location_scale(
  filter(ls_unpaired, negation == "with"),
  category = scenario,
  location = mu,
  sigma = sigma
) +
  guides(color = "none", fill = "none") +
  labs(title = "Misuse: sigma shuffled within category (pairing destroyed)")

print(p_ls_correct + p_ls_misuse)

# ==== 15. layer_bf_evidence_scale() STANDALONE ====

bf_x_data <- data.frame(
  cond = c("A vs B", "C vs D", "E vs F"),
  log_bf = c(-2.1, 0.3, 4.8)
)

p_bf_scale_x <- ggplot(bf_x_data, aes(y = cond, x = log_bf)) +
  geom_point(size = 3) +
  layer_bf_evidence_scale(orientation = "x") +
  labs(title = "layer_bf_evidence_scale(orientation = 'x'): baseline")
print(p_bf_scale_x)

sweep_data <- data.frame(
  prior_sd = seq(0.1, 1.5, by = 0.2),
  log_bf = c(6.2, 5.1, 3.8, 2.5, 1.4, 0.3, -0.6, -1.5)
)
p_bf_scale_y <- ggplot(sweep_data, aes(x = prior_sd, y = log_bf)) +
  layer_bf_evidence_scale(orientation = "y") +
  geom_line(color = mt_colors[1]) +
  geom_point(color = mt_colors[1], size = 3) +
  labs(title = "orientation = 'y': baseline") +
  coord_cartesian(clip = "off") +
  theme(plot.margin = margin(5.5, 55, 5.5, 5.5, "pt"))
print(p_bf_scale_y)

p_bf_threshold_wide <- ggplot(bf_x_data, aes(y = cond, x = log_bf)) +
  geom_point(size = 3) +
  layer_bf_evidence_scale(orientation = "x", weak_threshold = log(10)) +
  labs(title = "weak_threshold = log(10) (much wider band)")
p_bf_threshold_narrow <- ggplot(bf_x_data, aes(y = cond, x = log_bf)) +
  geom_point(size = 3) +
  layer_bf_evidence_scale(orientation = "x", weak_threshold = log(1.5)) +
  labs(title = "weak_threshold = log(1.5) (much narrower band)")
print(p_bf_threshold_wide)
print(p_bf_threshold_narrow)

p_bf_no_label <- ggplot(bf_x_data, aes(y = cond, x = log_bf)) +
  geom_point(size = 3) +
  layer_bf_evidence_scale(orientation = "x", weak_label = NULL) +
  labs(title = "weak_label = NULL (band with no text)")
print(p_bf_no_label)

p_bf_direction_labels <- ggplot(bf_x_data, aes(y = cond, x = log_bf)) +
  geom_point(size = 3) +
  layer_bf_evidence_scale(
    orientation = "x",
    direction_labels = c("favors A", "favors B"),
    direction_colors = c("darkgreen", "darkred")
  ) +
  labs(title = "direction_labels + custom direction_colors")
print(p_bf_direction_labels)

p_bf_secondary <- ggplot(bf_x_data, aes(y = cond, x = log_bf)) +
  geom_point(size = 3) +
  layer_bf_evidence_scale(
    orientation = "x",
    secondary_axis = TRUE,
    secondary_breaks = c(1, 3, 10, 30),
    secondary_name = "BF"
  ) +
  labs(title = "secondary_axis = TRUE, custom secondary_breaks")
print(p_bf_secondary)

# orientation = "y" + coord_cartesian(clip = "off")/plot.margin interaction,
# with a wider range and a longer label than the vignette's own example
p_bf_y_wide_range <- ggplot(sweep_data, aes(x = prior_sd, y = log_bf)) +
  layer_bf_evidence_scale(
    orientation = "y",
    range = c(-10, 10),
    direction_labels = c(
      "a much longer label than before, supporting a real and substantial difference",
      "supports equivalence"
    )
  ) +
  geom_line(color = mt_colors[1]) +
  geom_point(color = mt_colors[1], size = 3) +
  labs(title = "orientation='y', wider range + longer label - clipping check")
print(p_bf_y_wide_range)

# ==== 16. prepare_bf_contrasts() STANDALONE ====

bf_raw <- mu_bf()

r16_default <- prepare_bf_contrasts(bf_raw)
cat("== prepare_bf_contrasts(): default strip = ' NA$' ==\n")
print(head(r16_default[c("contrast", ".left", ".right", ".contrast_label")]))

r16_custom_strip <- prepare_bf_contrasts(bf_raw, strip = "NA$")
cat("\n== custom strip = 'NA$' (no leading space) ==\n")
print(head(r16_custom_strip[c(".left", ".right")]))

r16_no_strip <- prepare_bf_contrasts(bf_raw, strip = NULL)
cat("\n== strip = NULL (raw 'NA' suffix retained) ==\n")
print(head(r16_no_strip[c(".left", ".right")]))

cat(
  "\n== pairs = NULL (unfiltered, original order), row count:",
  nrow(prepare_bf_contrasts(bf_raw)),
  "==\n"
)

cat("\n== reversed-order pair WITH value (expect automatic sign-flip) ==\n")
r16_reversed_with_value <- prepare_bf_contrasts(
  bf_raw,
  value = log_BF,
  pairs = list(c("without undef", "with undef"))
)
print(r16_reversed_with_value[c(".left", ".right", "log_BF")])

demo_warning(
  "reversed-order pair WITHOUT value (expect a warning, no sign-flip)",
  prepare_bf_contrasts(bf_raw, pairs = list(c("without undef", "with undef")))
)

# ==== 17. plot_bf_forest() WITH REAL DATA ====

bf_mu <- mu_bf()
bf_sigma <- sigma_bf()

p_bf_forest_baseline <- plot_bf_forest(
  bf_mu,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default
) +
  labs(title = "plot_bf_forest(): mu submodel (vignette baseline)")
print(p_bf_forest_baseline)

p_bf_forest_directions <- plot_bf_forest(
  bf_mu,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default,
  direction_labels = c("supports difference", "supports equivalence")
) +
  labs(title = "direction_labels")
print(p_bf_forest_directions)

p_bf_forest_secondary <- plot_bf_forest(
  bf_mu,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default,
  direction_labels = c("supports difference", "supports equivalence"),
  secondary_axis = TRUE
) +
  labs(title = "secondary_axis = TRUE")
print(p_bf_forest_secondary)

# sigma submodel - never shown in the vignette, different/fewer contrasts,
# so bf_pairs_default isn't reused as-is: omit `pairs` and use the raw
# contrast strings directly as labels (a fully supported, documented mode)
cat("Available sigma-submodel contrasts:\n")
print(unique(bf_sigma$contrast))
p_bf_forest_sigma <- plot_bf_forest(
  bf_sigma,
  contrast = contrast,
  log_bf = log_BF
) +
  labs(
    title = "sigma submodel, no pairs filter (raw contrast strings as labels)"
  )
print(p_bf_forest_sigma)

p_bf_forest_no_evidence <- plot_bf_forest(
  bf_mu,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default,
  evidence_scale = FALSE
) +
  labs(title = "evidence_scale = FALSE (bare forest)")
print(p_bf_forest_no_evidence)

p_bf_forest_no_reorder <- plot_bf_forest(
  bf_mu,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default,
  contrast_reorder = FALSE
) +
  labs(title = "contrast_reorder = FALSE (pairs' own order)")
print(p_bf_forest_no_reorder)

p_bf_forest_shapes_colors <- plot_bf_forest(
  bf_mu,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default,
  positive_color = "darkgreen",
  negative_color = "darkred",
  positive_shape = 15,
  negative_shape = 18
) +
  labs(title = "custom positive/negative color + shape")
print(p_bf_forest_shapes_colors)

# real data has no `se` column at all - synthesize one to exercise the
# errorbar branch, which the real bundled data structurally can never reach
bf_with_se <- prepare_bf_contrasts(
  bf_mu,
  value = log_BF,
  pairs = bf_pairs_default
)
set.seed(3)
bf_with_se$se <- runif(nrow(bf_with_se), 0.3, 1.2)
p_bf_forest_se <- plot_bf_forest(
  bf_with_se,
  contrast = .contrast_label,
  log_bf = log_BF,
  se = se
) +
  labs(title = "synthetic se column - exercises the errorbar branch")
print(p_bf_forest_se)

# ==== 18. DELIBERATE MISUSE / ERROR-PATH DEMOS ====
# Every probe below is a labeled, isolated call via demo_error()/
# demo_warning() (both defined in Section 1), so the whole section runs in
# one pass without halting on the first stop() - review every message here
# in one sitting.

## ---- geom_split_violin_sd(): wrong split level counts ----
demo_error(
  "geom_split_violin_sd(): split has 1 level",
  geom_split_violin_sd(
    aes(x = group, y = y),
    data = gen_split_bad_levels(n_levels = 1),
    split = split
  )
)
demo_error(
  "geom_split_violin_sd(): split has 4 levels (real `scenario` column)",
  geom_split_violin_sd(
    aes(x = negation, y = judgment),
    data = clean_projection_data(),
    split = scenario
  )
)

## ---- missing data ----
demo_error(
  "geom_split_violin_sd(): data = NULL",
  geom_split_violin_sd(aes(x = group, y = y), split = split)
)

## ---- split column not found ----
demo_error(
  "geom_split_violin_sd(): split column not in data",
  geom_split_violin_sd(
    aes(x = group, y = y),
    data = gen_split_data(),
    split = nonexistent_column
  )
)

## ---- fill / outline_color length errors ----
some_split_data <- gen_split_data()
demo_error(
  "geom_split_violin_sd(): fill length 3 (must be length 2)",
  geom_split_violin_sd(
    aes(x = group, y = y),
    data = some_split_data,
    split = split,
    fill = c("red", "green", "blue")
  )
)
demo_error(
  "geom_split_violin_sd(): outline_color length 3 (must be length 2)",
  geom_split_violin_sd(
    aes(x = group, y = y),
    data = some_split_data,
    split = split,
    outline_color = c("red", "green", "blue")
  )
)

## ---- reserved-dots warnings, shared across all three _sd geoms ----
demo_warning("geom_violin_sd(alpha = ...)", geom_violin_sd(alpha = 0.5))
demo_warning("geom_violin_sd(color = ...)", geom_violin_sd(color = "red"))
demo_warning("geom_violin_sd(linewidth = ...)", geom_violin_sd(linewidth = 2))
demo_warning("geom_violin_sd(trim = ...)", geom_violin_sd(trim = TRUE))
demo_warning(
  "geom_half_violin_sd(alpha = ...)",
  geom_half_violin_sd(alpha = 0.5)
)
demo_warning(
  "geom_split_violin_sd(alpha = ...)",
  geom_split_violin_sd(
    aes(x = group, y = y),
    data = some_split_data,
    split = split,
    alpha = 0.5
  )
)

## ---- split-specific `side`/`show.legend` reserved-dots warning (a
## different code path from the shared one above) ----
demo_warning(
  "geom_split_violin_sd(side = ...)",
  geom_split_violin_sd(
    aes(x = group, y = y),
    data = some_split_data,
    split = split,
    side = "l"
  )
)

## ---- plot_location_scale(): ellipse_alpha errors ----
demo_error(
  "plot_location_scale(): ellipse_alpha length mismatch",
  plot_location_scale(
    loc_scale_draws(),
    category = scenario,
    location = mu,
    sigma = sigma,
    ellipse_level = c(.5, .95),
    ellipse_alpha = c(.1, .2, .3)
  )
)
demo_error(
  "plot_location_scale(): ellipse_alpha = 1.5 (out of [0,1])",
  plot_location_scale(
    loc_scale_draws(),
    category = scenario,
    location = mu,
    sigma = sigma,
    ellipse_alpha = 1.5
  )
)
demo_error(
  "plot_location_scale(): ellipse_alpha = -0.2 (out of [0,1])",
  plot_location_scale(
    loc_scale_draws(),
    category = scenario,
    location = mu,
    sigma = sigma,
    ellipse_alpha = -0.2
  )
)

## ---- prepare_bf_contrasts(): pair not found / malformed contrast string ----
demo_error(
  "prepare_bf_contrasts(): requested pair not found",
  prepare_bf_contrasts(mu_bf(), pairs = list(c("nonexistent", "alsofake")))
)
demo_error(
  "prepare_bf_contrasts(): malformed contrast string (no ' - ' delimiter)",
  prepare_bf_contrasts(data.frame(contrast = "this has no delimiter"))
)

## ---- plot_location_scale(): location/sigma omitted - regression check for
## the 0.1.0 fix (old bug: cryptic recursive-default-argument error; should
## now be a plain missing-argument error) ----
demo_error(
  "plot_location_scale(): location/sigma omitted",
  plot_location_scale(loc_scale_draws(), category = scenario)
)

# ==== 19. COMPOSITE: PATCHWORK ACROSS PLOT TYPES ====
# gap: no coverage of patchwork composing genuinely different plot-builder
# types together (only facets of one type, elsewhere).

p19_a <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "_sd geom", x = NULL, y = NULL)

p19_b <- plot_ridge_hdi(
  mu_ridge_draws(),
  category = cond,
  value_limits = c(-2.3, 2.3)
) +
  labs(title = "plot_ridge_hdi()")

p19_c <- plot_bf_forest(
  mu_bf(),
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default
) +
  labs(title = "plot_bf_forest()")

p19_composite_default <- (p19_a + p19_b) / p19_c
print(p19_composite_default)

p19_composite_collected <- (p19_a + p19_b) /
  p19_c +
  plot_layout(guides = "collect")
print(p19_composite_collected)

# ==== 20. COMPOSITE: DARK THEME ACROSS THE SAME LAYOUT ====

use_theme_mt(dark = TRUE)

p20_a <- ggplot(gen_groups(3, 80), aes(group, y, fill = group)) +
  geom_violin_sd() +
  guides(fill = "none") +
  labs(title = "_sd geom (dark)", x = NULL, y = NULL)

p20_b <- plot_ridge_hdi(
  mu_ridge_draws(),
  category = cond,
  value_limits = c(-2.3, 2.3)
) +
  labs(title = "plot_ridge_hdi() (dark)")

p20_c <- plot_bf_forest(
  mu_bf(),
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default
) +
  labs(title = "plot_bf_forest() (dark)")

p20_composite <- (p20_a + p20_b) / p20_c

# dark = TRUE's transparent panel/plot backgrounds are only meaningful
# composited over a dark page - rendering against R's default white device
# background makes a CORRECTLY working dark theme look broken. Wrap it in an
# explicit dark background so the distinction is obvious.
print(
  p20_composite &
    theme(plot.background = element_rect(fill = "#151515", color = NA))
)

use_theme_mt() # back to the default light theme before later sections

# ==== 21. DISCRETE PALETTE AUTO-RESOLUTION VS. MANUAL scale_fill_manual() ====

palette_summary_5 <- aggregate(y ~ group, data = gen_groups(5, 40), FUN = mean)

p_palette_auto <- ggplot(palette_summary_5, aes(group, y, fill = group)) +
  geom_col() +
  guides(fill = "none") +
  labs(title = "theme_mt() auto palette (5 groups, no explicit scale)")
p_palette_manual <- ggplot(palette_summary_5, aes(group, y, fill = group)) +
  geom_col() +
  scale_fill_manual(values = mt_colors5) +
  guides(fill = "none") +
  labs(title = "explicit scale_fill_manual(mt_colors5) (5 groups)")
print(p_palette_auto + p_palette_manual)
cat(
  "The two panels above should be pixel-identical if theme_mt()'s auto-palette resolution matches an explicit scale_fill_manual(mt_colors5).\n"
)

## ---- 8 groups: confirmed overflow/blank-fill rough edge (only 5 colors
## in mt_colors5/dark_mt_colors5) ----
palette_summary_8 <- aggregate(y ~ group, data = gen_groups(8, 30), FUN = mean)

p_palette_overflow_light <- ggplot(
  palette_summary_8,
  aes(group, y, fill = group)
) +
  geom_col() +
  guides(fill = "none") +
  labs(
    title = "KNOWN ROUGH EDGE: 8 groups, theme_mt() auto palette - overflow groups render blank/NA"
  )
print(p_palette_overflow_light)

use_theme_mt(dark = TRUE)
p_palette_overflow_dark <- ggplot(
  palette_summary_8,
  aes(group, y, fill = group)
) +
  geom_col() +
  guides(fill = "none") +
  labs(title = "Same overflow, dark = TRUE (dark_mt_colors5, also 5 colors)")
print(
  p_palette_overflow_dark &
    theme(plot.background = element_rect(fill = "#151515", color = NA))
)
use_theme_mt()

# workaround: mt_colors_many(8) instead of the fixed 5-color palette
p_palette_workaround <- ggplot(palette_summary_8, aes(group, y, fill = group)) +
  geom_col() +
  scale_fill_manual(values = mt_colors_many(8)) +
  guides(fill = "none") +
  labs(title = "Workaround: scale_fill_manual(values = mt_colors_many(8))")
print(p_palette_workaround)

# ==== 22. theme_mt() OVERRIDES + COMPLEX REAL DATA ====
# Companion to Section 3's one-argument-at-a-time sweep: several overrides
# together, on a faceted real-data plot built by one of the package's own
# plot-builder functions (which sets its own local theme() tweaks, e.g.
# axis.text.y hjust = 1 - watch whether those survive underneath a full
# `+ theme_mt(...)` call, which replaces the WHOLE theme object rather than
# patching individual elements).

p_theme_overrides_complex <- plot_ridge_hdi(
  mu_ridge_draws(),
  category = cond,
  facet = trigger,
  facet_nrow = 2,
  value_limits = c(-2.3, 2.3)
) +
  theme_mt(
    base_size = 14,
    grid_color = "steelblue",
    axis_text_color = "darkorange",
    show_axis_line = FALSE
  ) +
  labs(
    title = "Multiple theme_mt() overrides combined on a faceted real-data plot"
  )
print(p_theme_overrides_complex)

# ==== 23. FONT DEEP-DIVE ON MARKDOWN-HEAVY REAL CONTENT ====
# plot_bf_forest() with direction_labels has bold titles, markdown axis
# text, and annotated arrow labels simultaneously - the busiest single
# rendering surface for text in the package. Rebuilt three times through
# use_theme_mt() (not a trailing `+ theme_mt(...)`, so plot_bf_forest()'s
# own local theme() overrides stay layered on top of the active base font,
# not replaced by it - see Section 22's note on that distinction).

bf_font_data <- mu_bf()

use_theme_mt(base_family = "Roboto Condensed") # default, not installed by this package
p_font_default <- plot_bf_forest(
  bf_font_data,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default,
  direction_labels = c("supports difference", "supports equivalence")
) +
  labs(
    title = "base_family = 'Roboto Condensed' (default, not installed by this package)"
  )
print(p_font_default)

use_theme_mt(base_family = "") # roxygen-documented reliable fallback
p_font_empty <- plot_bf_forest(
  bf_font_data,
  contrast = contrast,
  log_bf = log_BF,
  pairs = bf_pairs_default,
  direction_labels = c("supports difference", "supports equivalence")
) +
  labs(title = "base_family = '' (roxygen-documented reliable fallback)")
print(p_font_empty)

if (length(installed_families) > 0) {
  alt_family <- installed_families[1]
  use_theme_mt(base_family = alt_family)
  p_font_alt <- plot_bf_forest(
    bf_font_data,
    contrast = contrast,
    log_bf = log_BF,
    pairs = bf_pairs_default,
    direction_labels = c("supports difference", "supports equivalence")
  ) +
    labs(
      title = paste0(
        "base_family = '",
        alt_family,
        "' (confirmed installed via systemfonts)"
      )
    )
  print(p_font_alt)
}

use_theme_mt() # restore the default active theme before later sections

cat(
  "Judge the three plots above in the device you actually view plots in",
  "(RStudio plot pane / quartz / etc) - systemfonts::match_fonts() can",
  "report a font as resolved even when the rendering device you're using",
  "can't find it. Also watch whether plot_bf_forest()'s right-aligned",
  "contrast labels (axis.text.y hjust = 1) survived in all three.\n"
)

# ==== 24. WRAP-UP ====
# No code - a reminder of how to report back per section:
#   - BUG: something clearly broken (an error where none is documented, a
#     crash, or visibly wrong output).
#   - ROUGH EDGE: works, but surprising, easy to misuse, or worth smoothing
#     over in a future release (e.g. Section 21's 5-color palette overflow).
#   - SPEC GAP: current behavior is defensible but undocumented, or a
#     combination of arguments has no clearly "right" answer yet.
# Also worth noting: which sections looked identical to their vignette/test
# counterparts (nothing new found) vs. which surfaced something worth a
# follow-up issue.
