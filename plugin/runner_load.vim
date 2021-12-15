"======================================================================
"
" runner_load.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 05:40:55
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :


"----------------------------------------------------------------------
" internal
"----------------------------------------------------------------------
let g:asyncrun_event = get(g:, 'asyncrun_event', {})
let g:asyncrun_runner = get(g:, 'asyncrun_runner', {})
let s:script_time = {}


"----------------------------------------------------------------------
" find script 
"----------------------------------------------------------------------
function! s:find_script(name)
	let test = 'autoload/asyncrun/runner/' . a:name . '.vim'
	let fn = findfile(test, &rtp)
	if fn == ''
		return ''
	endif
	let fn = fnamemodify(fn, ':p')
	let fn = substitute(fn, '\\', '/', 'g')
	return fn
endfunc


"----------------------------------------------------------------------
" load runner
"----------------------------------------------------------------------
function! s:load_runner(name)
	let name = a:name
	let load = s:find_script(name)
	let test = 'asyncrun#runner#' . name . '#run'
	if filereadable(load) && load != ''
		let mtime = getftime(load)
		let ltime = get(s:script_time, load, 0)
		if mtime > ltime
			exec 'source ' . fnameescape(load)
			let s:script_time[load] = mtime
		endif
		if exists('*' . test)
			let g:asyncrun_runner[name] = test
		endif
	endif
endfunc


"----------------------------------------------------------------------
" init runner
"----------------------------------------------------------------------
function! g:asyncrun_event.runner(name)
	call s:load_runner(a:name)
endfunc



