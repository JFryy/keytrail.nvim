-- Create lazy-loaded commands and autocommands
local function setup_lazy()
    -- Create the KeyTrail command
    vim.api.nvim_create_user_command('KeyTrail', function(opts)
        require('keytrail').ensure_setup()
        require('keytrail').handle_command(opts)
    end, {
        nargs = 1,
        complete = function()
            return {}
        end
    })

    -- Create the KeyTrailJump command
    vim.api.nvim_create_user_command('KeyTrailJump', function()
        require('keytrail').ensure_setup()
        require('keytrail').handle_jump_command()
    end, {})

    -- Set up filetype autocommand for lazy initialization
    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "yaml", "json" },
        callback = function()
            require('keytrail').ensure_setup()
        end,
        once = false
    })
end

setup_lazy()

