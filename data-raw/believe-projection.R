# Prepares the anonymized `believe_projection` package data from the raw
# results of Thalmann & Matticchio (2024, AC Proceedings;
# https://platform.openjournals.nl/PAC/article/view/21865). Source CSV lives
# outside this repo, in the sibling `believe-projection` project.
#
# Participants' consent covers publishing the trial-level data, including
# the demographic columns kept here (age, gender, the debrief response
# `which`) and response times; it does not cover raw identifiers.
#
# Anonymization applied:
#   - `payment_code` (real participant payment identifier), `handed`,
#     `lang`, `study`, `caff` dropped entirely - not needed for any plot in
#     this package and (for `payment_code`) not fit to share regardless.
#   - `id` (an MD5 hash of the participant's IP address) replaced with a
#     fresh `p01`..`p34` code, assigned via a random permutation, so it
#     carries no link back to the original hash or enrollment order.
library(dplyr)

raw_csv <- "~/Desktop/LaTeX/believe-projection/data/believe-projection.csv"

set.seed(2024)
believe_projection <- read.csv(raw_csv, stringsAsFactors = FALSE) |>
  select(
    -payment_code,
    -handed,
    -lang,
    -study,
    -caff
  ) |>
  mutate(
    id = factor(id, levels = sample(unique(id))),
    id = sprintf("p%02d", as.integer(id))
  ) |>
  as_tibble()

usethis::use_data(believe_projection, overwrite = TRUE)
