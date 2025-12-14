local M = {}

local config = require('keytrail.config')
local jump = require('keytrail.jump')

---Handle the :KeyTrail <path> command
---@param opts table Command options with args field
function M.handle_command(opts)
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

---Handle the :KeyTrailJump command
function M.handle_jump_command()
    local ft = vim.bo.filetype
    if not config.get().filetypes[ft] then
        vim.notify("KeyTrail: Current filetype not supported", vim.log.levels.ERROR)
        return
    end

    if not jump.jumpwindow() then
        vim.notify("KeyTrail: Could not jump to specified path", vim.log.levels.ERROR)
    end
end

---Handle the :KeyTrailYank command
---@param get_path function Function to get the current path
function M.handle_yank_command(get_path)
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

return M
