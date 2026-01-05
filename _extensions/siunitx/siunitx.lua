local stringify = pandoc.utils.stringify

local opts = {
  decimal_marker = ".",
  range_separator = " to ",
  list_separator = ", ",
  list_final_separator = ", and ",
  number_unit_separator_html = "&nbsp;",
  number_unit_separator_math = "\\,",
  per_mode = "symbol",
  per_symbol_html = "/",
  per_symbol_math = "/",
}

local macro_list = {
  {name = "SIrange", args = 3},
  {name = "SIlist", args = 2},
  {name = "numrange", args = 2},
  {name = "numlist", args = 1},
  {name = "SI", args = 2},
  {name = "si", args = 1},
  {name = "num", args = 1},
  {name = "ang", args = 1},
}

local default_separators = {
  range_separator = " to ",
  list_separator = ", ",
  list_final_separator = " and ",
  range_separator_math = "\\text{ to }",
  list_separator_math = ",\\,",
  list_final_separator_math = "\\text{ and }",
  per_word = " per ",
}

local prefix_map = {
  yocto = "y",
  zepto = "z",
  atto = "a",
  femto = "f",
  pico = "p",
  nano = "n",
  micro = "u",
  milli = "m",
  centi = "c",
  deci = "d",
  deca = "da",
  hecto = "h",
  kilo = "k",
  mega = "M",
  giga = "G",
  tera = "T",
  peta = "P",
  exa = "E",
  zetta = "Z",
  yotta = "Y",
}

local unit_map = {
  metre = "m",
  meter = "m",
  gram = "g",
  kilogram = "kg",
  second = "s",
  minute = "min",
  hour = "h",
  day = "d",
  ampere = "A",
  kelvin = "K",
  mole = "mol",
  candela = "cd",
  hertz = "Hz",
  newton = "N",
  pascal = "Pa",
  joule = "J",
  watt = "W",
  coulomb = "C",
  volt = "V",
  farad = "F",
  ohm = "ohm",
  siemens = "S",
  weber = "Wb",
  tesla = "T",
  henry = "H",
  lumen = "lm",
  lux = "lx",
  becquerel = "Bq",
  gray = "Gy",
  sievert = "Sv",
  katal = "kat",
  litre = "L",
  liter = "L",
  radian = "rad",
  steradian = "sr",
  degree = "deg",
  degreeCelsius = "degC",
  celsius = "degC",
  percent = "%",
  bar = "bar",
  atmosphere = "atm",
  barn = "b",
  knot = "kn",
  neper = "Np",
  bel = "B",
  byte = "B",
  bit = "bit",
  dalton = "Da",
  electronvolt = "eV",
  astronomicalunit = "au",
}

local function is_html_format()
  return FORMAT and FORMAT:match("html") ~= nil
end

local function trim(text)
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function inlines_to_string(inlines)
  local parts = {}
  for _, inline in ipairs(inlines) do
    local t = inline.t
    if t == "Str" then
      table.insert(parts, inline.text)
    elseif t == "Space" or t == "SoftBreak" or t == "LineBreak" then
      table.insert(parts, " ")
    elseif t == "Code" then
      table.insert(parts, inline.text)
    elseif t == "RawInline" then
      table.insert(parts, inline.text)
    elseif t == "Math" then
      table.insert(parts, inline.text)
    elseif t == "Span" then
      table.insert(parts, inlines_to_string(inline.content))
    else
      table.insert(parts, stringify(inline))
    end
  end
  return table.concat(parts)
end

local function meta_to_string(value)
  if value == nil then
    return nil
  end
  if type(value) == "string" then
    return value
  end
  local t = pandoc.utils.type(value)
  if t == "Inlines" or t == "MetaInlines" then
    return inlines_to_string(value)
  end
  if t == "MetaString" and value.text then
    return value.text
  end
  if t == "MetaBool" then
    return value and "true" or "false"
  end
  return stringify(value)
end

