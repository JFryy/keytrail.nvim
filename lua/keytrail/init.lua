---@class KeyTrail
local M = {}

---@alias FileType 'yaml'|'json'|'jsonc'|'json5'

-- Lazy-loaded modules
local config, highlights, treesitter, display, autocmds, commands

-- Setup state
local _setup_complete = false

---Lazy module loader
local function ensure_modules()
    if not config then
        config = require('keytrail.config')
        highlights = require('keytrail.highlights')
        treesitter = require('keytrail.treesitter')
        display = require('keytrail.display')
        autocmds = require('keytrail.autocmds')
        commands = require('keytrail.commands')
    end
end

---Get the path at the current cursor position
---@return string path The current path or empty string
local function get_path()
    ensure_modules()
    local ft = vim.bo.filetype
    if not config.get().filetypes[ft] then
        return ""
    end

    local path = treesitter.get_path_at_cursor(ft)
    if not path then
        return ""
    end

    return path
end

---Lazy setup function - only called when needed
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

    -- Setup autocommands with display handlers
    autocmds.setup(
        function() display.handle_cursor_move(get_path) end,
        function() display.clear_hover_timer() end,
        function() display.clear() end
    )

    -- Set up default key mapping for jump
    vim.keymap.set('n', '<leader>' .. config.get().key_mapping, function()
        local ft = vim.bo.filetype
        if not config.get().filetypes[ft] then
            vim.notify("KeyTrail: Current filetype not supported", vim.log.levels.ERROR)
            return
        end
        local jump = require('keytrail.jump')
        jump.jumpwindow()
    end, { desc = 'KeyTrail: Jump to path', silent = true })

    -- Set up default key mapping for yank
    vim.keymap.set('n', '<leader>' .. config.get().yank_key_mapping, function()
        M.handle_yank_command()
    end, { desc = 'KeyTrail: Yank current path', silent = true })
end

---Command handlers (exposed for use in plugin/keytrail.lua)
function M.handle_command(opts)
    ensure_modules()
    commands.handle_command(opts)
end

function M.handle_jump_command()
    ensure_modules()
    commands.handle_jump_command()
end

function M.handle_yank_command()
    ensure_modules()
    commands.handle_yank_command(get_path)
end

---Legacy setup function for manual configuration
function M.setup(opts)
    M.ensure_setup(opts)
end

---Return a statusline-safe string for the current path.
---Intended to be used inside statusline expressions.
function M.statusline()
    ensure_modules()
    return display.generate_statusline()
end

return M
