"======================================================================
"
" floater_reuse.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:48:57
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :

function! asyncrun#runner#floaterm_reuse#run(opts)
	let curr_bufnr = floaterm#curr()
	if has_key(a:opts, 'silent') && a:opts.silent == 1
		FloatermHide!
	endif
	let cmd = 'cd ' . shellescape(getcwd())
	call floaterm#terminal#send(curr_bufnr, [cmd])
	call floaterm#terminal#send(curr_bufnr, [a:opts.cmd])
	stopinsert
	if &filetype == 'floaterm' && g:floaterm_autoinsert
		call floaterm#util#startinsert()
	endif
	return 0
endfunc


