"======================================================================
"
" xterm.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:37:16
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :

function! asyncrun#runner#xterm#run(opts)
	if !executable('xterm')
		return asyncrun#utils#errmsg('xterm executable not find !')
	endif
	let cmds = []
	let cmds += ['cd ' . shellescape(getcwd()) ]
	let cmds += [a:opts.cmd]
	let cmds += ['echo ""']
	let cmds += ['read -n1 -rsp "press any key to continue ..."']
	let text = shellescape(join(cmds, ";"))
	let command = 'xterm '
	let command .= ' -T ' . shellescape(':AsyncRun ' . a:opts.cmd)
	let command .= ' -e bash -c ' . text
	call system(command . ' &')
endfunc


