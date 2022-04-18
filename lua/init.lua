local Path = require("plenary.path")
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

M.setup = function()
  M.load()
end

M.save = function()
  Path:new(cache_config):write(vim.fn.json_encode(M.played), "w")
end

M.load = function()
  local ok, played = pcall(read_config, cache_config)
  if not ok then
    M.played = {}
  else
    -- TODO: do log debug (not sure how to trigger the debug func)
    -- print(vim.inspect(played))
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

M.stopping_soon = function()
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

-- functions that can be called by users

M.get_played = function(granularity, since_date)
  local total = 0
  local total_bydir = {}

  local pattern = "(%d+)/(%d+)/(%d+)"
  local day, month, year = since_date:match(pattern)
  local since = os.time({ year = year, month = month, day = day })

  for date, _ in pairs(M.played) do
    if granularity == "today" then
      if date ~= os.date("%x") then
        goto continue
      end
    elseif granularity == "since" then
      if date < since then
        goto continue
      end
    end
    for dir, pl in pairs(M.played[date]) do
      total = total + pl.elapsed_sec
      total_bydir[dir] = total_bydir[dir] + pl.elapsed_sec
    end
    ::continue::
  end
  print("Your total played time in neovim is " .. total .. " seconds.")
  print(vim.inspect(total_bydir))
end

-- Not sure if this is the correct place to put these AUTOCMDs
-- AUTOCMD
local group = vim.api.nvim_create_augroup("played", { clear = true })
-- When theres an input
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = group,
  callback = M.start_counting,
})
-- This is when AFK is detected
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = group,
  callback = M.stopping_soon,
})

return M
