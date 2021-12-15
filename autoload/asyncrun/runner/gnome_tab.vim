"======================================================================
"
" gnome_tab.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:35:44
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :


function! asyncrun#runner#gnome_tab#run(opts)
	if !executable('gnome-terminal')
		return asyncrun#utils#errmsg('gnome-terminal executable not find !')
	endif
	let cmds = []
	let cmds += ['cd ' . shellescape(getcwd()) ]
	let cmds += [a:opts.cmd]
	let cmds += ['echo ""']
	let cmds += ['read -n1 -rsp "press any key to continue ..."']
	let text = shellescape(join(cmds, ";"))
	let command = 'gnome-terminal --tab --active -- bash -c ' . text
	call system(command . ' &')
endfunction


