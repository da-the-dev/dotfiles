-- YouTube in IINA's picture-in-picture window, controlled from nvim (<leader>v...).
-- yt-dlp finds the stream, IINA (built on mpv) plays it and takes commands over a socket. The
-- player outlives nvim: any nvim can control it, and the position in each video is remembered.
local M = {}

local socket = vim.uv.os_tmpdir() .. "/nvim-video.sock" -- $TMPDIR is private to the user
local state_file = vim.fn.stdpath("state") .. "/video.json" -- { last = id, positions = { [id] = seconds } }

-- YouTube refuses yt-dlp's usual streams (403), but not its HLS ones: one file with picture and
-- sound if there is one, else two. H.264, as IINA doesn't start YouTube's VP9 HLS streams.
local attempts = {
  { "--extractor-args", "youtube:player_client=web_embedded", "-f", "b[protocol^=m3u8][vcodec^=avc][height<=1080]" },
  { "-f", "bv*[protocol^=m3u8][vcodec^=avc][height<=1080]+ba[protocol^=m3u8]/b[protocol^=m3u8][vcodec^=avc]" },
}

local function iina()
  for _, cmd in ipairs({ "iina", "/Applications/IINA.app/Contents/MacOS/iina-cli" }) do
    if vim.fn.executable(cmd) == 1 then return cmd end
  end
end

local function warn(msg) vim.notify(msg, vim.log.levels.WARN, { title = "Video" }) end

-- Saved positions --------------------------------------------------------------------------------

local function read_state()
  local ok, state = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(state_file), "\n")) end)
  state = ok and type(state) == "table" and state or {}
  state.positions = state.positions or {}
  return state
end

local function write_state(change)
  local state = read_state() -- other nvims write it too
  change(state)
  local tmp = state_file .. "." .. vim.uv.os_getpid()
  vim.fn.writefile({ vim.json.encode(state) }, tmp)
  vim.uv.fs_rename(tmp, state_file)
end

-- The player: mpv's JSON protocol ----------------------------------------------------------------

local pipe, requests, next_id = nil, {}, 0

local function disconnect()
  if pipe and not pipe:is_closing() then pipe:close() end
  pipe = nil
  local pending = requests
  requests = {}
  for _, callback in pairs(pending) do callback(nil) end
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
        local done = ok and msg.request_id and requests[msg.request_id]
        if done then
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

-- What's playing: { id, expire } (set by `mark`) and the position, or nil. Stored in the player,
-- so every nvim sees the same.
local function current(callback)
  get("user-data/nvim_video", function(video)
    if type(video) ~= "table" or not video.id then return callback(nil) end
    get("time-pos", function(pos)
      if pos then callback(video, pos) else callback(nil) end
    end)
  end)
end

