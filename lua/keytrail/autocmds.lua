local M = {}

-- File patterns that KeyTrail supports
M.PATTERNS = { "*.yaml", "*.yml", "*.json", "*.jsonc" }

---Set up all autocommands for KeyTrail
---@param handle_cursor_move function Callback for cursor movement
---@param clear_hover_timer function Callback to clear hover timer
---@param clear_display function Callback to clear display
function M.setup(handle_cursor_move, clear_hover_timer, clear_display)
    local group = vim.api.nvim_create_augroup("KeyTrail", { clear = true })

    -- Show popup on cursor move
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        callback = handle_cursor_move,
        pattern = M.PATTERNS
    })

    -- Clear popup when leaving buffer or window
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "WinScrolled", "ModeChanged" }, {
        group = group,
        callback = function()
            clear_hover_timer()
            clear_display()
        end,
        pattern = M.PATTERNS
    })

    -- Clear popup when entering insert mode
    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
        group = group,
        callback = function()
            clear_hover_timer()
            clear_display()
        end,
        pattern = M.PATTERNS
    })
end

return M
