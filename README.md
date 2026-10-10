# bufswitch.nvim

An automatic, numbered buffer history for Neovim, drawn in the winbar.

Every file you open is added to a short list across the top of the window. The newest is
`1`, the one before it `2`, and so on. Jump to any of them with one home-row key, step
back and forth through them, and drop the ones you're done with. It works like
harpoon, except you never have to mark anything.

```
  1: init.lua    2: ui.lua   3: README.md   4: config.lua
```

The current buffer is highlighted, and each name gets its filetype icon if you have an
icon plugin. Once the list grows past 7 entries, the other entries shrink to just their
number and icon, e.g. `[3]`, so the bar stays on one line.

## Contents

- [How it behaves](#how-it-behaves)
- [Requirements](#requirements)
- [Installation](#installation)
- [Default keymaps](#default-keymaps)
- [Commands](#commands)
- [Configuration](#configuration)
- [Lua API](#lua-api)
- [Highlights](#highlights)
- [Putting the bar somewhere else](#putting-the-bar-somewhere-else)

## How it behaves

- **Entering a file adds it to the front of the list.** Opening it with `:e`, a picker,
  `gd` or anything else all count.
- **The order doesn't change when you revisit a file.** Going back to a buffer that's
  already in the list only moves the highlight, so its number stays the same, and your
  fingers learn that `<A-s>` is "the file I was just in".
- **Back and forward follow the list order.** `back` goes toward older entries and wraps
  from the oldest to the newest. `forward` goes toward newer entries. Both take a count.
- **Removing an entry only takes it off the list.** The buffer stays open, and entering
  it again puts it back at the front. To remove the entry you're on, use `remove_back`
  or `remove_forward`, which also take you to its neighbour.
- **Pausing freezes the list.** While paused, newly opened files aren't recorded, but
  moving into a file that's already listed still moves the highlight. Use `add` to put
  the current buffer on the list by hand. This gives you a fixed working set, much like
  harpoon.
- **Some buffers are never recorded:** buffers without a name, unlisted buffers,
  `buftype=nofile`, and anything that matches `exclude`. The defaults cover oil,
  harpoon's menu and Telescope's prompt.
- **Tool windows are left alone.** `ignore` lists them, and the defaults cover Neogit,
  Diffview (the whole diff tab) and the Avante sidebar. Entering these windows doesn't
  change the history or the winbar, and the switch keys won't swap out the buffers
  inside them.

The history lasts for one Neovim session and isn't saved to disk.

## Requirements

- Neovim **0.10** or newer
- Optional: file icons from [mini.icons](https://github.com/echasnovski/mini.icons)
  (used first) or [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons),
  with a [Nerd Font](https://www.nerdfonts.com/). Without either, the bar shows
  plain file names.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ElliotLearnsThings/bufswitch.nvim",
  lazy = false, -- load at startup so the first file you open is recorded
  opts = {},
}
```

`opts = {}` is all you need, because lazy passes it to `require("bufswitch").setup()`.
Set `vim.g.mapleader` **before** lazy loads the plugin, or the `<leader>` keys will be
mapped with the wrong leader.

> [!IMPORTANT]
> Don't give the spec `keys = …` or `cmd = …`. They make lazy hold the plugin back until
> you press a key, so every file you opened before then is missing from the history.
> `event = "VeryLazy"` works, since the plugin records the open buffer when it loads,
> but `lazy = false` is simpler.

Without lazy.nvim, put the plugin on your `runtimepath` (with
[vim-plug](https://github.com/junegunn/vim-plug), `vim.pack`, or a git clone into
`pack/*/start/`) and call setup yourself:

```lua
require("bufswitch").setup()
```

## Default keymaps

All mappings are normal mode.

| Key | Action |
| --- | --- |
| `<A-a>` `<A-s>` `<A-d>` `<A-f>` `<A-g>` `<A-h>` `<A-j>` `<A-k>` `<A-l>` | Go to entry 1–9 |
| `<>` | Go back (toward older entries), takes a count: `3<>` |
| `><` | Go forward (toward newer entries), takes a count |
| `<leader>j1` … `<leader>j9` | Remove entry 1–9 from the list (stays on the current buffer) |
| `<<` | Remove the current entry and open the older one |
| `>>` | Remove the current entry and open the newer one |
| `<leader>jl` | Pause / resume recording |
| `<leader>jj` | Add the current buffer (while paused) |
| `<leader>jk` | Clear the list and start again from the current buffer |
| `<leader>bb` | Print the raw history (debugging) |

> [!WARNING]
> By default `<<` and `>>` **replace Vim's shift-line-left/right** in normal mode.
> Indenting in visual mode (`<`, `>`) and with a motion (`<j`, `>ip`) still works. To
> keep the built-ins, remap or disable these two:
>
> ```lua
> opts = { keys = { remove_back = "<leader>j<", remove_forward = "<leader>j>" } }
> ```

The `<A-…>` keys need your terminal to send Alt as Meta. Most Linux terminals do this
out of the box. On macOS, turn on "Use Option as Meta key" in Terminal or
"Left Option key: Esc+" in iTerm2.

## Commands

The `:BufSwitch` command does everything the keymaps do, and tab-completes its subcommands.

| Command | Action |
| --- | --- |
| `:BufSwitch back [count]` | Go back |
| `:BufSwitch forward [count]` | Go forward |
| `:BufSwitch jump {n}` | Go to entry `n` |
| `:BufSwitch remove {n}` | Remove entry `n` from the list |
| `:BufSwitch remove_back` | Remove the current entry, open the older one |
| `:BufSwitch remove_forward` | Remove the current entry, open the newer one |
| `:BufSwitch toggle_pause` | Pause / resume recording |
| `:BufSwitch add` | Add the current buffer (while paused) |
| `:BufSwitch clear` | Clear the list |
| `:BufSwitch inspect` | Print the raw history |

## Configuration

These are the defaults. Pass only the options you want to change.

```lua
require("bufswitch").setup({
  -- Start with recording paused
  start_paused = false,

  -- Draw the bar in the global winbar. Set to false and use require("bufswitch").render()
  -- to put it somewhere else (see below)
  winbar = true,

  -- Past this many entries the unselected ones shrink to their number and icon
  compact_after = 7,

  -- Print what the history is doing
  debug = false,

  -- Set any key to false to leave it unmapped, or `keys = false` to map nothing
  keys = {
    back = "<>",
    forward = "><",
    -- The n-th key goes to entry n of the bar, as many as you like
    jump = { "<A-a>", "<A-s>", "<A-d>", "<A-f>", "<A-g>", "<A-h>", "<A-j>", "<A-k>", "<A-l>" },
    -- The n-th key removes entry n
    remove = {
      "<leader>j1", "<leader>j2", "<leader>j3", "<leader>j4", "<leader>j5",
      "<leader>j6", "<leader>j7", "<leader>j8", "<leader>j9",
    },
    remove_back = "<<",
    remove_forward = ">>",
    add = "<leader>jj",
    toggle_pause = "<leader>jl",
    clear = "<leader>jk",
    inspect = "<leader>bb",
  },

  -- Buffers that are never recorded
  exclude = {
    buftypes = { "nofile" },                               -- exact 'buftype' values
    filetypes = { "^oil$", "harpoon", "TelescopePrompt" }, -- Lua patterns
    names = { "^oil://", "Neogit" },                       -- Lua patterns on the buffer name
  },

  -- Tool windows bufswitch stays out of entirely: entering them leaves the history and
  -- the winbar alone, and the switch keys do nothing inside them
  ignore = {
    filetypes = { "^Neogit", "^Diffview", "^Avante" },
    names = { "^neogit://", "^diffview://" },
    diffview_tab = true, -- every window in a diffview.nvim tab, including the file side of a diff
  },
})
```

Tables of options merge into the defaults key by key, but **lists are replaced whole**.
So `exclude = { filetypes = { "fugitive" } }` excludes only `fugitive`. Copy the
defaults above into your list if you want to keep them. Misspelled option names
produce a warning.

### Examples

Keep the numbered jump keys and turn everything else off:

```lua
opts = {
  keys = {
    back = false, forward = false, remove = false,
    remove_back = false, remove_forward = false,
    add = false, toggle_pause = false, clear = false, inspect = false,
  },
}
```

Jump with `<leader>1`…`<leader>5` instead of Alt:

```lua
opts = {
  keys = { jump = { "<leader>1", "<leader>2", "<leader>3", "<leader>4", "<leader>5" } },
}
```

Don't record fugitive or terminal buffers either:

```lua
opts = {
  exclude = {
    buftypes = { "nofile", "terminal" },
    filetypes = { "^oil$", "harpoon", "TelescopePrompt", "^fugitive" },
    names = { "^oil://", "Neogit", "^fugitive://" },
  },
}
```

## Lua API

Use these to build your own mappings. Each one redraws the bar afterwards.

```lua
local bufswitch = require("bufswitch")

bufswitch.back(count)      -- go back `count` entries (default 1)
bufswitch.forward(count)   -- go forward `count` entries (default 1)
bufswitch.jump(n)          -- go to entry n (1 = most recent)
bufswitch.remove(n)        -- remove entry n from the list
bufswitch.remove_back()    -- remove the current entry, open the older one
bufswitch.remove_forward() -- remove the current entry, open the newer one
bufswitch.add()            -- add the current buffer (while paused)
bufswitch.toggle_pause()
bufswitch.clear()
bufswitch.inspect()        -- print the raw history
bufswitch.render()         -- the bar as a statusline string
```

For example, to go back with `<BS>`, counts included:

```lua
vim.keymap.set("n", "<BS>", function() require("bufswitch").back(vim.v.count) end)
```

## Highlights

| Group | Default | Used for |
| --- | --- | --- |
| `BufSwitchSel` | `TabLineSel`, bold | The current entry |
| `BufSwitchDim` | links to `TabLine` | All other entries |

The groups are set with `default = true`, so your own definitions win. Set them from a
`ColorScheme` autocmd so they survive switching colorschemes:

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "BufSwitchSel", { link = "PmenuSel" })
    vim.api.nvim_set_hl(0, "BufSwitchDim", { link = "Comment" })
  end,
})
```

Icons keep their own colour on the background of the entry they sit in.

## Putting the bar somewhere else

The bar uses the **global** winbar. A plugin window that sets its own winbar, like
Avante or Diffview, keeps it. If something else already uses your winbar, such as
breadcrumbs, set `winbar = false` and show the bar wherever you like with
`render()`. In the tabline, for example:

```lua
opts = { winbar = false }

-- then, anywhere in your config
vim.o.showtabline = 2
vim.o.tabline = "%!v:lua.require'bufswitch'.render()"
```

## License

MIT, see [LICENSE](LICENSE).
