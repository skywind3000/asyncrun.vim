"======================================================================
"
" gnome.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:33:35
"
"======================================================================


"----------------------------------------------------------------------
" gnome-terminal
"----------------------------------------------------------------------
function! asyncrun#runner#gnome#run(opts)
	if !executable('gnome-terminal')
		return asyncrun#utils#errmsg('gnome-terminal executable not find !')
	endif
	let cmds = []
	let cmds += ['cd ' . shellescape(getcwd()) ]
	let cmds += [a:opts.cmd]
	let cmds += ['echo ""']
	let cmds += ['read -n1 -rsp "press any key to continue ..."']
	let text = shellescape(join(cmds, ";"))
	let command = 'gnome-terminal -- bash -c ' . text
	call system(command . ' &')
endfunction


