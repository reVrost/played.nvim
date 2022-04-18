local played = require("played")
-- Not sure if this is the correct place to put these AUTOCMDs
-- AUTOCMD
local group = vim.api.nvim_create_augroup("played", { clear = true })
-- When theres an input

played.load()
print("Loaded")

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = group,
  callback = played.start_counting,
})
-- This is when AFK is detected
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = group,
  callback = played.stopping_soon,
})
