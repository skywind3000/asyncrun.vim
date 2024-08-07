local terminal = require("toggleterm.terminal").Terminal
local M = {}

M.setup = function(opts)
    M._asyncrun_mapping = opts.mapping
    M._start_in_insert = opts.start_in_insert
end

function M.reset()
    if M._asyncrun_term ~= nil then
        if vim.g.asynctasks_term_reuse ~= 1 then
            -- TODO: handle multiple terminals
            error("Terminal existed is not support . please set g.asynctasks_term_reuse = 1")
        else
            vim.notify("Delete existing terminal", "info")
        end
        M._asyncrun_term:shutdown()
    end

    M._asyncrun_term = nil
    M._asyncrun_term_toggle = nil
end

function M.runner(opts)
    M.reset()
    M._asyncrun_term = terminal:new({
        cmd = opts.cmd,
        dir = opts.cwd,
        close_on_exit = false,
        hidden = true,
        on_open = function(term)
            if M._start_in_insert then
                vim.cmd("startinsert!")
            else
                vim.cmd("stopinsert!")
            end
        end
    })

    function M._asyncrun_term_toggle()
        M._asyncrun_term:toggle()
    end

    if not opts.silent then
        M._asyncrun_term_toggle()
    end

    if M._asyncrun_mapping then
        vim.api.nvim_set_keymap("n", M._asyncrun_mapping,
            "<cmd>lua require('asyncrun_toggleterm')._asyncrun_term_toggle()<CR>", {
                noremap = true,
                silent = true
            })
    end
end

return M
