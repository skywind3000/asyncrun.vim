"======================================================================
"
" utils.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:33:42
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :


"----------------------------------------------------------------------
" output msg
"----------------------------------------------------------------------
function! asyncrun#utils#errmsg(msg)
	redraw
	echohl ErrorMsg
	echom 'ERROR: ' . a:msg
	echohl NONE
	return 0
endfunc


"----------------------------------------------------------------------
" display require message
"----------------------------------------------------------------------
function! asyncrun#utils#require(what)
	call asyncrun#utils#errmsg('require: ' . a:what . ' ')
endfunc


