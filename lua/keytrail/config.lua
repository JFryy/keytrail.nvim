local M = {}

---@class KeyTrailConfig
local default_config = {
    -- UI settings
    hover_delay = 20,      -- Delay in milliseconds before showing popup
    popup_highlight = nil, -- Highlight or highlight table to use for the popup background (auto-detect when nil)
    winblend = 10,         -- Transparency for the popup window (0-100) (kept for backward compatibility)
    popup = {
        enabled = true,    -- Control whether the floating popup is shown
        winblend = nil,    -- Override transparency for the popup window (0-100)
    },
    statusline = {
        enabled = false, -- Keep an up-to-date cache for statusline integrations
        prefix = "",     -- Text added before the rendered path
        suffix = "",     -- Text added after the rendered path
        empty = "",      -- Text to show when no path is available
    },
    colors = {
        "#d4c4a8",               -- Soft yellow
        "#c4d4a8",               -- Soft green
        "#a8c4d4",               -- Soft blue
        "#d4a8c4",               -- Soft purple
        "#a8d4c4",               -- Soft teal
    },
    delimiter = ".",             -- Dot as default delimiter
    position = "bottom",         -- Position of the popup
    zindex = 1,                  -- z-index of the popup window
    bracket_color = "#0000ff",   -- Blue color for brackets
    delimiter_color = "#ff0000", -- Red color for delimiter
    filetypes = {                -- Supported file types
        yaml = true,
        json = true,
        jsonc = true,
        json5 = true
    },
    key_mapping = "jq",     -- Key mapping for jump window (will be prefixed with <leader>)
    yank_key_mapping = "jy" -- Key mapping for yank command (will be prefixed with <leader>)
}

---@type KeyTrailConfig
local config = vim.deepcopy(default_config)

---Get the current configuration
---@return KeyTrailConfig
function M.get()
    return config
end

---Update the configuration
---@param opts KeyTrailConfig
function M.set(opts)
    if not opts then return end
    -- Only merge fields that are provided in opts
    for k, v in pairs(opts) do
        if type(v) == "table" and type(config[k]) == "table" then
            config[k] = vim.tbl_deep_extend('force', config[k], v)
        else
            config[k] = v
        end
    end
end

---Reset the configuration to defaults
function M.reset()
    config = vim.deepcopy(default_config)
end

return M
