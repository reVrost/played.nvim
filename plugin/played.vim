augroup Played
  autocmd!
  autocmd CursorMoved,CursorMovedI * :lua require("played").start_counting()
  autocmd CursorHold,CursorHoldI * :lua require("played").stop_counting()
augroup end
