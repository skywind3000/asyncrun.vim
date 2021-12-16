function! asyncrun#runner#toggleterm#run(opts)
    lua require("asyncrun.toggleterm").runner(vim.fn.eval("a:opts"))
endfunction
