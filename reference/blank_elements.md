# Hide theme elements together with everything that inherits from them

With
[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md),
`theme(axis.text.y = element_blank())` does not hide the y tick labels.
ggplot2 (as of 4.0.3) resolves axis labels through the position-specific
children (`axis.text.y.left`, `axis.text.y.right`), and a child only
becomes blank with its parent if it has `inherit.blank = TRUE`.
[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)
has to set those children explicitly with
[`ggtext::element_markdown()`](https://wilkelab.org/ggtext/reference/element_markdown.html),
or markdown would be drawn as literal text, and ggplot2 ignores
`inherit.blank` for such S3 elements. Blanking the parent therefore
leaves them drawn.

## Usage

``` r
blank_elements(...)
```

## Arguments

- ...:

  Names of theme elements, as character strings, e.g. `"axis.text.y"`,
  `"axis.title"` or `"strip.text"`.

## Value

A `ggplot2` theme object, to be added to a plot or theme.

## Details

`blank_elements()` sidesteps this by blanking the named elements and all
of their descendants in ggplot2's element tree, so
`blank_elements("axis.text.y")` is the
[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)
equivalent of `theme(axis.text.y = element_blank())` under a built-in
ggplot2 theme. Native elements such as `panel.grid` or `axis.line` do
not need it, since a blank parent reaches them anyway, but they are
accepted too.

Because the descendants are blanked explicitly, a later
`theme(axis.text.y.left = element_markdown(...))` brings that one child
back, as it would under any theme.

## See also

[`theme_mt()`](https://mkthalmann.github.io/emptyviz/reference/theme_mt.md)

## Examples

``` r
library(ggplot2)
ggplot(mtcars, aes(wt, mpg)) +
  geom_point() +
  theme_mt(base_family = "") +
  blank_elements("axis.text.y", "axis.title.y")
```
