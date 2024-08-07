function! asyncrun#runner#toggleterm2#run(opts)
    lua require("asyncrun.toggleterm2").runner(vim.fn.eval("a:opts"))
endfunction
