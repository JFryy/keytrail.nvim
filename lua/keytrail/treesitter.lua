local M = {}

local config = require('keytrail.config')

---Check if a treesitter parser is ready for use
---@param lang string The language/parser name
---@return boolean ready Whether the parser is ready
function M.ensure_parser_ready(lang)
    local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
    if not ok then
        vim.notify("keytrail: nvim-treesitter not available", vim.log.levels.WARN)
        return false
    end

    -- Check if using new treesitter (get_parser_configs returns nil)
    if not parsers or not parsers.get_parser_configs then
        return true
    end

    local parser_configs = parsers.get_parser_configs()
    local parser_config = parser_configs[lang]
    if not parser_config then
        vim.notify("keytrail: No parser config for " .. lang, vim.log.levels.WARN)
        return false
    end

    -- Check if the parser is installed
    if not parsers.has_parser(lang) then
        vim.schedule(function()
            vim.cmd('TSInstall ' .. lang)
        end)
        vim.notify("keytrail: Installing " .. lang .. " parser...", vim.log.levels.INFO)
        return false
    end

    return true
end

---Remove quotes from a key string
---@param key string The key to clean
---@return string cleaned The cleaned key
function M.clean_key(key)
    return key:gsub('^["\']', ''):gsub('["\']$', '')
end

---Quote a key if it contains the delimiter
---@param key string The key to potentially quote
---@return string quoted The quoted key if needed, otherwise original
function M.quote_key_if_needed(key)
    local delimiter = config.get().delimiter
    if key:find(delimiter, 1, true) then
        return "'" .. key .. "'"
    end
    return key
end

---Get the path at the current cursor position using treesitter
---@param ft string The filetype
---@return string|nil path The path at cursor, or nil if not found
function M.get_path_at_cursor(ft)
    -- Map jsonc and json5 to json parser since they share the same syntax
    local parser_lang = (ft == "jsonc" or ft == "json5") and "json" or ft

    if not M.ensure_parser_ready(parser_lang) then
        return nil
    end

    local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, parser_lang)
    if not ok_parser or not parser then
        return nil
    end

    local trees = parser:parse()
    if not trees or not trees[1] then
        return nil
    end

    local tree = trees[1]
    local root = tree:root()
    if not root then
        return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local node = root:named_descendant_for_range(row, col, row, col)
    if not node then
        return nil
    end

    ---@type string[]
    local path = {}
    while node do
        local type = node:type()

        -- Handle both YAML and JSON object properties
        if type == "block_mapping_pair" or type == "flow_mapping_pair" or type == "pair" then
            local key_node = node:field("key")[1]
            if key_node then
                local key = M.clean_key(vim.treesitter.get_node_text(key_node, 0))
                table.insert(path, 1, M.quote_key_if_needed(key))
            end
            -- Handle both YAML and JSON array items
        elseif type == "block_sequence_item" or type == "flow_sequence_item" or type == "array" then
            local parent = node:parent()
            if parent then
                local index = 0
                for child in parent:iter_children() do
                    if child == node then break end
                    if child:type() == type then index = index + 1 end
                end
                table.insert(path, 1, "[" .. index .. "]") -- Format array index with brackets
            end
        end

        node = node:parent()
    end

    if #path == 0 then
        return nil
    end

    -- Join path segments with delimiter
    return table.concat(path, config.get().delimiter)
end

return M
