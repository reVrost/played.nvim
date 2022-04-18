local Path = require("plenary.path")
local popup = require("plenary.popup")
local M = {}

-- AFK time has to be > update interval
local afk_time_seconds = 15 + 1
local update_interval_seconds = 5
local data_path = vim.fn.stdpath("data")
local cache_config = string.format("%s/played.json", data_path)

local read_config = function(local_config)
  return vim.fn.json_decode(Path:new(local_config):read())
end

M.played_timer = vim.loop.new_timer()
M.afk_timer = vim.loop.new_timer()
M.is_counting = false

M.save = function()
  Path:new(cache_config):write(vim.fn.json_encode(M.played), "w")
end

M.load = function()
  local ok, played = pcall(read_config, cache_config)
  if not ok then
    M.played = {}
  else
    -- TODO: do log debug (not sure how to trigger the debug func)
    print(vim.inspect(played))
    M.played = played
  end
end

M.add_played = function()
  local elapsed = 0
  local currentDate = os.date("%x")
  local directory = vim.fn.getcwd()

  if M.played[currentDate] == nil then
    M.played[currentDate] = {}
  end

  if M.played[currentDate][directory] ~= nil then
    elapsed = M.played[currentDate][directory].elapsed_sec
  end

  M.played[currentDate][directory] = { elapsed_sec = elapsed + update_interval_seconds }
  -- print(string.format("[%s][%s] = %d", currentDate, directory, elapsed + update_interval_seconds))

  -- Then save
  M.save()
end

M.start_counting = function()
  if M.played == nil then
    M.load()
  end
  M.afk_timer:stop()

  if not M.is_counting then
    M.played_timer:start(
      100,
      update_interval_seconds * 1000,
      vim.schedule_wrap(function()
        -- Dont count the first run
        if M.is_counting then
          M.add_played()
        end
        M.is_counting = true
      end)
    )
  end

  -- Stop unplayed timer
end

-- Stopping logic
M.stop_counting = function()
  if M.played == nil then
    M.load()
  end

  M.reserve = afk_time_seconds
  M.afk_timer:start(
    100,
    1 * 1000,
    vim.schedule_wrap(function()
      -- print("tick" .. M.reserve)
      M.reserve = M.reserve - 1
      if M.reserve <= 0 then
        M.played_timer:stop()
        M.afk_timer:stop()
        M.is_counting = false

        -- print("Done. elapsed:")
        -- print(vim.inspect(M.played))
      end
    end)
  )
end

M.get_date = function(date)
  local pattern = "(%d+)/(%d+)/(%d+)"
  local day, month, year = date:match(pattern)
  local converted = os.time({ year = year, month = month, day = day })
  return converted
end

M.get_readable_time = function(seconds)
  -- local day = seconds / (24*3600)
  -- seconds = seconds % (24 * 3600)

  local hours = seconds / 3600
  seconds = seconds % 3600

  local minutes = seconds / 60
  seconds = seconds % 60

  local round = function(bla)
    return math.floor(bla + 0.55)
  end

  return string.format("%sh %sm %ss", round(hours), round(minutes), seconds)
end

M.show_popup = function(granularity, total, total_bydir, since_date)
  local width = 60
  local height = 10
  local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  local bufnr = vim.api.nvim_create_buf(false, false)

  local _, win = popup.create(bufnr, {
    title = "Time log",
    line = math.floor(((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    minwidth = width,
    minheight = height,
    borderchars = borderchars,
  })
  local contents = {}
  contents[1] = ""
  if granularity == "since" then
    contents[2] = "  Your total time since" .. since_date .. " is " .. M.get_readable_time(total) .. "."
  else
    contents[2] = "  Your total time is " .. M.get_readable_time(total) .. "."
  end
  contents[3] = ""
  local id = 4
  for k, v in pairs(total_bydir) do
    contents[id] = string.format("  [%s]: %s", k, M.get_readable_time(v))
    id = id + 1
  end
  vim.api.nvim_win_set_option(win.border.win_id, "winhl", "Normal:PlayedBorder")
  vim.api.nvim_buf_set_lines(bufnr, 0, #contents, false, contents)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "delete")
end

-- functions that can be called by users
M.get_played = function(granularity, since_date)
  local total = 0
  local total_bydir = {}

  local since = nil
  if since_date ~= nil then
    since = M.get_date(since_date)
  end

  for date, _ in pairs(M.played) do
    if granularity == "today" then
      if date ~= os.date("%x") then
        goto continue
      end
    elseif granularity == "since" then
      -- time since date
      if os.difftime(M.get_date(date), since) < 0 then
        goto continue
      end
    end
    for dir, pl in pairs(M.played[date]) do
      total = total + pl.elapsed_sec
      total_bydir[dir] = (total_bydir[dir] ~= nil and total_bydir[dir] or 0) + pl.elapsed_sec
    end
    ::continue::
  end
  M.show_popup(granularity, total, total_bydir, since_date)
end

return M
