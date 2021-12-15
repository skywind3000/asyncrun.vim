"======================================================================
"
" tmux.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:52:27
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :

function! asyncrun#runner#tmux#run(opts)
	if exists('*VimuxRunCommand') == 0
		return asyncrun#utils#errmsg('require benmills/vimux')
	endif
	let cwd = getcwd()
	call VimuxRunCommand('cd ' . shellescape(cwd) . '; ' . a:opts.cmd)
endfunc


