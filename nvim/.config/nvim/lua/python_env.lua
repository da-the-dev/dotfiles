-- Python interpreter selection, VSCode-style:
--   * per project: a saved choice wins, otherwise <root>/.venv (or venv) is used automatically
--   * the choice is remembered across restarts
--   * the chosen venv is "activated" inside nvim (VIRTUAL_ENV + PATH), so :terminal, :! and
--     anything nvim spawns (e.g. a debugger later) use the same interpreter
local M = {}

local store = vim.fn.stdpath("data") .. "/python-interpreters.json"
local base_path = vim.env.PATH
local root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", ".git" }

local cache -- saved choices, read from disk once

local function load()
  if not cache then
    local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(store), "\n")) end)
    cache = ok and type(data) == "table" and data or {}
  end
  return cache
end

local function save(data)
  cache = data
  vim.fn.writefile({ vim.json.encode(data) }, store)
end

-- venv directory that contains this python, if any
local function venv_of(python)
  local dir = vim.fs.dirname(vim.fs.dirname(python))
  if vim.uv.fs_stat(dir .. "/pyvenv.cfg") then
    return dir
  end
end

local function project_venvs(root)
  local found = {}
  for _, name in ipairs({ ".venv", "venv" }) do
    local p = root .. "/" .. name .. "/bin/python"
    if vim.fn.executable(p) == 1 then
      table.insert(found, p)
    end
  end
  return found
end

local function pyright_client(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr or 0, name = "basedpyright" })[1]
end

local function current_root()
  local client = pyright_client()
  return client and client.root_dir or vim.fs.root(0, root_markers) or vim.uv.cwd()
end

--- Interpreter for a project root: saved choice > project .venv > nil (python on PATH)
function M.resolve(root)
  local saved = load()[root]
  if saved and vim.fn.executable(saved) == 1 then
    return saved
  end
  return project_venvs(root)[1]
end

--- Interpreter for the current buffer's project (falls back to python3 on PATH)
function M.current()
  return M.resolve(current_root()) or vim.fn.exepath("python3")
end

--- Make nvim's environment match the interpreter (like VSCode activating it in terminals)
function M.activate(python)
  local venv = python and venv_of(python)
  vim.env.VIRTUAL_ENV = venv
  vim.env.PATH = venv and (venv .. "/bin:" .. base_path) or base_path
end

local versions = {} -- python path -> "3.12.4"

--- Statusline text for Python buffers, e.g. " 3.12.4 (.venv)"; cached per buffer
function M.status()
  if vim.bo.filetype ~= "python" then
    return ""
  end
  if vim.b.python_status then
    return vim.b.python_status
  end
  local python = M.current()
  if python == "" then
    return ""
  end
  if not versions[python] then
    local out = vim.system({ python, "--version" }, { text = true }):wait(2000)
    versions[python] = ((out.stdout or "") .. (out.stderr or "")):match("%d+%.%d+%.?%d*") or "?"
  end
  local venv = venv_of(python)
  local text = " " .. versions[python] .. (venv and (" (" .. vim.fn.fnamemodify(venv, ":t") .. ")") or "") .. "  "
  vim.b.python_status = text
  return text
end

local function apply(root, python)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    vim.b[b].python_status = nil
  end
  M.activate(python)
  for _, client in ipairs(vim.lsp.get_clients({ name = "basedpyright" })) do
    if client.root_dir == root then
      client.settings.python = vim.tbl_extend("force", client.settings.python or {}, { pythonPath = python })
      client:notify("workspace/didChangeConfiguration", { settings = client.settings })
    end
  end
  vim.cmd.redrawstatus({ bang = true })
  vim.notify("Python interpreter: " .. python)
end

--- Pick an interpreter for the current project
function M.pick()
  local root = current_root()
  local items, seen = {}, {}
  local function add(path, label)
    if path and not seen[path] and vim.fn.executable(path) == 1 then
      seen[path] = true
      table.insert(items, { path = path, label = label })
    end
  end

  for _, p in ipairs(project_venvs(root)) do
    add(p, "venv  " .. vim.fn.fnamemodify(venv_of(p), ":t"))
  end
  local uv = vim.system({ "uv", "python", "list", "--only-installed", "--output-format", "json" }, { text = true }):wait(3000)
  local ok, pythons = pcall(vim.json.decode, uv.stdout or "")
  if ok and type(pythons) == "table" then
    for _, py in ipairs(pythons) do
      add(py.path, "uv    " .. py.version)
    end
  end
  for dir in base_path:gmatch("[^:]+") do
    add(dir .. "/python3", "PATH  python3")
  end

  local current = M.current()
  vim.ui.select(items, {
    prompt = "Python interpreter for " .. vim.fn.fnamemodify(root, ":~"),
    format_item = function(item)
      return (item.path == current and "● " or "  ") .. item.label .. "  " .. vim.fn.fnamemodify(item.path, ":~")
    end,
  }, function(choice)
    if not choice then
      return
    end
    local data = load()
    data[root] = choice.path
    save(data)
    apply(root, choice.path)
  end)
end

return M
