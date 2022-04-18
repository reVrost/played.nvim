local M = {}

-- AFK time has to be > update interval
local afk_time_seconds = 10 + 1
local update_interval_seconds = 5

M.played = {}
M.played_timer = vim.loop.new_timer()
M.afk_timer = vim.loop.new_timer()
M.is_counting = false

M.startLog = function()
  M.afk_timer:stop()

  local currentDate = os.date("%x")

  if not M.is_counting then
    M.played_timer:start(
      100,
      update_interval_seconds * 1000,
      vim.schedule_wrap(function()
        M.is_counting = true
        local elapsed = 0
        local directory = vim.fn.getcwd()
        if M.played[currentDate] == nil then
          M.played[currentDate] = {}
        end
        if M.played[currentDate][directory] ~= nil then
          elapsed = M.played[currentDate][directory].elapsed_sec
        end
        M.played[currentDate][directory] = { elapsed_sec = elapsed + update_interval_seconds }
        print(string.format("[%s][%s] = %d", currentDate, directory, elapsed + update_interval_seconds))
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
      print("tick" .. M.reserve)
      M.reserve = M.reserve - 1
      if M.reserve <= 0 then
        M.played_timer:stop()
        M.afk_timer:stop()
        M.is_counting = false

        print("Done. elapsed:")
        print(vim.inspect(M.played))
      end
    end)
  )
end

-- AUTOCMD

local group = vim.api.nvim_create_augroup("played", { clear = true })
-- When theres an input
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = group,
  callback = M.startLog,
})
-- This is when AFK is detected
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = group,
  callback = M.stopping_soon,
})

return M
