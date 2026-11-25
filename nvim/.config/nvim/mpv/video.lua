-- Runs inside mpv (started by lua/video.lua), so it works with no nvim open: remembers the position
-- in each YouTube video, and gets a new stream when YouTube's expires.
local utils = require("mp.utils")

local state_file = mp.get_opt("video-state") -- { last = id, width = percent, positions = { [id] = seconds } }
local lifetime = tonumber(mp.get_opt("video-lifetime")) or 5 * 3600 -- streams expire after about 6 hours
local loaded -- when the stream was fetched

local function current()
  local path = mp.get_property("path")
  return path and path:match("^https://youtu%.be/([%w_-]+)$")
end

local function read()
  local file = io.open(state_file)
  local state = file and utils.parse_json(file:read("*a")) or {}
  if file then file:close() end
  state.positions = state.positions or {}
  return state
end

local function save()
  local id, pos = current(), mp.get_property_number("time-pos")
  if not id or not pos or not loaded then return end
  local state = read()
  state.last = id
  -- a video watched to its end starts over
  state.positions[id] = not mp.get_property_bool("eof-reached") and math.floor(pos) or nil
  local window, display = mp.get_property_number("osd-width"), mp.get_property_number("display-width")
  if window and window > 0 and display and display > 0 and not mp.get_property_bool("fullscreen") then
    state.width = math.floor(window / display * 100 + 0.5)
  end
  local file = io.open(state_file .. ".mpv", "w")
  if not file then return end
  file:write(utils.format_json(state))
  file:close()
  os.rename(state_file .. ".mpv", state_file)
end

local function expired() return loaded and os.time() - loaded >= lifetime end

local function reload(pos)
  loaded = nil -- don't save a position from the expired stream
  mp.commandv("loadfile", mp.get_property("path"), "replace", "-1", "start=" .. pos)
end

-- Start where it was left, unless a time was asked for
mp.add_hook("on_load", 5, function()
  local id = current()
  local pos = id and mp.get_property("start") == "none" and read().positions[id]
  if pos then mp.set_property("file-local-options/start", pos) end
end)
mp.register_event("file-loaded", function()
  loaded = os.time()
  save()
end)
mp.add_hook("on_unload", 50, function()
  save()
  loaded = nil
end)

mp.observe_property("pause", "bool", function(_, paused)
  if not paused and expired() then reload(mp.get_property_number("time-pos", 0)) end
end)
mp.add_periodic_timer(5, function()
  if not expired() then
    save()
  elseif not mp.get_property_bool("pause") then
    save()
    reload(mp.get_property_number("time-pos", 0))
  end
end)

-- "script-message video-seek SECONDS relative|absolute"
mp.register_script_message("video-seek", function(seconds, mode)
  seconds = tonumber(seconds)
  if expired() then
    if mode == "relative" then seconds = mp.get_property_number("time-pos", 0) + seconds end
    reload(math.max(0, seconds))
  else
    mp.commandv("seek", seconds, mode, "exact")
  end
end)
