"======================================================================
"
" macos.vim - 
"
" Created by skywind on 2021/12/30
" Last Modified: 2021/12/30 20:06:52
"
"======================================================================

function! asyncrun#runner#macos#run(opts)
	if asyncrun#macos#check() == 0
		return asyncrun#utils#errmsg('require macOS !')
	endif
	call asyncrun#macos#start_command('terminal', a:opts)
	redraw!
endfunc