local function get_cfg(cfg, key, default)
  if not cfg then
    return default
  end
  local value = cfg[key]
  if value == nil then
    value = cfg[key:gsub("_", "-")]
  end
  if value == nil then
    value = cfg[key:gsub("-", "_")]
  end
  if value == nil then
    return default
  end
  local str = meta_to_string(value)
  if str == nil or str == "" then
    return default
  end
  return str
end

local function read_options(meta)
  local cfg = meta.siunitx
  local options = {}
  local function to_math_separator(text)
    return text:gsub("%s+", "\\,")
  end
  local function strip_ensuremath(text)
    local trimmed = trim(text)
    while true do
      local inner = trimmed:match("^\\\\ensuremath%s*{(.-)}%s*$")
      if not inner then
        break
      end
      trimmed = inner
    end
    return trimmed
  end
  local function unwrap_tex_text(text)
    local inner = text:match("^\\\\text%s*{(.-)}%s*$")
    if inner then
      return inner
    end
    inner = text:match("^\\\\mathrm%s*{(.-)}%s*$")
    if inner then
      return inner
    end
    return nil
  end
  local function has_letters(text)
    return text:find("%a") ~= nil or text:find("[\128-\255]") ~= nil
  end
  local function math_from_plain(text)
    if has_letters(text) then
      return "\\text{" .. text .. "}"
    end
    return to_math_separator(text)
  end
  local function normalize_separator(raw, raw_math, default_text, default_math)
    local html = default_text
    local math = default_math
    if raw and trim(raw) ~= "" then
      local stripped = strip_ensuremath(raw)
      local inner = unwrap_tex_text(stripped)
      if inner then
        html = inner
        if not raw_math then
          math = "\\text{" .. inner .. "}"
        end
      else
        html = stripped
        if not raw_math then
          if stripped:find("\\") then
            math = stripped
          else
            math = math_from_plain(stripped)
          end
        end
      end
    end
    if raw_math and trim(raw_math) ~= "" then
      local stripped_math = strip_ensuremath(raw_math)
      math = stripped_math
      if not raw or trim(raw) == "" then
        local inner = unwrap_tex_text(stripped_math)
        if inner then
          html = inner
        end
      end
    end
    return html, math
  end

  options.decimal_marker = get_cfg(cfg, "decimal-marker", ".")
  local raw_range = get_cfg(cfg, "range-separator", nil)
    or get_cfg(cfg, "range-phrase", nil)
  local raw_range_math = get_cfg(cfg, "range-separator-math", nil)
    or get_cfg(cfg, "range-phrase-math", nil)
  local raw_list = get_cfg(cfg, "list-separator", nil)
  local raw_list_math = get_cfg(cfg, "list-separator-math", nil)
  local raw_list_final = get_cfg(cfg, "list-final-separator", nil)
  local raw_list_final_math = get_cfg(cfg, "list-final-separator-math", nil)
  options.per_mode = get_cfg(cfg, "per-mode", "symbol")


  local common_sep = get_cfg(cfg, "number-unit-separator", nil)
  if common_sep then
    options.number_unit_separator_html = common_sep
    options.number_unit_separator_math = common_sep
  else
    options.number_unit_separator_html = get_cfg(cfg, "number-unit-separator-html", "&nbsp;")
    options.number_unit_separator_math = get_cfg(cfg, "number-unit-separator-math", "\\,")
  end

  if options.per_mode == "word" then
    local per_word = default_separators.per_word
    options.per_symbol_html = per_word
    options.per_symbol_math = to_math_separator(per_word)
  else
    options.per_symbol_html = "/"
    options.per_symbol_math = "/"
  end

  options.range_separator, options.range_separator_math = normalize_separator(
    raw_range,
    raw_range_math,
    default_separators.range_separator,
    default_separators.range_separator_math
  )
  options.list_separator, options.list_separator_math = normalize_separator(
    raw_list,
    raw_list_math,
    default_separators.list_separator,
    default_separators.list_separator_math
  )
  options.list_final_separator, options.list_final_separator_math = normalize_separator(
    raw_list_final,
    raw_list_final_math,
    default_separators.list_final_separator,
    default_separators.list_final_separator_math
  )

  return options
end

