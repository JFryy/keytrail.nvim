local M = {}

local config = require("keytrail.config")

---Split a rendered path into highlighted chunks for display.
---@param path string
---@return table chunks -- Array of {text, highlight}
---@return number width -- Approximate display width including padding
function M.from_path(path)
    if path == nil or path == "" then
        return {}, 0
    end

    local cfg = config.get()
    local delimiter = cfg.delimiter
    local colored_text = {}
    local total_width = 0

    local segments = vim.split(path, delimiter, { plain = true })

    for i, segment in ipairs(segments) do
        local color_idx = ((i - 1) % #cfg.colors) + 1
        if segment:match("^%[.*%]$") then
            local index = segment:match("%[(%d+)%]")
            table.insert(colored_text, { "[", "KeyTrailBracket" })
            table.insert(colored_text, { index, "YAMLPathline" .. color_idx })
            table.insert(colored_text, { "]", "KeyTrailBracket" })
            total_width = total_width + #segment
        else
            table.insert(colored_text, { segment, "YAMLPathline" .. color_idx })
            total_width = total_width + #segment
        end
        if i < #segments and not segments[i + 1]:match("^%[.*%]$") then
            table.insert(colored_text, { delimiter, "KeyTrailDelimiter" })
            total_width = total_width + #delimiter
        end
    end

    total_width = total_width + 2

    return colored_text, total_width
end

return M