local function save_position(callback)
  current(function(video, pos)
    -- an expired stream can jump anywhere
    if video and os.time() < video.expire then
      write_state(function(state)
        state.last = video.id
        state.positions[video.id] = math.floor(pos)
      end)
    end
    if callback then callback() end
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

-- callback({ title, urls })
local function resolve(id, callback, attempt)
  attempt = attempt or 1
  local cmd = { "yt-dlp", "--ignore-config", "--no-warnings", "--no-playlist" }
  vim.list_extend(cmd, attempts[attempt])
  vim.list_extend(cmd, { "--print", "%(title)s", "--print", "urls", "--", "https://youtu.be/" .. id })
  vim.system(cmd, { text = true, timeout = 60000 }, vim.schedule_wrap(function(res)
    local lines = vim.split(vim.trim(res.stdout or ""), "\n")
    if res.code == 0 and #lines >= 2 then
      callback({ title = lines[1], urls = vim.list_slice(lines, 2) })
    elseif attempts[attempt + 1] then
      resolve(id, callback, attempt + 1)
    else
      local errors = vim.split(vim.trim(res.stderr or ""), "\n")
      local last = errors[#errors]
      callback(nil, last ~= "" and last or "yt-dlp gave no stream")
    end
  end))
end

local opening = false

-- Hide IINA's main window, leaving picture-in-picture. IINA's own setting for that has no effect
-- with --pip: it hides the window at launch, and shows it again when the video is ready.
local function hide_window()
  get("pid", function(pid)
    if not pid then return end
    local app = "$.NSRunningApplication.runningApplicationWithProcessIdentifier(" .. pid .. ")"
    vim.system({ "osascript", "-l", "JavaScript", "-e", "ObjC.import('AppKit'); " .. app .. ".hide" })
  end)
end

-- Once the stream plays: name it, and note in the player what it is
local function mark(id, stream, launched, tries)
  get("path", function(path)
    get("time-pos", function(pos)
      if path == stream.urls[1] and pos then
        opening = false
        if vim.fn.mode() ~= "c" then vim.api.nvim_echo({ { "" } }, false, {}) end -- clear "Opening video…"
        local expire = tonumber(stream.urls[1]:match("[/&?]expire[/=](%d+)")) or os.time() + 5 * 3600
        send({ "set_property", "user-data/nvim_video", { id = id, expire = expire } })
        send({ "set_property", "force-media-title", stream.title })
        if stream.urls[2] then send({ "audio-add", stream.urls[2], "select" }) end
        write_state(function(state) state.last = id end)
        if launched then hide_window() end
      elseif tries > 0 then
        vim.defer_fn(function() mark(id, stream, launched, tries - 1) end, 250)
      else
        opening = false
        warn("IINA didn't start playing " .. stream.title)
      end
    end)
  end)
end

-- Play a video, from `seconds` or where it was left
local function open(id, seconds)
  if opening then return warn("Already opening a video") end
  opening = true
  vim.notify("Opening video…")
  save_position(function()
    seconds = seconds or read_state().positions[id] or 0
    resolve(id, function(stream, err)
      if not stream then
        opening = false
        return warn(err)
      end
      get("idle-active", function(idle)
        if idle == false then -- a video is open: replace it
          send({ "set_property", "user-data/nvim_video", {} }) -- not to be saved as the old video
          send({ "loadfile", stream.urls[1], "replace", -1, { start = tostring(seconds) } })
          send({ "set_property", "pause", false })
        else
          if idle then send({ "quit" }) end -- IINA without a video: start over
          disconnect()
          os.remove(socket)
          vim.system({
            iina(), "--no-stdin", "--pip", "--mpv-start=" .. seconds, "--mpv-input-ipc-server=" .. socket, stream.urls[1],
          }, { detach = true, stdout = false, stderr = false })
        end
        mark(id, stream, idle ~= false, 120)
      end)
    end)
  end)
end

-- Keys -------------------------------------------------------------------------------------------

-- Run f(video, pos) if a video is open
local function with_video(f)
  current(function(video, pos)
    if video then f(video, pos) else warn("No video is open (<leader>vv reopens the last one)") end
  end)
end

-- Play / pause; reopens the last video if it's closed or its stream has expired
function M.toggle()
  current(function(video)
    if not video or os.time() >= video.expire then
      local last = video and video.id or read_state().last
      if last then open(last) else warn("No video yet: <leader>vo on a YouTube link") end
      return
    end
    send({ "cycle", "pause" })
    save_position()
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
  current(function(video)
    if video and video.id == link.id and os.time() < video.expire then
      send({ "seek", link.seconds, "absolute" })
    else
      open(link.id, link.seconds)
    end
  end)
end

function M.seek(seconds)
  with_video(function() send({ "seek", seconds, "relative+exact" }) end)
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
  with_video(function(video, pos)
    if vim.api.nvim_get_current_buf() ~= buf or vim.api.nvim_get_current_win() ~= win then return end
    if not vim.bo[buf].modifiable then return warn("Can't write in this buffer") end
    pos = math.floor(pos)
    local text = ("https://youtu.be/%s?t=%d"):format(video.id, pos)
    if vim.bo[buf].filetype == "markdown" then text = ("[%s](%s)"):format(clock(pos), text) end
    local col = vim.api.nvim_win_get_cursor(win)[2] + 1
    if vim.api.nvim_get_current_line():sub(col, col):match("%S") then text = " " .. text end
    vim.api.nvim_put({ text }, "c", true, true)
  end)
end

function M.close()
  save_position(function()
    send({ "quit" }, function(ok)
      if ok == nil then warn("No video is open") end
    end)
  end)
end

function M.setup()
  if not iina() or vim.fn.executable("yt-dlp") == 0 then return end
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
  vim.uv.new_timer():start(5000, 5000, vim.schedule_wrap(function() save_position() end))
end

return M
