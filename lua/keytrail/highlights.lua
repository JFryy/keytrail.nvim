local M = {}

local config = require("keytrail.config")

---Set up all highlight groups
function M.setup()
    -- Set up popup background highlight
    local popup_highlight = config.get().popup_highlight
    if type(popup_highlight) == "string" and popup_highlight ~= "" then
        vim.api.nvim_set_hl(0, "KeyTrailPopup", { link = popup_highlight })
    elseif type(popup_highlight) == "table" then
        vim.api.nvim_set_hl(0, "KeyTrailPopup", popup_highlight)
    else
        local function apply_highlight(name)
            local hl = nil

            if vim.api.nvim_get_hl then
                local ok_new, hl_new = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
                if ok_new then
                    hl = hl_new
                end
            end

            if (not hl or vim.tbl_isempty(hl)) and vim.api.nvim_get_hl_by_name then
                local ok_old, hl_old = pcall(vim.api.nvim_get_hl_by_name, name, true)
                if ok_old and hl_old then
                    hl = {}
                    if hl_old.background then hl.bg = hl_old.background end
                    if hl_old.foreground then hl.fg = hl_old.foreground end
                end
            end

            if not hl or vim.tbl_isempty(hl) then
                return false
            end

            local derived = {}
            if hl.bg then derived.bg = hl.bg else derived.bg = "NONE" end
            if hl.fg then derived.fg = hl.fg else derived.fg = "NONE" end
            if hl.bold then derived.bold = hl.bold end
            if hl.italic then derived.italic = hl.italic end
            if hl.underline then derived.underline = hl.underline end
            if hl.undercurl then derived.undercurl = hl.undercurl end
            if hl.strikethrough then derived.strikethrough = hl.strikethrough end
            vim.api.nvim_set_hl(0, "KeyTrailPopup", derived)
            return true
        end

        if not apply_highlight("NormalFloat") and not apply_highlight("Normal") then
            vim.api.nvim_set_hl(0, "KeyTrailPopup", {
                bg = "NONE",
                fg = "NONE",
            })
        end
    end

    -- Set up color for delimiter
    vim.api.nvim_set_hl(0, "KeyTrailDelimiter", {
        fg = config.get().delimiter_color,
        bold = false,
    })

    -- Set up color for array brackets
    vim.api.nvim_set_hl(0, "KeyTrailBracket", {
        fg = config.get().bracket_color,
        bold = false,
    })

    -- Set up colors for path segments
    for i, color in ipairs(config.get().colors) do
        vim.api.nvim_set_hl(0, "YAMLPathline" .. i, {
            fg = color,
            bg = "NONE",
            bold = false,
        })
    end
end

return M
