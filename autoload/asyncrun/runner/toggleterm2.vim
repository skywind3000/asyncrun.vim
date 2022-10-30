function! asyncrun#runner#toggleterm2#run(opts)
    lua require("asyncrun_toggleterm").runner(vim.fn.eval("a:opts"))
endfunction