local M = {}

local config = require('keytrail.config')
local popup = require('keytrail.popup')
local render = require('keytrail.render')

-- Timer for hover delay
local hover_timer = nil

-- Cached segments for statusline integration
local statusline_segments = {}

---Check if popup is enabled in config
---@return boolean enabled Whether popup is enabled
local function popup_is_enabled()
    local popup_cfg = config.get().popup
    return not popup_cfg or popup_cfg.enabled ~= false
end

---Check if statusline is enabled in config
---@return boolean enabled Whether statusline is enabled
local function statusline_is_enabled()
    local statusline_cfg = config.get().statusline
    return statusline_cfg and statusline_cfg.enabled
end

---Set the statusline segments cache
---@param segments table The segments to cache
local function set_statusline_segments(segments)
    if not statusline_is_enabled() then
        statusline_segments = {}
        return
    end

    if segments and not vim.tbl_isempty(segments) then
        statusline_segments = segments
    else
        statusline_segments = {}
    end
end

---Get the statusline segments cache
---@return table segments The cached segments
function M.get_statusline_segments()
    return statusline_segments
end

---Update the display (popup and/or statusline)
---@param get_path function Function to get the current path
function M.update(get_path)
    local path = get_path()
    if path == "" then
        set_statusline_segments({})
        popup.close()
        return
    end

    local colored_text, total_width = render.from_path(path)
    set_statusline_segments(colored_text)

    if popup_is_enabled() then
        popup.show(colored_text, total_width)
    else
        popup.close()
    end
end

---Clear the display (popup and statusline)
function M.clear()
    set_statusline_segments({})
    popup.close()
end

---Handle cursor movement with hover delay
---@param get_path function Function to get the current path
function M.handle_cursor_move(get_path)
    -- Clear existing timer
    if hover_timer then
        hover_timer:stop()
        hover_timer = nil
    end

    -- Start new timer
    local delay = config.get().hover_delay or 0
    if not popup_is_enabled() or delay <= 0 then
        M.update(get_path)
        return
    end

    hover_timer = vim.defer_fn(function()
        M.update(get_path)
    end, delay)
end

---Clear the hover timer
function M.clear_hover_timer()
    if hover_timer then
        hover_timer:stop()
        hover_timer = nil
    end
end

---Generate statusline string from cached segments
---@return string statusline The formatted statusline string
function M.generate_statusline()
    local cfg = config.get().statusline or {}
    if not cfg.enabled then
        return cfg.empty or ""
    end

    if vim.tbl_isempty(statusline_segments) then
        return cfg.empty or ""
    end

    local parts = {}
    if cfg.prefix and cfg.prefix ~= "" then
        table.insert(parts, cfg.prefix)
    end

    for _, chunk in ipairs(statusline_segments) do
        local text, hl = chunk[1], chunk[2]
        if hl and hl ~= "" then
            table.insert(parts, "%#" .. hl .. "#" .. text)
        else
            table.insert(parts, text)
        end
    end

    if cfg.suffix and cfg.suffix ~= "" then
        table.insert(parts, cfg.suffix)
    end

    table.insert(parts, "%#StatusLine#")
    return table.concat(parts)
end

return M
