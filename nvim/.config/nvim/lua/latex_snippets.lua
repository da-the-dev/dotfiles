-- LaTeX snippets for math in markdown, like Obsidian's latex-suite: type `mk`, then e.g. `x/`, `@a`,
-- `sr`. Most expand by themselves; the ones under `tab` need <Tab>. Built on LuaSnip.
-- The list comes from an Obsidian vault, based on latex-suite's defaults (MIT, (c) artisticat1:
-- https://github.com/artisticat1/obsidian-latex-suite). Not ported: matrix keys, bracket pairs, tabout,
-- auto-enlarged brackets.
local M = {}

-- Names usable in regex triggers
local vars = {
  GREEK = "alpha|beta|gamma|Gamma|delta|Delta|epsilon|varepsilon|zeta|eta|theta|Theta|iota|kappa|lambda"
    .. "|Lambda|mu|nu|omicron|xi|Xi|pi|Pi|rho|sigma|Sigma|tau|upsilon|Upsilon|varphi|phi|Phi|chi|psi|Psi"
    .. "|omega|Omega",
  SYMBOL = "hbar|ell|nabla|infty|dots|leftrightarrow|mapsto|setminus|mid|bigcap|bigcup|cap|cup|land|lor"
    .. "|subseteq|subset|implies|impliedby|iff|exists|forall|equiv|square|neq|geq|leq|gg|ll|sim|simeq"
    .. "|approx|propto|cdot|oplus|otimes|times|star|perp|det|exp|ln|log|partial",
  SHORT_SYMBOL = "to|pm|mp",
}

-- { trigger, replacement, re = true, priority = n, word = true }
--   replacement: $0, $1, ... are the fields in <Tab> order (${0:x} with a default), [[0]] the first
--   group of a regex trigger. re: a vim regex (very magic, ":h /\v").
--   Where several match, the higher priority wins, then the longer trigger.

