-- YouTube in a small mpv window on top of everything, controlled from nvim (<leader>v...). mpv takes
-- commands over a socket and outlives nvim, so any nvim can control it. Positions are saved by a
-- script inside mpv: ../mpv/video.lua.
local M = {}

local socket = vim.uv.os_tmpdir() .. "/nvim-video-mpv.sock" -- $TMPDIR is private to the user on macOS
if vim.env.XDG_RUNTIME_DIR then socket = vim.env.XDG_RUNTIME_DIR .. "/nvim-video-mpv.sock" end -- Linux
local state_file = vim.fn.stdpath("state") .. "/video.json"

local function warn(msg) vim.notify(msg, vim.log.levels.WARN, { title = "Video" }) end

local function read_state()
  local ok, state = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(state_file), "\n")) end)
  return ok and type(state) == "table" and state or {}
end

local function mpv_command()
  local cmd = {
    "mpv", "--no-terminal", "--input-ipc-server=" .. socket,
    "--idle=once", "--keep-open=yes", -- wait for a video; stay open at its end
    "--script=" .. vim.fn.stdpath("config") .. "/mpv/video.lua", "--script-opts-append=video-state=" .. state_file,
    -- YouTube refuses yt-dlp's usual streams (403), but not its HLS ones
    "--ytdl-format=bv*[protocol^=m3u8][vcodec^=avc][height<=1080]+ba[protocol^=m3u8]/b[protocol^=m3u8]",
    "--script-opts-append=ytdl_hook-all_formats=no",
    "--ytdl-raw-options-append=ignore-config=", "--ytdl-raw-options-append=no-playlist=",
    "--ytdl-raw-options-append=extractor-args=youtube:player_client=default,web_embedded",
    -- a window on top, on every Space (also over a full-screen terminal), that doesn't take the focus
    "--ontop", "--on-all-workspaces", "--no-border", "--focus-on=never", "--auto-window-resize=no",
    ("--geometry=%d%%-20+40"):format(math.max(10, math.min(100, read_state().width or 36))),
  }
  if vim.fn.has("mac") == 1 then cmd[#cmd + 1] = "--macos-app-activation-policy=accessory" end
  return cmd
end

-- The player: mpv's JSON protocol ----------------------------------------------------------------

local pipe, requests, next_id = nil, {}, 0
local opening = nil -- { error = last error message } while a video is being opened

local function opened(err)
  if not opening then return end
  opening = nil
  if err then
    warn(err)
  elseif vim.fn.mode() ~= "c" then
    vim.api.nvim_echo({ { "" } }, false, {}) -- clear "Opening video…"
  end
end

local function on_event(msg)
  if not opening then return end
  if msg.event == "log-message" then
    -- yt-dlp's own message ("ERROR: ...") says most
    if not opening.error or msg.text:match("^ERROR") then opening.error = vim.trim(msg.text) end
  elseif msg.event == "file-loaded" then
    opened()
  elseif msg.event == "end-file" and msg.reason == "error" then
    opened(opening.error or "mpv couldn't open the video")
  end
end

local function disconnect()
  if pipe and not pipe:is_closing() then pipe:close() end
  pipe = nil
  local pending = requests
  requests = {}
  for _, callback in pairs(pending) do callback(nil) end
  opened(opening and opening.error or "mpv quit")
end

local function connect(callback)
  if pipe then return callback(true) end
  if not vim.uv.fs_stat(socket) then return callback(false) end
  local new, buffer = assert(vim.uv.new_pipe()), ""
  new:connect(socket, vim.schedule_wrap(function(err)
    if err or pipe then -- nobody listens (a leftover file), or connected meanwhile
      new:close()
      return callback(pipe ~= nil)
    end
    pipe = new
    new:read_start(vim.schedule_wrap(function(read_err, data)
      if new ~= pipe then return end
      if read_err or not data then return disconnect() end
      buffer = buffer .. data
      while true do
        local line, rest = buffer:match("^(.-)\n(.*)$")
        if not line then break end
        buffer = rest
        local ok, msg = pcall(vim.json.decode, line, { luanil = { object = true } })
        if ok and msg.event then
          on_event(msg)
        elseif ok and requests[msg.request_id] then
          local done = requests[msg.request_id]
          requests[msg.request_id] = nil
          done(msg.error == "success", msg.data)
        end
      end
    end))
    callback(true)
  end))
end

-- Send a command; callback(ok, data), with ok = nil if there's no player
local function send(command, callback)
  callback = callback or function() end
  connect(function(connected)
    if not connected then return callback(nil) end
    next_id = next_id + 1
    requests[next_id] = callback
    pipe:write(vim.json.encode({ command = command, request_id = next_id }) .. "\n")
  end)
end

local function get(property, callback)
  send({ "get_property", property }, function(ok, data)
    if not ok then data = nil end -- (not `ok and data or nil`: data can be false)
    callback(data)
  end)
end

-- callback(id, position) of the open video, or nothing
local function current(callback)
  get("path", function(path)
    local id = path and path:match("^https://youtu%.be/([%w_-]+)$")
    if not id then return callback() end
    get("time-pos", function(pos)
      if pos then callback(id, pos) else callback() end
    end)
  end)
end

-- Connect to mpv, starting it if needed; callback(connected)
local function ensure_player(callback)
  connect(function(connected)
    if connected then return callback(true) end
    os.remove(socket)
    vim.system(mpv_command(), { detach = true, stdin = false, stdout = false, stderr = false })
    local function try(left)
      connect(function(ok)
        if ok or left == 0 then return callback(ok) end
        vim.defer_fn(function() try(left - 1) end, 100)
      end)
    end
    try(50)
  end)
end

-- Links ------------------------------------------------------------------------------------------

-- video id and start time in seconds (or nil) of a YouTube link
local function parse(url)
  local id = url:match("youtu%.be/([%w_-]+)")
  if not id and url:match("youtube%.com/") then
    id = url:match("[?&]v=([%w_-]+)") or url:match("/live/([%w_-]+)") or url:match("/shorts/([%w_-]+)")
      or url:match("/embed/([%w_-]+)")
  end
  if not id or #id ~= 11 then return nil end
  local t = url:match("[?&#]t=(%w+)") or url:match("[?&]start=(%d+)")
  local seconds
  if t and t:match("^%d+s?$") then
    seconds = tonumber(t:match("%d+"))
  elseif t then
    local function unit(u) return tonumber(t:match("(%d+)" .. u)) or 0 end
    seconds = unit("h") * 3600 + unit("m") * 60 + unit("s")
  end
  return id, seconds
end

-- The link under the cursor (anywhere on a Markdown [text](link)), or the only one on the line
local function link_at_cursor()
  local line, col = vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1
  local found = {}
  local from = 1
  while true do
    local s, e = line:find("https?://[%w%-%._~:/%?#@!%$&%*%+,;=%%]+", from)
    if not s then break end
    from = e + 1
    local id, seconds = parse(line:sub(s, e))
    if id then
      local text = line:sub(1, s - 1):match("()%[[^%[%]]*%]%($") -- start of the Markdown link
      local link = { id = id, seconds = seconds }
      if col >= (text or s) and col <= e + (text and 1 or 0) then return link end
      found[#found + 1] = link
    end
  end
  return #found == 1 and found[1] or nil
end

local function clock(seconds)
  local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
  return h > 0 and ("%d:%02d:%02d"):format(h, m, s) or ("%d:%02d"):format(m, s)
end

-- Opening ----------------------------------------------------------------------------------------

-- Play a video, from `seconds` or where it was left
local function open(id, seconds)
  vim.notify("Opening video…")
  ensure_player(function(connected)
    if not connected then return warn("mpv didn't start") end
    opening = {}
    send({ "request_log_messages", "error" })
    send({ "set_property", "pause", false })
    send({ "loadfile", "https://youtu.be/" .. id, "replace", -1, seconds and { start = tostring(seconds) } or vim.empty_dict() })
  end)
end

-- Keys -------------------------------------------------------------------------------------------

-- Run f(id, pos) if a video is open
local function with_video(f)
  current(function(id, pos)
    if id then f(id, pos) else warn("No video is open (<leader>vv reopens the last one)") end
  end)
end

-- Play / pause; reopens the last video if it's closed
function M.toggle()
  get("path", function(path) -- (also while it's still loading)
    if path then return send({ "cycle", "pause" }) end
    local last = read_state().last
    if last then open(last) else warn("No video yet: <leader>vo on a YouTube link") end
  end)
end

function M.open()
  local link = link_at_cursor()
  if not link then
    local id, seconds = parse(vim.trim(vim.fn.getreg("+")))
    if not id then return warn("No YouTube link under the cursor or in the clipboard") end
    link = { id = id, seconds = seconds }
  end
  open(link.id, link.seconds)
end

function M.go()
  local link = link_at_cursor()
  if not link or not link.seconds then return warn("No YouTube timestamp under the cursor") end
  current(function(id)
    if id == link.id then
      send({ "script-message", "video-seek", tostring(link.seconds), "absolute" })
    else
      open(link.id, link.seconds)
    end
  end)
end

function M.seek(seconds)
  with_video(function() send({ "script-message", "video-seek", tostring(seconds), "relative" }) end)
end

function M.speed(change)
  with_video(function()
    get("speed", function(speed)
      if not speed then return end
      speed = math.max(0.25, math.min(4, speed + change))
      send({ "set_property", "speed", speed })
      vim.notify(("Speed %.2f"):format(speed))
    end)
  end)
end

function M.insert_timestamp()
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  with_video(function(id, pos)
    if vim.api.nvim_get_current_buf() ~= buf or vim.api.nvim_get_current_win() ~= win then return end
    if not vim.bo[buf].modifiable then return warn("Can't write in this buffer") end
    pos = math.floor(pos)
    local text = ("https://youtu.be/%s?t=%d"):format(id, pos)
    if vim.bo[buf].filetype == "markdown" then text = ("[%s](%s)"):format(clock(pos), text) end
    local col = vim.api.nvim_win_get_cursor(win)[2] + 1
    if vim.api.nvim_get_current_line():sub(col, col):match("%S") then text = " " .. text end
    vim.api.nvim_put({ text }, "c", true, true)
  end)
end

function M.close()
  send({ "quit" }, function(ok)
    if ok == nil then warn("No video is open") end
  end)
end

function M.setup()
  if vim.fn.executable("mpv") == 0 or vim.fn.executable("yt-dlp") == 0 then return end
  local function map(key, f, desc) vim.keymap.set("n", "<leader>v" .. key, f, { desc = desc }) end
  map("v", M.toggle, "Play / pause, reopen the last video")
  map("o", M.open, "Open link (cursor or clipboard)")
  map("g", M.go, "Go to timestamp under cursor")
  map("t", M.insert_timestamp, "Insert timestamp")
  map("h", function() M.seek(-10 * vim.v.count1) end, "Back 10s")
  map("l", function() M.seek(10 * vim.v.count1) end, "Forward 10s")
  map("-", function() M.speed(-0.25) end, "Slower")
  map("=", function() M.speed(0.25) end, "Faster")
  map("q", M.close, "Close video")
end

return M
