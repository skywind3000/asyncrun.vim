"======================================================================
"
" shebang.vim - 
"
" Created by skywind on 2022/01/12
" Last Modified: 2022/01/12 22:30:25
"
"======================================================================

function! asyncrun#program#shebang#translate(opts)
	let cmd = asyncrun#utils#strip(a:opts.cmd)
	if cmd == ''
		return 'echo empty command'
	endif
	if cmd =~ '^".*"$'
		let cmd = asyncrun#utils#strip(strpart(cmd, 1, len(cmd) - 2))
	endif
	if cmd =~ '^\''.*\''$'
		let cmd = asyncrun#utils#strip(strpart(cmd, 1, len(cmd) - 2))
	endif
	if filereadable(cmd) == 0
		return 'echo file not find: ' . cmd
	endif
	let textlist = readfile(cmd, '', 20)
	let shebang = ''
	for text in textlist
		let text = asyncrun#utils#strip(text)
		if text =~ '^#'
			let text = asyncrun#utils#strip(strpart(text, 1))
			if text =~ '^!'
				let shebang = asyncrun#utils#strip(strpart(text, 1))
				break
			endif
		endif
	endfor
	if shebang == ''
		return 'echo shebang not find in: ' . cmd
	endif
	return shebang . ' "' . cmd . '"'
endfunc


