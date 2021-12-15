"======================================================================
"
" termhelp.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:40:30
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :

function! asyncrun#runner#termhelp#run(args)
	let cwd = getcwd()
	call TerminalSend('cd ' . shellescape(cwd) . "\r")
	call TerminalSend(a:args.cmd . "\r")
endfunc

