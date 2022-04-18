local played = require("played")
local popup = require("plenary.popup")

local get_date = function(date)
  local pattern = "(%d+)/(%d+)/(%d+)"
  local day, month, year = date:match(pattern)
  local converted = os.time({ year = year, month = month, day = day })
  return converted
end

local get_readable_time = function(seconds)
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

function Get_Played(granularity, since_date)
  local total = 0
  local total_bydir = {}

  local since = nil
  if since_date ~= nil then
    since = get_date(since_date)
  end

  for date, _ in pairs(played.played) do
    if granularity == "today" then
      if date ~= os.date("%x") then
        goto continue
      end
    elseif granularity == "since" then
      -- time since date
      if os.difftime(get_date(date), since) < 0 then
        goto continue
      end
    end
    for dir, pl in pairs(played.played[date]) do
      total = total + pl.elapsed_sec
      total_bydir[dir] = (total_bydir[dir] ~= nil and total_bydir[dir] or 0) + pl.elapsed_sec
    end
    ::continue::
  end

  -- popup
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
    contents[2] = "  Your total time since" .. since_date .. " is " .. get_readable_time(total) .. "."
  else
    contents[2] = "  Your total time is " .. get_readable_time(total) .. "."
  end
  contents[3] = ""
  local id = 4
  for k, v in pairs(total_bydir) do
    contents[id] = string.format("  [%s]: %s", k, get_readable_time(v))
    id = id + 1
  end
  vim.api.nvim_win_set_option(win.border.win_id, "winhl", "Normal:PlayedBorder")
  vim.api.nvim_buf_set_lines(bufnr, 0, #contents, false, contents)
end