local function escape_html(text)
  return text
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub("\"", "&quot;")
    :gsub("'", "&#39;")
end

local function escape_tex(text)
  return text:gsub("%%", "\\%%"):gsub("_", "\\_")
end

local function skip_spaces(text, index)
  local i = index
  while i <= #text and text:sub(i, i):match("%s") do
    i = i + 1
  end
  return i
end

local function read_braced_arg(text, index)
  if text:sub(index, index) ~= "{" then
    return nil, index
  end
  local depth = 0
  local start = index + 1
  local i = index
  while i <= #text do
    local ch = text:sub(i, i)
    if ch == "{" then
      depth = depth + 1
    elseif ch == "}" then
      depth = depth - 1
      if depth == 0 then
        return text:sub(start, i - 1), i + 1
      end
    end
    i = i + 1
  end
  return nil, index
end

local function read_bracket_arg(text, index)
  if text:sub(index, index) ~= "[" then
    return nil, index
  end
  local depth = 0
  local start = index + 1
  local i = index
  while i <= #text do
    local ch = text:sub(i, i)
    if ch == "[" then
      depth = depth + 1
    elseif ch == "]" then
      depth = depth - 1
      if depth == 0 then
        return text:sub(start, i - 1), i + 1
      end
    end
    i = i + 1
  end
  return nil, index
end

