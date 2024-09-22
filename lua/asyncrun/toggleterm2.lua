local terminal = require("toggleterm.terminal").Terminal
local M = {}

M.setup = function(opts)
    M._asyncrun_mapping = opts.mapping
    M._start_in_insert = opts.start_in_insert
    M._clear_env = opts.clear_env
    M._go_back = opts.go_back
end

function M.reset()
    if M._asyncrun_term ~= nil then
        if vim.g.asynctasks_term_reuse ~= 1 then
            -- TODO: handle multiple terminals
            error("Terminal existed is not support . please set g.asynctasks_term_reuse = 1")
        end
        M._asyncrun_term:shutdown()
        M._asyncrun_term = nil
    end
end

function M.runner(opts)
    M.reset()
    M._asyncrun_term = terminal:new({
        cmd = opts.cmd,
        dir = opts.cwd,
        close_on_exit = (opts.close == "1") and true or false,
        hidden = true,
        clear_env = M._clear_env or false,
        on_open = function(term)
            if M._start_in_insert then
                vim.cmd("startinsert!")
            else
                vim.cmd("stopinsert")
            end
        end,
        on_exit = function(term, job_id, exit_code, event_name)
            vim.g.asyncrun_code = exit_code
            vim.cmd("doautocmd User AsyncRunStop")
        end,
    })

    function M._asyncrun_term_toggle()
        M._asyncrun_term:toggle()
    end

    if not opts.silent then
        M._asyncrun_term_toggle()
        if M._go_back then
            vim.cmd("wincmd p")
        end
    end

    if M._asyncrun_mapping then
        vim.api.nvim_set_keymap("n", M._asyncrun_mapping,
            "<cmd>lua require('asyncrun.toggleterm2')._asyncrun_term_toggle()<CR>", {
                noremap = true,
                silent = true
            })
    end
end

return M
