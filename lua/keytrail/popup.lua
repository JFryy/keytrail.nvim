local M = {}

local config = require('keytrail.config')

-- Create namespace for virtual text
local ns = vim.api.nvim_create_namespace('keytrail')

-- Track the current popup window and buffer
local current_popup = nil
local current_buf = nil

---Close the current popup if it exists
function M.close()
    if current_popup and vim.api.nvim_win_is_valid(current_popup) then
        vim.api.nvim_win_close(current_popup, true)
    end
    if current_buf and vim.api.nvim_buf_is_valid(current_buf) then
        vim.api.nvim_buf_delete(current_buf, { force = true })
    end
    current_popup = nil
    current_buf = nil
end

---Create a new popup window
---@param path_width number The width needed for the path text
---@return number, number The buffer and window IDs
function M.create(path_width)
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false

    -- Get window dimensions
    local win_width = vim.api.nvim_win_get_width(0)
    local win_height = vim.api.nvim_win_get_height(0)

    -- Calculate popup position and size
    local row = config.get().position == "bottom" and win_height - 1 or 0
    local popup_width = math.min(path_width, win_width)
    local col = win_width - popup_width

    -- Create the popup window
    local popup = vim.api.nvim_open_win(buf, false, {
        relative = 'win',
        row = row,
        col = col,
        width = popup_width,
        height = 1,
        style = 'minimal',
        border = 'none',
        noautocmd = true,
        focusable = false,
        zindex = config.get().zindex,
    })

    -- Set popup window options
    local cfg = config.get()
    local popup_cfg = cfg.popup or {}
    local winblend = popup_cfg.winblend
    if winblend == nil then
        winblend = cfg.winblend or 0
    end
    winblend = math.max(0, math.min(100, winblend))
    vim.wo[popup].winblend = winblend
    vim.wo[popup].cursorline = false
    vim.wo[popup].cursorcolumn = false
    vim.wo[popup].number = false
    vim.wo[popup].relativenumber = false
    vim.wo[popup].signcolumn = 'no'
    vim.wo[popup].foldcolumn = '0'
    vim.wo[popup].list = false
    vim.wo[popup].wrap = false
    vim.wo[popup].linebreak = false
    vim.wo[popup].scrolloff = 0
    vim.wo[popup].sidescrolloff = 0

    -- Set the window highlight to transparent
    vim.api.nvim_win_set_hl_ns(popup, ns)
    vim.wo[popup].winhighlight = 'Normal:KeyTrailPopup'

    return buf, popup
end

---Show the popup with prepared colored text
---@param colored_text table The segments to display (array of {text, highlight})
---@param total_width number The width needed for the popup (optional)
function M.show(colored_text, total_width)
    -- Always close existing popup first
    M.close()

    if not colored_text or vim.tbl_isempty(colored_text) then
        return
    end

    if not total_width then
        total_width = 0
        for _, chunk in ipairs(colored_text) do
            total_width = total_width + #chunk[1]
        end
        total_width = total_width + 2
    end

    -- Create new popup with calculated width
    current_buf, current_popup = M.create(total_width)

    -- Add virtual text with colors, but use overlay positioning instead of right_align
    vim.api.nvim_buf_set_extmark(current_buf, ns, 0, 0, {
        virt_text = colored_text,
        virt_text_pos = "overlay",
    })
end

return M
