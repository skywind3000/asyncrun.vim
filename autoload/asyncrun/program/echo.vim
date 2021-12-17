"======================================================================
"
" echo.vim - 
"
" Created by skywind on 2021/12/18
" Last Modified: 2021/12/18 04:17:39
"
"======================================================================

" echom "test load"


function! asyncrun#program#echo#translate(opts)
	return 'echo (' . a:opts.cmd . ')'
endfunc


