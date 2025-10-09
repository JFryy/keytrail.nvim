# KeyTrail.nvim
A Neovim plugin in pure lua that shows the current path in YAML and JSON files, with the ability to jump to any path in the document using fuzzyfinding search w/ telescope / filepickers.

![Demo](docs/demo.gif)

## Features

- Shows the current path in YAML and JSON files
- Hover popup with the current path
- Jump to any path in the document using Telescope
- Yank (copy) the current path to clipboard
- Support for both YAML and JSON file types
- Configurable delimiter and hover delay
- Customizable key mapping

## Requirements

- Neovim 0.9.0 or higher
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (or fzf-lua or any file picker)


## Keytrail Jump Config

Keytrail jump implements `vim.ui.select` which is a generic interface that is implemented with most pickers such as telescope, fzf-lua and others. For configuration for Telescope for example,
please ensure you have that implemented in your plugin configuration (e.g. `plugins/telescope.lua`).

telescope:
```lua
    extensions = {
        ["ui-select"] = {
            require("telescope.themes").get_dropdown {
                -- even more opts
            }
        }
    }
}

-- Set telescope as the picker for vim.ui.select
require("telescope").load_extension("ui-select")
```

fzf-lua:
```lua
-- Set fzf-lua as the picker for vim.ui.select
require('fzf-lua').register_ui_select()
```

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "jfryy/keytrail.nvim",
    dependencies = {
        "nvim-treesitter/nvim-treesitter"
    }
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    "jfryy/keytrail.nvim",
    requires = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("keytrail").setup()
    end,
}
```

## Configuration

KeyTrail can be configured by passing a table to the setup function:

```lua
require("keytrail").setup({
    -- The delimiter to use between path segments
    delimiter = ".",
    -- The delay in milliseconds before showing the hover popup
    hover_delay = 100,
    -- The key mapping to use for jumping to a path
    key_mapping = "jq",
    -- The key mapping to use for yanking the current path
    yank_key_mapping = "jy",
    -- The file types to enable KeyTrail for
    filetypes = {
        yaml = true,
        json = true,
    },
})
```

## Usage
KeyTrail provides the following commands:

- `:KeyTrail <path>` - Jump to the specified path
- `:KeyTrailJump` - Open Telescope to select and jump to a path
- `:KeyTrailYank` - Yank (copy) the current path to the clipboard

By default, KeyTrail maps `<leader>jq` to `:KeyTrailJump` and `<leader>jy` to `:KeyTrailYank` in normal mode.