local function match_macro(text, pos)
  for _, macro in ipairs(macro_list) do
    if text:sub(pos, pos + #macro.name - 1) == macro.name then
      return macro
    end
  end
  return nil
end

local function parse_segments(text)
  local segments = {}
  local changed = false
  local i = 1
  local last = 1
  while i <= #text do
    if text:sub(i, i) == "\\" then
      local macro = match_macro(text, i + 1)
      if macro then
        local j = i + 1 + #macro.name
        j = skip_spaces(text, j)
        local _, next_j = read_bracket_arg(text, j)
        if next_j ~= j then
          j = next_j
        end
        local args = {}
        local ok = true
        for _ = 1, macro.args do
          j = skip_spaces(text, j)
          local arg
          arg, j = read_braced_arg(text, j)
          if not arg then
            ok = false
            break
          end
          table.insert(args, arg)
        end
        if ok then
          if i > last then
            table.insert(segments, {type = "text", value = text:sub(last, i - 1)})
          end
          local raw = text:sub(i, j - 1)
          table.insert(segments, {type = "macro", name = macro.name, args = args, raw = raw})
          changed = true
          i = j
          last = i
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  if last <= #text then
    table.insert(segments, {type = "text", value = text:sub(last)})
  end

  return segments, changed
end

local function split_list(text)
  local items = {}
  local sep = ";"
  if not text:find(";", 1, true) then
    sep = ","
  end
  for item in text:gmatch("[^" .. sep .. "]+") do
    local trimmed = trim(item)
    if trimmed ~= "" then
      table.insert(items, trimmed)
    end
  end
  return items
end

local function join_list(items, sep, final_sep)
  if #items == 0 then
    return ""
  end
  if #items == 1 then
    return items[1]
  end
  if #items == 2 then
    return items[1] .. final_sep .. items[2]
  end
  return table.concat(items, sep, 1, #items - 1) .. final_sep .. items[#items]
end

local function format_number(value)
  local text = trim(value)
  if opts.decimal_marker ~= "." then
    text = text:gsub("%.", opts.decimal_marker)
  end
  return text
end

local function format_unit(value, per_symbol)
  local out = {}
  local i = 1
  local power_next = nil

  local function append_text(text, apply_power)
    local result = text
    if apply_power and power_next and result ~= "" then
      result = result .. "^" .. power_next
      power_next = nil
    end
    table.insert(out, result)
  end

  while i <= #value do
    local ch = value:sub(i, i)
    if ch == "\\" then
      local cmd = value:match("^\\([A-Za-z]+)", i)
      if cmd then
        local advance = #cmd + 1
        if cmd == "per" then
          append_text(per_symbol, false)
          i = i + advance
        elseif cmd == "square" then
          power_next = "2"
          i = i + advance
        elseif cmd == "cubic" then
          power_next = "3"
          i = i + advance
        elseif cmd == "squared" then
          if #out > 0 then
            out[#out] = out[#out] .. "^2"
          else
            append_text("^2", false)
          end
          i = i + advance
        elseif cmd == "cubed" then
          if #out > 0 then
            out[#out] = out[#out] .. "^3"
          else
            append_text("^3", false)
          end
          i = i + advance
        elseif cmd == "text" or cmd == "mathrm" then
          local arg, next_i = read_braced_arg(value, i + advance)
          if arg then
            append_text(arg, false)
            i = next_i
          else
            append_text(cmd, false)
            i = i + advance
          end
        else
          local prefix = prefix_map[cmd]
          local unit = unit_map[cmd]
          if prefix then
            append_text(prefix, false)
            i = i + advance
          elseif unit then
            append_text(unit, true)
            i = i + advance
          else
            append_text(cmd, false)
            i = i + advance
          end
        end
      else
        append_text(ch, false)
        i = i + 1
      end
    else
      if ch == "~" then
        append_text(" ", false)
      else
        append_text(ch, false)
      end
      i = i + 1
    end
  end

  return table.concat(out)
end

local function format_angle(value)
  local parts = {}
  for item in value:gmatch("[^;]+") do
    local trimmed = trim(item)
    if trimmed ~= "" then
      table.insert(parts, trimmed)
    end
  end

  local labels = {" deg", " min", " s"}
  local out = {}
  for i, part in ipairs(parts) do
    local label = labels[i] or ""
    table.insert(out, format_number(part) .. label)
  end
  return table.concat(out, " ")
end

local function render_macro_html(name, args)
  if name == "num" then
    local number = format_number(args[1])
    return "<span class=\"siunitx siunitx-number\">" .. escape_html(number) .. "</span>"
  elseif name == "si" then
    local unit = format_unit(args[1], opts.per_symbol_html)
    return "<span class=\"siunitx siunitx-unit\">" .. escape_html(unit) .. "</span>"
  elseif name == "SI" then
    local number = format_number(args[1])
    local unit = format_unit(args[2], opts.per_symbol_html)
    return "<span class=\"siunitx\"><span class=\"siunitx-number\">" .. escape_html(number) .. "</span>" .. opts.number_unit_separator_html .. "<span class=\"siunitx-unit\">" .. escape_html(unit) .. "</span></span>"
  elseif name == "numrange" then
    local first = format_number(args[1])
    local second = format_number(args[2])
    return "<span class=\"siunitx\">" .. escape_html(first) .. opts.range_separator .. escape_html(second) .. "</span>"
  elseif name == "SIrange" then
    local first = format_number(args[1])
    local second = format_number(args[2])
    local unit = format_unit(args[3], opts.per_symbol_html)
    return "<span class=\"siunitx\">" .. escape_html(first) .. opts.range_separator .. escape_html(second) .. opts.number_unit_separator_html .. escape_html(unit) .. "</span>"
  elseif name == "numlist" then
    local items = split_list(args[1])
    local escaped = {}
    for _, item in ipairs(items) do
      table.insert(escaped, escape_html(format_number(item)))
    end
    return "<span class=\"siunitx\">" .. join_list(escaped, opts.list_separator, opts.list_final_separator) .. "</span>"
  elseif name == "SIlist" then
    local items = split_list(args[1])
    local escaped = {}
    for _, item in ipairs(items) do
      table.insert(escaped, escape_html(format_number(item)))
    end
    local unit = format_unit(args[2], opts.per_symbol_html)
    return "<span class=\"siunitx\">" .. join_list(escaped, opts.list_separator, opts.list_final_separator) .. opts.number_unit_separator_html .. escape_html(unit) .. "</span>"
  elseif name == "ang" then
    local angle = format_angle(args[1])
    return "<span class=\"siunitx\">" .. escape_html(angle) .. "</span>"
  end
  return nil
end

local function render_macro_math(name, args)
  local function math_text(text)
    return "\\mathrm{" .. text .. "}"
  end

  if name == "num" then
    return format_number(args[1])
  elseif name == "si" then
    local unit = format_unit(args[1], opts.per_symbol_math)
    return "\\mathrm{" .. escape_tex(unit) .. "}"
  elseif name == "SI" then
    local number = format_number(args[1])
    local unit = format_unit(args[2], opts.per_symbol_math)
    return "\\mathrm{" .. number .. opts.number_unit_separator_math .. escape_tex(unit) .. "}"
  elseif name == "numrange" then
    local first = format_number(args[1])
    local second = format_number(args[2])
    return math_text(first) .. opts.range_separator_math .. math_text(second)
  elseif name == "SIrange" then
    local first = format_number(args[1])
    local second = format_number(args[2])
    local unit = format_unit(args[3], opts.per_symbol_math)
    return math_text(first)
      .. opts.range_separator_math
      .. math_text(second)
      .. opts.number_unit_separator_math
      .. math_text(escape_tex(unit))
  elseif name == "numlist" then
    local items = split_list(args[1])
    local formatted = {}
    for _, item in ipairs(items) do
      table.insert(formatted, math_text(format_number(item)))
    end
    return join_list(formatted, opts.list_separator_math, opts.list_final_separator_math)
  elseif name == "SIlist" then
    local items = split_list(args[1])
    local formatted = {}
    for _, item in ipairs(items) do
      table.insert(formatted, math_text(format_number(item)))
    end
    local unit = format_unit(args[2], opts.per_symbol_math)
    return join_list(formatted, opts.list_separator_math, opts.list_final_separator_math)
      .. opts.number_unit_separator_math
      .. math_text(escape_tex(unit))
  elseif name == "ang" then
    local angle = format_angle(args[1])
    return "\\mathrm{" .. escape_tex(angle) .. "}"
  end
  return nil
end

local function handle_str(el)
  if not is_html_format() then
    return nil
  end
  if not el.text:find("\\") then
    return nil
  end
  local segments, changed = parse_segments(el.text)
  if not changed then
    return nil
  end

  local inlines = {}
  for _, segment in ipairs(segments) do
    if segment.type == "text" then
      if segment.value ~= "" then
        table.insert(inlines, pandoc.Str(segment.value))
      end
    else
      local html = render_macro_html(segment.name, segment.args)
      if html then
        table.insert(inlines, pandoc.RawInline("html", html))
      else
        table.insert(inlines, pandoc.Str(segment.raw))
      end
    end
  end

  if #inlines == 0 then
    return nil
  end
  return inlines
end

local function handle_raw(el, is_block)
  if not is_html_format() then
    return nil
  end
  if el.format ~= "tex" and el.format ~= "latex" then
    return nil
  end
  local trimmed = trim(el.text)
  local segments, changed = parse_segments(trimmed)
  if not changed then
    return nil
  end
  if #segments == 1 and segments[1].type == "macro" then
    local html = render_macro_html(segments[1].name, segments[1].args)
    if html then
      if is_block then
        return pandoc.RawBlock("html", html)
      end
      return pandoc.RawInline("html", html)
    end
  end
  return nil
end

local function handle_math(el)
  if not is_html_format() then
    return nil
  end
  if not el.text:find("\\") then
    return nil
  end
  local segments, changed = parse_segments(el.text)
  if not changed then
    return nil
  end

  local out = {}
  for _, segment in ipairs(segments) do
    if segment.type == "text" then
      table.insert(out, segment.value)
    else
      local tex = render_macro_math(segment.name, segment.args)
      if tex then
        table.insert(out, tex)
      else
        table.insert(out, segment.raw)
      end
    end
  end

  return pandoc.Math(el.mathtype, table.concat(out))
end

function Pandoc(doc)
  opts = read_options(doc.meta)
  if not is_html_format() then
    return doc
  end
  return doc:walk({
    Str = handle_str,
    RawInline = function(el)
      return handle_raw(el, false)
    end,
    RawBlock = function(el)
      return handle_raw(el, true)
    end,
    Math = handle_math,
  })
end
