local M = {}
local config = require('keytrail.config')
local treesitter = require('keytrail.treesitter')

-- Helper: smart path splitting that handles quoted segments
---@param path string
---@param delimiter string
---@return string[]
local function split_path_segments(path, delimiter)
    local segments = {}
    local current_segment = ""
    local in_quotes = false
    local quote_char = nil
    local i = 1

    while i <= #path do
        local char = path:sub(i, i)

        if not in_quotes then
            if char == "'" or char == '"' then
                in_quotes = true
                quote_char = char
                current_segment = current_segment .. char
            elseif char == delimiter then
                if current_segment ~= "" then
                    table.insert(segments, current_segment)
                    current_segment = ""
                end
            else
                current_segment = current_segment .. char
            end
        else
            current_segment = current_segment .. char
            if char == quote_char then
                in_quotes = false
                quote_char = nil
            end
        end

        i = i + 1
    end

    -- Add the last segment
    if current_segment ~= "" then
        table.insert(segments, current_segment)
    end

    return segments
end

---@param ft string The file type
---@param path string The path to find (e.g. "data[0].key1")
---@return boolean success Whether the jump was successful
function M.jump_to_path(ft, path)
    -- Map jsonc to json parser since they share the same syntax
    local parser_lang = ft == "jsonc" and "json" or ft

    if not treesitter.ensure_parser_ready(parser_lang) then
        return false
    end

    local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, parser_lang)
    if not ok_parser or not parser then
        return false
    end

    local trees = parser:parse()
    if not trees or not trees[1] then
        return false
    end

    local tree = trees[1]
    local root = tree:root()
    if not root then
        return false
    end

    -- Split path into segments
    local segments = split_path_segments(path, config.get().delimiter)
    local current_node = root

    -- Handle root node based on file type
    if parser_lang == "json" then
        -- For JSON, get the actual object from the program node
        for child in current_node:iter_children() do
            if child:type() == "object" then
                current_node = child
                break
            end
        end
    elseif ft == "yaml" then
        -- Handle YAML document structure
        if current_node:type() == "stream" then
            for child in current_node:iter_children() do
                if child:type() == "document" then
                    current_node = child
                    break
                end
            end
        end

        if current_node:type() == "document" then
            for child in current_node:iter_children() do
                if child:type() == "block_node" or child:type() == "block_mapping" then
                    current_node = child
                    break
                end
            end
        end

        -- If we're at a block_node, get its block_mapping child
        if current_node:type() == "block_node" then
            for child in current_node:iter_children() do
                if child:type() == "block_mapping" then
                    current_node = child
                    break
                end
            end
        end
    end

    -- Traverse the path
    for _, segment in ipairs(segments) do
        local found = false
        -- Check if segment is an array index
        local index = segment:match("%[(%d+)%]")
        local key = segment:match("^([^%[]+)%[")

        if index then
            -- Handle array access
            local array_index = tonumber(index)

            -- First find the mapping pair with the array key
            if key then
                for child in current_node:iter_children() do
                    local type = child:type()

                    if type == "block_mapping_pair" or type == "flow_mapping_pair" or type == "pair" then
                        local key_node = child:field("key")[1]
                        if key_node then
                            local found_key = treesitter.clean_key(vim.treesitter.get_node_text(key_node, 0))

                            if found_key == treesitter.clean_key(key) then
                                -- Get the value node which should contain the array
                                local value_node = child:field("value")[1]
                                if value_node then
                                    -- For JSON, the value might be an array directly
                                    if value_node:type() == "array" then
                                        current_node = value_node
                                        -- If the value is a block_node, get its content
                                    elseif value_node:type() == "block_node" then
                                        for content in value_node:iter_children() do
                                            if content:type() == "block_sequence" or content:type() == "flow_sequence" or content:type() == "array" then
                                                current_node = content
                                                break
                                            end
                                        end
                                    else
                                        current_node = value_node
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Now find the array item at the specified index
            local current_index = 0

            -- For JSON arrays, we need to handle both array_element nodes and direct object nodes
            for child in current_node:iter_children() do
                local type = child:type()

                -- Skip non-element nodes in JSON arrays (like commas and brackets)
                if type == "," or type == "[" or type == "]" then
                    goto continue
                end

                if current_index == array_index then
                    -- For JSON, the array element might be an object directly
                    if type == "object" then
                        current_node = child
                        found = true
                        break
                    end

                    -- For YAML, handle block sequence items
                    if type == "block_sequence_item" then
                        -- For YAML sequence items, we need to get the block node
                        for content in child:iter_children() do
                            if content:type() == "block_node" then
                                -- For block nodes, get their block mapping
                                for mapping in content:iter_children() do
                                    if mapping:type() == "block_mapping" then
                                        current_node = mapping
                                        found = true
                                        break
                                    end
                                end
                                if found then break end
                            end
                        end
                        if found then break end
                    end

                    -- For other formats, check for array element types
                    if type == "flow_sequence_item" or type == "array_element" then
                        -- For list items, we need to get the actual content node
                        for content in child:iter_children() do
                            if content:type() == "object" then
                                current_node = content
                                found = true
                                break
                            elseif content:type() == "block_node" or
                                content:type() == "block_mapping" or
                                content:type() == "flow_mapping" then
                                current_node = content
                                found = true
                                break
                            elseif content:type() == "flow_node" or
                                content:type() == "plain_scalar" or
                                content:type() == "string" or
                                content:type() == "number" or
                                content:type() == "true" or
                                content:type() == "false" or
                                content:type() == "null" then
                                -- For scalar values, use the content node directly
                                current_node = content
                                found = true
                                break
                            end
                        end
                        if found then break end
                    end
                end

                if type ~= "," and type ~= "[" and type ~= "]" then
                    current_index = current_index + 1
                end

                ::continue::
            end
        else
            -- Handle object property access
            for child in current_node:iter_children() do
                local type = child:type()

                -- Handle both direct key-value pairs and nested mappings
                if type == "block_mapping_pair" or type == "flow_mapping_pair" or type == "pair" then
                    local key_node = child:field("key")[1]
                    if key_node then
                        key = treesitter.clean_key(vim.treesitter.get_node_text(key_node, 0))

                        if key == treesitter.clean_key(segment) then
                            -- Get the value node
                            local value_node = child:field("value")[1]
                            if value_node then
                                -- For value nodes, we need to get the actual content if it's a block_node
                                if value_node:type() == "block_node" then
                                    for content in value_node:iter_children() do
                                        if content:type() == "block_mapping" or
                                            content:type() == "flow_mapping" or
                                            content:type() == "object" then
                                            current_node = content
                                            found = true
                                            break
                                        elseif content:type() == "block_sequence" or
                                            content:type() == "flow_sequence" or
                                            content:type() == "array" then
                                            -- If we found a sequence, get its first item
                                            current_node = content
                                            for item in content:iter_children() do
                                                if item:type() == "block_sequence_item" or
                                                    item:type() == "flow_sequence_item" or
                                                    item:type() == "array_element" then
                                                    -- Get the content of the first item
                                                    for item_content in item:iter_children() do
                                                        if item_content:type() == "block_node" then
                                                            -- For YAML block nodes, get their block mapping
                                                            for mapping in item_content:iter_children() do
                                                                if mapping:type() == "block_mapping" then
                                                                    current_node = mapping
                                                                    found = true
                                                                    break
                                                                end
                                                            end
                                                            if found then break end
                                                        elseif item_content:type() == "block_mapping" or
                                                            item_content:type() == "flow_mapping" or
                                                            item_content:type() == "object" then
                                                            current_node = item_content
                                                            found = true
                                                            break
                                                        elseif item_content:type() == "flow_node" or
                                                            item_content:type() == "plain_scalar" or
                                                            item_content:type() == "string" or
                                                            item_content:type() == "number" or
                                                            item_content:type() == "true" or
                                                            item_content:type() == "false" or
                                                            item_content:type() == "null" then
                                                            current_node = item_content
                                                            found = true
                                                            break
                                                        end
                                                    end
                                                    break
                                                end
                                            end
                                            if found then break end
                                        end
                                    end
                                else
                                    current_node = value_node
                                    found = true
                                end
                            else
                                current_node = child
                                found = true
                            end
                            if found then break end
                        end
                    end
                end
            end
        end

        if not found then
            vim.notify("Failed to find segment: " .. segment, vim.log.levels.ERROR)
            return false
        end
    end

    -- Jump to the found node
    local start_row, start_col = current_node:start()
    vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
    return true
