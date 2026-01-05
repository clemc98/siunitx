# siunitx for HTML (Quarto Extension)

Render a small subset of `siunitx` macros to HTML in Quarto. LaTeX/PDF output is untouched, and inline math like `$...$` is supported.

## Install

```bash
quarto add USER/siunitx
```

## Use

```yaml
filters:
  - siunitx
```

Or only for HTML:

```yaml
format:
  html:
    filters:
      - siunitx
```

## Supported macros

- `\SI{num}{unit}`
- `\si{unit}`
- `\num{num}`
- `\SIrange{a}{b}{unit}`
- `\numrange{a}{b}`
- `\SIlist{a; b; c}{unit}`
- `\numlist{a; b; c}`
- `\ang{d; m; s}` (simple degrees/minutes/seconds)

Common SI units and prefixes are mapped (for example `\kilo\meter`, `\newton`). Unknown unit commands are rendered without the leading backslash.

## Options

```yaml
siunitx:
  decimal-marker: "."
  number-unit-separator: "&nbsp;"
  range-phrase: "\\text{ to }"
  list-final-separator: " and "
  per-mode: "symbol" # or "word"
```

Notes:
- `range-phrase` is a siunitx-compatible alias for the range separator.
- `*-separator-math` can be given as TeX (for example `\\text{ et }`).
- Other `siunitx` keys are ignored by this filter.

## Example

Render the sample file:

```bash
quarto render example.qmd
```

## Limitations

This is a lightweight renderer, not a full `siunitx` implementation.