local auto = {
  -- Math mode
  { "beg", "\\begin{$0}\n$1\n\\end{$0}" },
  -- Greek letters
  { "@a", [[\alpha]] }, { "@A", [[\alpha]] }, { "@b", [[\beta]] }, { "@B", [[\beta]] }, { "@c", [[\chi]] },
  { "@C", [[\chi]] }, { "@g", [[\gamma]] }, { "@G", [[\Gamma]] }, { "@d", [[\delta]] },
  { "@D", [[\Delta]] }, { "@e", [[\epsilon]] }, { "@E", [[\epsilon]] }, { ":e", [[\varepsilon]] },
  { ":E", [[\varepsilon]] }, { "@z", [[\zeta]] }, { "@Z", [[\zeta]] }, { "@t", [[\theta]] },
  { "@T", [[\Theta]] }, { "@k", [[\kappa]] }, { "@K", [[\kappa]] }, { "@l", [[\lambda]] },
  { "@L", [[\Lambda]] }, { "@m", [[\mu]] }, { "@M", [[\mu]] }, { "@r", [[\rho]] }, { "@R", [[\rho]] },
  { "@s", [[\sigma]] }, { "@S", [[\Sigma]] }, { "ome", [[\omega]] }, { "@o", [[\omega]] },
  { "@O", [[\Omega]] }, { [[(^|[^\\])(${GREEK}|${SYMBOL})]], "[[0]]\\[[1]]", re = true },
  -- Insert space after greek letters and symbols, etc
  { [[\\(${GREEK}|${SYMBOL}|${SHORT_SYMBOL})([A-Za-z])]], "\\[[0]] [[1]]", re = true },
  { [[\\(${GREEK}|${SYMBOL}) sr]], "\\[[0]]^{2}", re = true },
  { [[\\(${GREEK}|${SYMBOL}) rd]], "\\[[0]]^{$0}$1", re = true },
  { [[\\(${GREEK}|${SYMBOL}) hat]], "\\hat{\\[[0]]}", re = true },
  { [[\\(${GREEK}|${SYMBOL}) dot]], "\\dot{\\[[0]]}", re = true },
  { [[\\(${GREEK}|${SYMBOL}) bar]], "\\bar{\\[[0]]}", re = true },
  { [[\\(${GREEK}|${SYMBOL}) vec]], "\\vec{\\[[0]]}", re = true },
  { [[\\(${GREEK}|${SYMBOL}) tilde]], "\\tilde{\\[[0]]}", re = true },
  { [[\\(${GREEK}|${SYMBOL}) und]], "\\underline{\\[[0]]}", re = true },
  { [[\\(${GREEK}),\.]], "\\boldsymbol{\\[[0]]}", re = true },
  { [[\\(${GREEK})\.,]], "\\boldsymbol{\\[[0]]}", re = true },
  -- Operations
  { "text", [[\text{$0}]] }, { "bf", [[\mathbf{$0}]] }, { "sr", "^{2}" }, { "rd", "^{$0}$1" },
  { "_", "_{$0}$1" }, { "^", "^{$0}$1" }, { "sts", [[_\text{$0}]] }, { "sq", [[\sqrt{ $0 }$1]] },
  { "//", [[\dfrac{$0}{$1}$2]] }, { "rm", [[\mathrm{$0}$1]] }, { "conj", "^{*}" },
  { "trace", [[\mathrm{Tr}]] }, { "det", [[\det]] }, { [[([a-zA-Z]),\.]], "\\mathbf{[[0]]}", re = true },
  { [[([a-zA-Z])\.,]], "\\mathbf{[[0]]}", re = true },
  { [[([A-Za-z])(\d)]], "[[0]]_{[[1]]}", re = true, priority = -1 },
  { [[([A-Za-z])_(\d\d)]], "[[0]]_{[[1]]}", re = true },
  { [[hat\{([A-Za-z])\}(\d)]], "hat{[[0]]}_{[[1]]}", re = true },
  { [[\\mathbf\{([A-Za-z])\}(\d)]], "\\mathbf{[[0]]}_{[[1]]}", re = true },
  { [[\\vec\{([A-Za-z])\}(\d)]], "\\vec{[[0]]}_{[[1]]}", re = true },
  { "([a-zA-Z])bar", "\\bar{[[0]]}", re = true }, { "([a-zA-Z])hat", "\\hat{[[0]]}", re = true },
  { "([a-zA-Z])ddot", "\\ddot{[[0]]}", re = true, priority = 3 },
  { "([a-zA-Z])dot", "\\dot{[[0]]}", re = true, priority = 1 },
  { "([a-zA-Z])vec", "\\vec{[[0]]}", re = true }, { "([a-zA-Z])tilde", "\\tilde{[[0]]}", re = true },
  { "([a-zA-Z])und", "\\underline{[[0]]}", re = true }, { "bar", [[\bar{$0}$1]] },
  { "hat", [[\hat{$0}$1]] }, { "dot", [[\dot{$0}$1]] }, { "ddot", [[\ddot{$0}$1]], priority = 2 },
  { "vec", [[\vec{$0}$1]] }, { "tilde", [[\tilde{$0}$1]] }, { "und", [[\underline{$0}$1]] },
  { [[(^|[^\\])(arcsin|arccos|arctan|arccot|arccsc|arcsec|sin|cos|tan|cot|csc)]], "[[0]]\\[[1]]", re = true },
  { [[\\(arcsin|arccos|arctan|arccot|arccsc|arcsec|sin|cos|tan|cot|csc)([A-Za-gi-z])]], "\\[[0]] [[1]]", re = true },
  { [[\\(arcsinh|arccosh|arctanh|arccoth|arcsch|arcsech|sinh|cosh|tanh|coth|csch)([A-Za-z])]], "\\[[0]] [[1]]", re = true },
  { [[\\(neq|geq|leq|gg|ll|sim)([0-9]+)]], "\\[[0]] [[1]]", re = true },
  -- Symbols
  { "ooo", [[\infty]] }, { "sum", [[\sum]] }, { "prod", [[\prod]] },
  { "lim", [[\lim_{ ${0:n} \to ${1:\infty} } $2]] }, { "+-", [[\pm]] }, { "-+", [[\mp]] },
  { "...", [[\dots]] }, { "<->", [[\leftrightarrow ]] }, { "->", [[\to]] }, { "!>", [[\mapsto]] },
  { "invs", "^{-1}" }, { [[\\\]], [[\setminus]] }, { "||", [[\mid]] }, { "and", [[\cap]] },
  { "orr", [[\cup]] }, { "inn", [[\in]] }, { [[\subset eq]], [[\subseteq]] }, { "set", [[\{ $0 \}$1]] },
  { "=>", [[\implies]] }, { "=<", [[\impliedby]] }, { "iff", [[\iff]] },
  { [[e\xi sts]], [[\exists]], priority = 1 }, { "===", [[\equiv]] }, { "Sq", [[\square]] },
  { "!=", [[\neq]] }, { ">=", [[\geq]] }, { "<=", [[\leq]] }, { ">>", [[\gg]] }, { "<<", [[\ll]] },
  { "~~", [[\sim]] }, { [[\sim ~]], [[\approx]] }, { "prop", [[\propto]] }, { "nabl", [[\nabla]] },
  { "del", [[\nabla]] }, { "xx", [[\times]] }, { "**", [[\cdot]] }, { "para", [[\parallel]] },
  { "xnn", "x_{n}" }, { "xii", "x_{i}" }, { "xjj", "x_{j}" }, { "xp1", "x_{n+1}" }, { "ynn", "y_{n}" },
  { "yii", "y_{i}" }, { "yjj", "y_{j}" }, { "mcal", [[\mathcal{$0}$1]] }, { "mbb", [[\mathbb{$0}$1]] },
  { "ell", [[\ell]] }, { "lll", [[\ell]] }, { "LL", [[\mathcal{L}]] }, { "HH", [[\mathcal{H}]] },
  { "CC", [[\mathbb{C}]] }, { "RR", [[\mathbb{R}]] }, { "ZZ", [[\mathbb{Z}]] }, { "NN", [[\mathbb{N}]] },
  { "II", [[\mathbb{1}]] }, { [[\mathbb{1}I]], [[\hat{\mathbb{1}}]] }, { "AA", [[\mathcal{A}]] },
  { "BB", [[\mathbf{B}]] }, { "EE", [[\mathbf{E}]] },
  -- Unit vectors
  { ":i", [[\mathbf{i}]] }, { ":j", [[\mathbf{j}]] }, { ":k", [[\mathbf{k}]] },
  { ":x", [[\hat{\mathbf{x}}]] }, { ":y", [[\hat{\mathbf{y}}]] }, { ":z", [[\hat{\mathbf{z}}]] },
  -- Derivatives
  { "pa2", [[\dfrac{ \partial^{2} ${0:y} }{ \partial ${1:x}^{2} } $2]] },
  { "pa3", [[\frac{ \partial^{3} ${0:y} }{ \partial ${1:x}^{3} } $2]] },
  { "pa([A-Za-z])([A-Za-z])2", "\\dfrac{ \\partial^{2} [[0]] }{ \\partial [[1]]^{2} } ", re = true },
  { "de([A-Za-z])([A-Za-z])2", "\\dfrac{ d^{2}[[0]] }{ d[[1]]^{2} } ", re = true },
  { "ddt", [[\frac{d}{dt} ]] },
  -- Integrals
  { "oinf", [[\int_{0}^{\infty} $0 \, d${1:x} $2]] },
  { "infi", [[\int_{-\infty}^{\infty} $0 \, d${1:x} $2]] },
  { "dint", [[\int_{${0:0}}^{${1:\infty}} $2 \, d${3:x} $4]] }, { "oint", [[\oint]] },
  { "iiint", [[\iiint]] }, { "iint", [[\iint]] }, { "int", [[\int $0 \, d${1:x} $2]] },
  -- Physics
  { "kbt", "k_{B}T" },
  -- Quantum mechanics
  { "hba", [[\hbar]] }, { "dag", [[^{\dagger}]] }, { "o+", [[\oplus ]] },
  { "bra", [[\bra{$0} $1]] }, { "ket", [[\ket{$0} $1]] },
  { "brk", [[\braket{ $0 | $1 } $2]] }, { [[\\bra\{([^|]+)\|]], "\\braket{ [[0]] | $0 ", re = true },
  { [[\\bra\{(.+)\}([^ ]+)\>]], "\\braket{ [[0]] | $0 ", re = true },
  { "outp", [[\ket{${0:\psi}} \bra{${0:\psi}} $1]] },
  -- Chemistry
  { "pu", [[\pu{ $0 }]] }, { "msun", [[M_{\odot}]] }, { "solm", [[M_{\odot}]] }, { "ce", [[\ce{ $0 }]] },
  { "iso", "{}^{${0:4}}_{${1:2}}${2:He}" }, { "hel4", "{}^{4}_{2}He " }, { "hel3", "{}^{3}_{2}He " },
  -- Environments
  { "pmat", "\\begin{pmatrix}\n$0\n\\end{pmatrix}" }, { "bmat", "\\begin{bmatrix}\n$0\n\\end{bmatrix}" },
  { "Bmat", "\\begin{Bmatrix}\n$0\n\\end{Bmatrix}" }, { "vmat", "\\begin{vmatrix}\n$0\n\\end{vmatrix}" },
  { "Vmat", "\\begin{Vmatrix}\n$0\n\\end{Vmatrix}" }, { "case", "\\begin{cases}\n$0\n\\end{cases}" },
  { "align", "\\begin{align}\n$0\n\\end{align}" }, { "array", "\\begin{array}\n$0\n\\end{array}" },
  { "matrix", "\\begin{matrix}\n$0\n\\end{matrix}" },
  { "matl", "\\begin{matrix*}[l]\n$0\n\\end{matrix*}" },
  { "matr", "\\begin{matrix*}[r]\n$0\n\\end{matrix*}" },
  -- Brackets
  { "avg", [[\langle $0 \rangle $1]] }, { "norm", [[\lvert $0 \rvert $1]], priority = 1 },
  { "mod", "|$0|$1" }, { "lr(", [[\left( $0 \right) $1]] }, { "lr|", [[\left| $0 \right| $1]] },
  { "lr{", [[\left\{ $0 \right\} $1]] }, { "lr[", [[\left[ $0 \right] $1]] },
  { "lra", [[\left< $0 \right> $1]] },
  -- Misc
  { "tayl", [[${0:f}(${1:x} + ${2:h}) = ${0:f}(${1:x}) + ${0:f}'(${1:x})${2:h} + ${0:f}''(${1:x}) \frac{${2:h}^{2}}{2!} + \dots$3]] },
  { "mbx", [[\mbox{$0}]] }, { "deg", [[^{\circ}]] },
  { [[([^ \t$]+) choose ([^ \t$]+)]], "{[[0]] \\choose [[1]]}", re = true },
  { "([A-Za-z])star", "[[0]]^{\\star}", re = true, priority = 1 },
  { "([A-Za-z0-9])bold", "\\textbf{[[0]]}", re = true },
}

-- Expanded with <Tab>
local tab = {
  { "te", [[\text{$0}]] },
  { [[(^|[^\\])pm]], "[[0]]\\pm", re = true }, { [[(^|[^\\])mp]], "[[0]]\\mp", re = true },
  { "par", [[\dfrac{ \partial ${0:y} }{ \partial ${1:x} } $2]] },
  { "pa([A-Za-z])([A-Za-z])", "\\dfrac{ \\partial [[0]] }{ \\partial [[1]] } ", re = true },
  { "pa([A-Za-z])([A-Za-z])([A-Za-z])", "\\dfrac{ \\partial^{2} [[0]] }{ \\partial [[1]] \\partial [[2]] } ", re = true },
  { "de([A-Za-z])([A-Za-z])", "\\dfrac{ d[[0]] }{ d[[1]] } ", re = true },
  { "gn", [[g=9.8 \dfrac{m}{s^2}]] }, { "gt", [[g=10 \dfrac{m}{s^2}]] },
  { "red", [[\textcolor{red}{$0}]] }, { "lred", [[\textcolor{violet}{$0}]] },
  { "blue", [[\textcolor{aqua}{$0}]] }, { "green", [[\textcolor{green}{$0}]] },
  { "lgreen", [[\textcolor{lightgreen}{$0}]] }, { "org", [[\textcolor{orange}{$0}]] },
  { "gold", [[\textcolor{gold}{$0}]] },
}


-- Outside math
local text = {
  { "mk", "$$0$$1", word = true },
  { "dm", "$$\n$0\n$$", word = true },
}

-- Visual mode: select, <Tab>, then one of these keys. $V is the selection.
local visual = {
  U = [[\underbrace{ $V }_{ $0 }]],
  O = [[\overbrace{ $V }^{ $0 }]],
  B = [[\underset{ $0 }{ $V }]],
  C = [[\cancel{ $V }]],
  K = [[\cancelto{ $0 }{ $V }]],
  S = [[\sqrt{ $V }]],
}

local fraction = [[\dfrac]]

-- Where is the cursor? ------------------------------------------------------------------------

-- Walk over a line from `state` ("text" or "block", i.e. inside $$...$$). Returns the state at its end,
-- and the byte where the math starts if the line ends inside math ("block" or "inline").
local function scan(line, state)
  local i, start = 1, state == "block" and 1 or nil
  while i <= #line do
    local c = line:sub(i, i)
    if c == "\\" then
      i = i + 1
    elseif state == "text" and c == "`" then
      local ticks = line:match("^`+", i)
      local _, stop = line:find(ticks, i + #ticks, true)
      i = stop or (i + #ticks - 1)
    elseif c == "$" then
      if line:sub(i, i + 1) == "$$" and state ~= "inline" then
        state = state == "block" and "text" or "block"
        i = i + 1
      elseif state ~= "block" then
        state = state == "inline" and "text" or "inline"
      end
      start = state ~= "text" and i + 1 or nil
    end
    i = i + 1
  end
  return state, start
end

-- Does a closing "$" follow in the rest of the line?
local function closes(rest)
  return (" " .. rest):find("[^\\]%$") ~= nil
end

-- Math at the cursor: { inline = bool, before = math text on this line before the cursor,
-- groups = names of the enclosing \name{...} or "^"/"_" groups }, or nil.
local function locate()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(0, 0, row, false)
  local line = lines[row]
  local state, fence, block_row = "text", nil, 1
  for n = 1, row - 1 do
    local l = lines[n]
    local f = state == "text" and (l:match("^%s*(```+)") or l:match("^%s*(~~~+)"))
    if fence then
      if f and f:sub(1, #fence) == fence then fence = nil end
    elseif f then
      fence = f
    elseif l:find("$$", 1, true) then
      state = scan(l, state)
      if state == "inline" then state = "text" end -- inline math doesn't span lines
      if state == "block" then block_row = n end
    end
  end
  if fence then return nil end

  local start
  state, start = scan(line:sub(1, col), state)
  -- `$|$`: the scan of "$" alone is an inline start; the closing one is what makes it math
  if state == "inline" and (not closes(line:sub(col + 1)) or line:find("^%s", start) and col >= start) then return nil end
  if state == "text" then return nil end

  -- enclosing groups, over the whole equation so far
  local before = line:sub(start, col)
  local from_block = state == "block" and start == 1 and block_row < row
  local all = from_block and table.concat(lines, "\n", block_row, row - 1) .. "\n" .. before or before
  if from_block then all = all:gsub("^.*%$%$", "") end
  local groups, i = {}, 1
  while i <= #all do
    local c = all:sub(i, i)
    if c == "\\" and all:find("^\\%A", i) then
      i = i + 1
    elseif c == "{" then
      local head = all:sub(1, i - 1)
      groups[#groups + 1] = head:match("\\(%a+)%*?$") or head:match("[%^_]$") or ""
    elseif c == "}" then
      groups[#groups] = nil
    end
    i = i + 1
  end
  return { inline = state == "inline", before = before, groups = groups }
end

local cache = {}
local function context()
  local key = table.concat({ vim.api.nvim_get_current_buf(), vim.b.changedtick, unpack(vim.api.nvim_win_get_cursor(0)) }, ":")
  if cache.key ~= key then cache = { key = key, value = locate() } end
  return cache.value
end

local function inside(m, names)
  for _, g in ipairs(m.groups) do
    if vim.tbl_contains(names, g) then return true end
  end
  return false
end

-- Math, but not the text part of it
local function in_math()
  local m = context()
  return m and not inside(m, { "text", "textrm", "mbox", "tag", "begin", "end" }) and m or nil
end

local function in_text()
  if context() then return false end
  for _, cap in ipairs(vim.treesitter.get_captures_at_cursor(0)) do
    if cap:find("^markup%.raw") then return false end -- code
  end
  return true
end

-- Building LuaSnip snippets -------------------------------------------------------------------

-- "\sqrt{ $0 }$1" -> LuaSnip nodes
local function nodes(replacement, selection)
  local ls = require("luasnip")
  local parts, pos, last = {}, 1, -1
  while pos <= #replacement do
    local rest = replacement:sub(pos)
    local s, index, default = rest:match("^(%$(%d))")
    if not s then s, index, default = rest:match("^(%${(%d):([^}]*)})") end
    local capture
    if not s then s, capture = rest:match("^(%[%[(%d)%]%])") end
    if not s and selection then s = rest:match("^%$V") end
    if index then
      parts[#parts + 1] = { index = tonumber(index), default = default }
      last = math.max(last, tonumber(index))
    elseif capture then
      parts[#parts + 1] = { capture = tonumber(capture) + 1 }
    elseif s then
      parts[#parts + 1] = { text = selection }
    else
      s = rest:match("^%$?[^%$%[]+") or rest:sub(1, 1)
      parts[#parts + 1] = { text = s }
    end
    pos = pos + #s
  end

  -- the last field ends the snippet; if it isn't at the very end, add one there so <Tab> gets out
  local final = parts[#parts]
  if last >= 0 and not (final.index == last and not final.default) then
    parts[#parts + 1] = { index = last + 1 }
    last = last + 1
  end

  local out, seen = {}, {}
  for k, p in ipairs(parts) do
    if p.index then
      local i = p.index == last and 0 or p.index + 1
      out[k] = seen[i] and require("luasnip.extras").rep(i) or ls.insert_node(i, p.default)
      seen[i] = true
    elseif p.capture then
      out[k] = ls.function_node(function(_, snip) return snip.captures[p.capture] or "" end)
    else
      local t = p.text
      -- latex-suite's removeSnippetWhitespace: no trailing space in inline math
      local at_end = k == #parts or (k == #parts - 1 and parts[#parts].index)
      if at_end and t:sub(-1) == " " then
        out[k] = ls.function_node(function()
          local m = context()
          return m and m.inline and (t:gsub("%s+$", "")) or t
        end)
      else
        out[k] = ls.text_node(vim.split(t, "\n"))
      end
    end
  end
  return out
end

-- A LuaSnip trigger matcher for our triggers, which also checks the context (cheap checks first)
local function matcher(def, allowed)
  local rx = def.re and [[\v\C%(]] .. def[1]:gsub("%${([%u_]+)}", vars) .. ")$" or nil
  return function()
    return function(line)
      local match, captures = nil, {}
      if rx then
        if not allowed() then return nil end
        local m = vim.fn.matchlist(line, rx)
        if #m == 0 or m[1] == "" then return nil end
        match, captures = m[1], vim.list_slice(m, 2)
      else
        if line:sub(-#def[1]) ~= def[1] then return nil end
        match = def[1]
        if not allowed() then return nil end
      end
      local prefix = line:sub(1, #line - #match)
      if def.word and prefix:find("[%w_\\]$") then return nil end
      -- inside a \macro being typed ("\sum", or the "eta" of "\beta"): leave it alone
      if match:find("^%a") and match:find("%a$") and prefix:find("\\%a*$") then return nil end
      return match, captures
    end
  end
end

-- `(a+b)/` -> \dfrac{a+b}{|}. Follows latex-suite: the numerator goes back to a space, + - = $ or an
-- open bracket; whole bracket groups are part of it.
local GREEK = vim.split(vars.GREEK, "|")
local function numerator(line)
  local m = line:sub(-1) == "/" and in_math()
  if not m or inside(m, { "^", "pu" }) then return nil end
  local s = line:sub(#line - #m.before + 1, -2)
  for _, g in ipairs(GREEK) do -- a space after a Greek letter belongs to it
    s = s:gsub("(\\" .. g .. ") ([^ ])", "%1#%2")
  end
  local open = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
  local i = #s
  while i >= 1 do
    local c = s:sub(i, i)
    if open[c] then
      local depth = 0
      local j = i
      while j >= 1 do
        local d = s:sub(j, j)
        if d == c then depth = depth + 1 elseif d == open[c] then depth = depth - 1 end
        if depth == 0 then break end
        j = j - 1
      end
      if j < 1 then return nil end
      i = j
    elseif (" $([{+-=\t"):find(c, 1, true) then
      break
    end
    i = i - 1
  end
  local num = line:sub(#line - #s + i, -2)
  if num == "" then return nil end
  local stripped = num
  if num:match("^%b()$") then stripped = num:sub(2, -2) end
  return num .. "/", { stripped }
end

-- Register everything for markdown
function M.setup()
  local ls = require("luasnip")
  local function build(list, allowed)
    local defs = vim.list_extend({}, list)
    local rank = {}
    for k, d in ipairs(defs) do
      rank[d] = { d.priority or 0, #(d[1]:gsub("%${([%u_]+)}", vars)), -k }
    end
    table.sort(defs, function(a, b)
      local x, y = rank[a], rank[b]
      for n = 1, 3 do
        if x[n] ~= y[n] then return x[n] > y[n] end
      end
      return false
    end)
    local out = {}
    for k, d in ipairs(defs) do
      out[k] = ls.snippet({
        trig = d[1], trigEngine = matcher(d, allowed), wordTrig = false, hidden = true, priority = 10000 - k,
      }, nodes(d[2]))
    end
    return out
  end
  local autos = build(auto, in_math)
  vim.list_extend(autos, build(text, in_text))
  autos[#autos + 1] = ls.snippet({
    trig = "/", trigEngine = function() return numerator end, wordTrig = false, hidden = true, priority = 1,
  }, nodes(fraction .. "{[[0]]}{$0}$1"))
  ls.add_snippets("markdown", autos, { type = "autosnippets", key = "latex_auto" })
  ls.add_snippets("markdown", build(tab, in_math), { key = "latex_tab" })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("latex_snippets", {}),
    pattern = "markdown",
    callback = function(args)
      vim.keymap.set("x", "<Tab>", M.wrap, { buffer = args.buf, desc = "Wrap math (U O B C K S)" })
    end,
  })
end

-- <Tab> / <S-Tab> for blink.cmp's keymap: true if it was ours. Fields win over the completion menu.
function M.tab(direction)
  if vim.bo.filetype ~= "markdown" or not package.loaded.luasnip then return false end
  local ls = require("luasnip")
  if direction == 1 and vim.api.nvim_get_mode().mode == "i" and ls.expandable() then
    vim.schedule(ls.expand)
  elseif ls.locally_jumpable(direction) then
    vim.schedule(function() ls.jump(direction) end)
  else
    return false
  end
  require("blink.cmp").hide()
  return true
end

-- Visual mode: ask for a key and wrap the selection
function M.wrap()
  local replacement = visual[vim.fn.getcharstr()]
  local a, b = vim.fn.getpos("v"), vim.fn.getpos(".")
  if not replacement or vim.fn.mode() ~= "v" or a[2] ~= b[2] then return end
  if a[3] > b[3] then a, b = b, a end
  local row, from = a[2] - 1, a[3] - 1
  local line = vim.api.nvim_get_current_line()
  local to = b[3] - 1 + #vim.fn.strcharpart(line:sub(b[3]), 0, 1)
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  vim.api.nvim_win_set_cursor(0, { row + 1, from })
  if not in_math() then return end
  vim.api.nvim_buf_set_text(0, row, from, row, to, { "" })
  local ls = require("luasnip")
  vim.cmd.startinsert()
  vim.schedule(function()
    ls.snip_expand(ls.snippet("", nodes(replacement, line:sub(from + 1, to))), { pos = { row, from } })
  end)
end

return M
