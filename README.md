# siunitx for HTML (Quarto Extension)

This Quarto extension lets you use common `siunitx` LaTeX macros in `.qmd` files and still get readable HTML output. The filter converts a small subset of macros to HTML when the output format is HTML, and it leaves everything unchanged for LaTeX/PDF. It also works when the macros are inside inline math delimiters like `$...$`.

## Install

```bash
quarto add USER/siunitx
```

## Use

Enable the filter in your document or project:

```yaml
filters:
  - siunitx
```

If you only want it for HTML output:

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

Common SI units and prefixes are mapped (for example `\kilo\meter`, `\newton`, `\milli\second`). Unknown unit commands are rendered without the leading backslash.

## Options

Set options in document or project metadata:

```yaml
siunitx:
  decimal-marker: "."
  number-unit-separator: "&nbsp;"
  number-unit-separator-html: "&nbsp;"
  number-unit-separator-math: "\\,"
  range-separator: " to "
  range-phrase: "\\text{ to }"
  range-separator-math: "\\text{ to }"
  list-separator: ", "
  list-separator-math: ",\\,"
  list-final-separator: " and "
  list-final-separator-math: "\\text{ and }"
  per-mode: "symbol" # or "word"
```

YAML uses `:` for key/value pairs. You can also keep other `siunitx` keys for compatibility; unsupported options are ignored by this filter.

Notes:
- `number-unit-separator` overrides both HTML and math separators.
- `range-phrase` is a siunitx-compatible alias for the range separator.
- `*-separator-math` can be given as TeX (for example `\\text{ et }`).
- `per-mode: word` renders `\per` as `per`.
- Math defaults use `\text{...}` for word joiners to keep accents readable.

## Styling hooks

HTML output uses these classes:

- `siunitx`
- `siunitx-number`
- `siunitx-unit`

## Example

See `example.qmd` for a complete example. The extension is stored in `_extensions/siunitx`, so you can render it directly:

```bash
quarto render example.qmd
```

## Limitations

This is a lightweight renderer, not a full `siunitx` implementation. It does not cover all options and numeric formatting rules, and it keeps unit symbols in ASCII (for example `degC`, `ohm`).
