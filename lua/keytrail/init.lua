---@class KeyTrail
local M = {}

---@alias FileType 'yaml'|'json'

-- Lazy-loaded modules
local config, popup, highlights, jump

-- Timer for hover delay
local hover_timer = nil

-- Setup state
local _setup_complete = false

-- Lazy module loader
local function ensure_modules()
    if not config then
        config = require('keytrail.config')
        popup = require('keytrail.popup')
        highlights = require('keytrail.highlights')
        jump = require('keytrail.jump')
    end
end

---@param lang string
---@return boolean
local function ensure_parser_ready(lang)
    local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
    if not ok then
        vim.notify("yaml_pathline: nvim-treesitter not available", vim.log.levels.WARN)
        return false
    end

    -- Check if using new treesitter (get_parser_configs returns nil)
    if not parsers or not parsers.get_parser_configs then
        return true
    end

    local parser_configs = parsers.get_parser_configs()
    local parser_config = parser_configs[lang]
    if not parser_config then
        vim.notify("yaml_pathline: No parser config for " .. lang, vim.log.levels.WARN)
        return false
    end

    -- Check if the parser is installed
    if not parsers.has_parser(lang) then
        vim.schedule(function()
            vim.cmd('TSInstall ' .. lang)
        end)
        vim.notify("yaml_pathline: Installing " .. lang .. " parser...", vim.log.levels.INFO)
        return false
    end

    return true
end

-- Helper: extract key from node text
---@param key string
local function clean_key(key)
    return key:gsub('^["\']', ''):gsub('["\']$', '')
end

-- Helper: quote key if it contains delimiter
---@param key string
local function quote_key_if_needed(key)
    ensure_modules()
    local delimiter = config.get().delimiter
    if key:find(delimiter, 1, true) then
        return "'" .. key .. "'"
    end
    return key
end

---@param ft FileType
---@return string|nil
local function get_treesitter_path(ft)
    if not ensure_parser_ready(ft) then
        return nil
    end

    local ok_parser, parser = pcall(vim.treesitter.get_parser, 0, ft)
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
                local key = clean_key(vim.treesitter.get_node_text(key_node, 0))
                table.insert(path, 1, quote_key_if_needed(key))
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

    -- Join path segments with a beautiful delimiter
    ensure_modules()
    return table.concat(path, config.get().delimiter)
end

-- Entry point
---@return string
local function get_path()
    ensure_modules()
    local ft = vim.bo.filetype
    if not config.get().filetypes[ft] then
        return ""
    end

    local path = get_treesitter_path(ft)
    if not path then
        return ""
    end

    return path
end

-- Handle cursor movement
local function handle_cursor_move()
    -- Clear existing timer
    if hover_timer then
        hover_timer:stop()
        hover_timer = nil
    end

    -- Start new timer
    ensure_modules()
    hover_timer = vim.defer_fn(function()
        popup.show(get_path())
    end, config.get().hover_delay)
end

-- Helper function to clear hover timer
local function clear_hover_timer()
    if hover_timer then
        hover_timer:stop()
        hover_timer = nil
    end
end

-- Set up autocommands
local function setup()
    local group = vim.api.nvim_create_augroup("KeyTrail", { clear = true })

    -- Show popup on cursor move
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        callback = handle_cursor_move,
        pattern = { "*.yaml", "*.yml", "*.json" }
    })

    -- Clear popup when leaving buffer or window
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "WinScrolled", "ModeChanged" }, {
        group = group,
        callback = function()
            clear_hover_timer()
            ensure_modules()
            popup.close()
        end,
        pattern = { "*.yaml", "*.yml", "*.json" }
    })

    -- Clear popup when entering insert mode
    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
        group = group,
        callback = function()
            clear_hover_timer()
            ensure_modules()
            popup.close()
        end,
        pattern = { "*.yaml", "*.yml", "*.json" }
    })
end

-- Generic handler function for all events
local function handle_event()
    ensure_modules()
    popup.show(get_path())
end

-- Handler functions
M.handle_cursor_move = handle_event
M.handle_window_change = handle_event
M.handle_buffer_change = handle_event

-- Lazy setup function - only called when needed
function M.ensure_setup(opts)
    if _setup_complete then
        return
    end
    _setup_complete = true

    ensure_modules()

    -- Ensure leader key is set
    if vim.g.mapleader == nil then
        vim.g.mapleader = " "
    end

    if opts ~= nil then
        config.set(opts)
    end
    highlights.setup()
    setup()

    -- Set up default key mapping for jump
    vim.keymap.set('n', '<leader>' .. config.get().key_mapping, function()
        local ft = vim.bo.filetype
        if not config.get().filetypes[ft] then
            vim.notify("KeyTrail: Current filetype not supported", vim.log.levels.ERROR)
            return
        end
        jump.jumpwindow()
    end, { desc = 'KeyTrail: Jump to path', silent = true })

    -- Set up default key mapping for yank
    vim.keymap.set('n', '<leader>' .. config.get().yank_key_mapping, function()
        M.handle_yank_command()
    end, { desc = 'KeyTrail: Yank current path', silent = true })
end

-- Command handlers
function M.handle_command(opts)
    ensure_modules()
    local ft = vim.bo.filetype
    if not config.get().filetypes[ft] then
        vim.notify("KeyTrail: Current filetype not supported", vim.log.levels.ERROR)
        return
    end

    if not opts.args or opts.args == "" then
        vim.notify("KeyTrail: Please provide a path to jump to", vim.log.levels.ERROR)
        return
    end

    if not jump.jump_to_path(ft, opts.args) then
        vim.notify("KeyTrail: Could not find path: " .. opts.args, vim.log.levels.ERROR)
    end
end

function M.handle_jump_command()
    ensure_modules()
    local ft = vim.bo.filetype
    if not config.get().filetypes[ft] then
        vim.notify("KeyTrail: Current filetype not supported", vim.log.levels.ERROR)
        return
    end

    if not jump.jumpwindow() then
        vim.notify("KeyTrail: Could not jump to specified path", vim.log.levels.ERROR)
    end
end

function M.handle_yank_command()
    ensure_modules()
    local ft = vim.bo.filetype
    if not config.get().filetypes[ft] then
        vim.notify("KeyTrail: Current filetype not supported", vim.log.levels.ERROR)
        return
    end

    local path = get_path()
    if path == "" then
        vim.notify("KeyTrail: No path found at cursor position", vim.log.levels.WARN)
        return
    end

    vim.fn.setreg('+', path)
    vim.notify("KeyTrail: Yanked path: " .. path, vim.log.levels.INFO)
end

-- Legacy setup function for manual configuration
function M.setup(opts)
    M.ensure_setup(opts)
end

return M
