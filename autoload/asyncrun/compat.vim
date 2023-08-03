"======================================================================
"
" compat.vim - 
"
" Created by skywind on 2023/08/03
" Last Modified: 2023/08/03 23:45:25
"
"======================================================================


"----------------------------------------------------------------------
" glob files
"----------------------------------------------------------------------
function! asyncrun#compat#glob( ... )
	let l:nosuf = (a:0 > 1 && a:2)
	let l:list = (a:0 > 2 && a:3)
	if l:nosuf
		let l:save_wildignore = &wildignore
		set wildignore=
	endif
	try
		let l:result = call('glob', [a:1])
		return (l:list ? split(l:result, '\n') : l:result)
	finally
		if exists('l:save_wildignore')
			let &wildignore = l:save_wildignore
		endif
	endtry
endfunc


"----------------------------------------------------------------------
" list files
"----------------------------------------------------------------------
function! asyncrun#compat#list(path, ...)
	let nosuf = (a:0 > 0)? (a:1) : 0
	if !isdirectory(a:path)
		return []
	endif
	let path = a:path . '/*'
	let part = asyncrun#compat#glob(path, nosuf)
	let candidate = []
	for n in split(part, "\n")
		let f = fnamemodify(n, ':t')
		if !empty(f)
			let candidate += [f]
		endif
	endfor
	return candidate
endfunc


