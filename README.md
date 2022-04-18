# played.nvim

Displays how long you've spent in a project/directory
Like a time log.
Useful if you're doing some consulting/freelancing work and in need of a timesheet

Still WIP
Haven't tested but most likely only compatible with neovim

## Installation

Use packer, add below

```
{
    "reVrost/played.nvim"
}
```

## Keybind

Neovim 0.7 (for vim.keymap_set)

```

vim.keymap.set({"n"}, "<leader>tt", function()
  require("played").get_played()
end)

```
