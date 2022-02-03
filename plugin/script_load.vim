"======================================================================
"
" script_load.vim - load scripts in autoload/asyncrun/{runner,program}
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
let g:asyncrun_program = get(g:, 'asyncrun_program', {})
let s:script_time = {}

let $PYTHONUNBUFFERED = '1'


"----------------------------------------------------------------------
" find script 
"----------------------------------------------------------------------
function! s:find_script(where, name)
	let test = 'autoload/asyncrun/' . a:where . '/' . a:name . '.vim'
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
	let load = s:find_script('runner', name)
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
" load program
"----------------------------------------------------------------------
function! s:load_program(name)
	let name = a:name
	let load = s:find_script('program', name)
	let test = 'asyncrun#program#' . name . '#translate'
	if filereadable(load) && load != ''
		let mtime = getftime(load)
		let ltime = get(s:script_time, load, 0)
		if mtime > ltime
			exec 'source ' . fnameescape(load)
			let s:script_time[load] = mtime
		endif
		if exists('*' . test)
			let g:asyncrun_program[name] = test
		endif
	endif
endfunc


"----------------------------------------------------------------------
" init runner
"----------------------------------------------------------------------
function! g:asyncrun_event.runner(name)
	call s:load_runner(a:name)
endfunc



"----------------------------------------------------------------------
" init program
"----------------------------------------------------------------------
function! g:asyncrun_event.program(name)
	call s:load_program(a:name)
endfunc