end

---Get all possible paths in the current document
---@return table paths Array of paths
local function get_all_paths()
    local ft = vim.bo.filetype
    -- Map jsonc to json parser since they share the same syntax
    local parser_lang = ft == "jsonc" and "json" or ft

    if not treesitter.ensure_parser_ready(parser_lang) then
        return {}
    end

    local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, parser_lang)
    if not ok_parser or not parser then
        return {}
    end

    local trees = parser:parse()
    if not trees or not trees[1] then
        return {}
    end

    local tree = trees[1]
    local root = tree:root()
    if not root then
        return {}
    end

    local paths = {}
    local function traverse_node(node, current_path)
        local type = node:type()

        -- Handle YAML document structure
        if parser_lang == "yaml" then
            if type == "stream" or type == "document" or type == "block_node" then
                for child in node:iter_children() do
                    traverse_node(child, current_path)
                end
                return
            end
        end

        -- Handle JSON structure
        if parser_lang == "json" then
            if type == "program" or type == "document" or type == "object" then
                for child in node:iter_children() do
                    traverse_node(child, current_path)
                end
                return
            end

            if type == "array" then
                local index = 0
                for child in node:iter_children() do
                    if child:type() == "array_element" then
                        local new_path = current_path .. "[" .. index .. "]"
                        table.insert(paths, new_path)
                        traverse_node(child, new_path)
                        index = index + 1
                    end
                end
                return
            end
        end

        -- Handle object properties
        if type == "pair" or type == "block_mapping_pair" or type == "flow_mapping_pair" then
            local key_node = node:field("key")[1]
            if key_node then
                local key = treesitter.clean_key(vim.treesitter.get_node_text(key_node, 0))
                local new_path = current_path ..
                (current_path ~= "" and config.get().delimiter or "") .. treesitter.quote_key_if_needed(key)
                table.insert(paths, new_path)

                -- Traverse value node
                local value_node = node:field("value")[1]
                if value_node then
                    traverse_node(value_node, new_path)
                end
            end
            -- Handle array items
        elseif type == "block_sequence_item" or type == "flow_sequence_item" then
            local parent = node:parent()
            if parent then
                local index = 0
                for child in parent:iter_children() do
                    if child == node then break end
                    if child:type() == type then index = index + 1 end
                end
                local new_path = current_path .. "[" .. index .. "]"
                table.insert(paths, new_path)

                -- Traverse array item content
                for child in node:iter_children() do
                    traverse_node(child, new_path)
                end
            end
            -- Handle block mappings and sequences
        elseif type == "block_mapping" or type == "flow_mapping" or type == "block_sequence" or type == "flow_sequence" then
            for child in node:iter_children() do
                traverse_node(child, current_path)
            end
        end
    end

    traverse_node(root, "")
    return paths
end

---Open picker to select and jump to a path
---@return boolean success Whether the jump was successful
function M.jumpwindow()
    local ft = vim.bo.filetype
    if not config.get().filetypes[ft] then
        vim.notify("KeyTrail: Current filetype not supported", vim.log.levels.ERROR)
        return false
    end

    -- Get all possible paths
    local paths = get_all_paths()
    if #paths == 0 then
        vim.notify("KeyTrail: No paths found in current document", vim.log.levels.WARN)
        return false
    end

    -- Use vim.ui.select which will use whatever picker is configured
    -- (telescope, fzf-lua, mini.picker, etc.)
    vim.ui.select(paths, {
        prompt = "Select path to jump to: ",
        format_item = function(path)
            return path
        end,
    }, function(selected_path)
        if selected_path then
            M.jump_to_path(ft, selected_path)
        end
    end)

    return true
end

return M
