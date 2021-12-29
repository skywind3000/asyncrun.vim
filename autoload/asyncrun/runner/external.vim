"======================================================================
"
" external.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:50:05
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :

if has('win32') || has('win64') || has('win16') || has('win95')
	finish
endif

function! asyncrun#runner#external#run(opts)
	let d = ['gnome', 'xfce', 'konsole', 'xterm']
	let p = get(g:, 'asyncrun_external', d)
	for n in p
		if n == 'gnome' && executable('gnome-terminal')
			return asyncrun#runner#gnome#run(a:opts)
		elseif n == 'xterm' && executable('xterm')
			return asyncrun#runner#xterm#run(a:opts)
		elseif n == 'konsole' && executable('konsole')
			return asyncrun#runner#konsole#run(a:opts)
		elseif n == 'xfce' && executable('xfce4-terminal')
			return asyncrun#runner#xfce#run(a:opts)
		endif
	endfor
endfunc


