"======================================================================
"
" info.vim - 
"
" Created by skywind on 2023/08/05
" Last Modified: 2023/08/05 04:02:20
"
"======================================================================


"----------------------------------------------------------------------
" internal
"----------------------------------------------------------------------
let s:windows = has('win32') || has('win95') || has('win64') || has('win16')
let s:scripthome = fnamemodify(resolve(expand('<sfile>:p')), ':h')


"----------------------------------------------------------------------
" list fts
"----------------------------------------------------------------------
function! asyncrun#info#list_fts()
	let output = []
	for name in asyncrun#compat#list($VIMRUNTIME . '/syntax', 1)
		let extname = fnamemodify(name, ':e')
		" echo name
		if extname == 'vim'
			call add(output, fnamemodify(name, ':t:r'))
		endif
	endfor
	return output
endfunc


"----------------------------------------------------------------------
" list environment names
"----------------------------------------------------------------------
function! asyncrun#info#list_envname()
	if has('python3') == 0
		if has('python2') == 0
			return []
		endif
	endif
	let result = []
	try
		silent! pyx import os as __os
		silent! let result = pyxeval('[name for name in __os.environ]')
	catch
	endtry
	return result
endfunc


"----------------------------------------------------------------------
" 
"----------------------------------------------------------------------
function! asyncrun#info#list_path()
	return split($PATH, s:windows? ';' : ':')
endfunc


"----------------------------------------------------------------------
" 
"----------------------------------------------------------------------
function! asyncrun#info#list_exe_py()
pyx << PYEOF
if 1:
	import sys, os
	_sep = sys.platform[:3] == 'win' and ';' or ':'
	_search = os.environ.get('PATH', '').split(_sep)
	_exename = {}
	for _dirname in _search:
		if not os.path.exists(_dirname):
			continue
		for fn in os.listdir(_dirname):
			if _sep == ':':
				_exename[fn] = 1
			else:
				_fn, _ext = os.path.splitext(os.path.split(fn)[-1])
				if _ext in ('.exe', '.cmd', '.bat'):
					_exename[_fn] = 1
	_output = [n for n in _exename]
	_output.sort()
PYEOF
	return pyxeval('_output')
endfunc


"----------------------------------------------------------------------
" 
"----------------------------------------------------------------------
function! asyncrun#info#list_executable()
	let output = {}
	let check = {'exe': 1, 'cmd':1, 'bat':1}
	if asyncrun#compat#check_python()
		return asyncrun#info#list_exe_py()
	endif
	for dirname in asyncrun#info#list_path()
		if !isdirectory(dirname)
			continue
		endif
		if s:windows != 0
			for ext in ['exe', 'cmd', 'bat']
				let part = asyncrun#compat#glob(dirname . '/*.' . ext, 1)
				for exename in split(part, "\n")
					let fn = fnamemodify(exename, ':t:r')
					let output[fn] = 1
				endfor
			endfor
		else
			let part = asyncrun#compat#glob(dirname . '/*', 1)
			for exename in split(part, "\n")
				if executable(exename)
					let fn = fnamemodify(exename, ':t')
					let output[fn] = 1
				endif
			endfor
		endif
	endfor
	return keys(output)
endfunc


"----------------------------------------------------------------------
" 
"----------------------------------------------------------------------
let g:asyncrun_info_pos = {
			\ 'tab': 'open the terminal in a new tab',
			\ 'TAB': 'open the terminal in a new tab on the left side',
			\ 'curwin': 'open the terminal in the current window',
			\ 'top': 'open the terminal above the current window',
			\ 'bottom': 'open the terminal below the current window',
			\ 'left': 'open the terminal on the left side',
			\ 'right': 'open the terminal on the right side',
			\ 'hide': "don't open a window, run in background",
			\ 'external': 'use an external terminal',
			\ }


"----------------------------------------------------------------------
" list runner
"----------------------------------------------------------------------
function! asyncrun#info#list_runner()
	let runners = {}
	for name in keys(get(g:, 'asyncrun_runner', {}))
		let runners[name] = 'runner'
	endfor
	for rtp in split(&rtp, ',')
		let t = rtp . '/autoload/asyncrun/runner'
		if isdirectory(t)
			for fn in asyncrun#compat#list(t, 1)
				let extname = fnamemodify(fn, ':e')
				let name = fnamemodify(fn, ':t:r')
				if extname == 'vim'
					let runners[name] = 'runner script'
				endif
			endfor
		endif
	endfor
	for fn in asyncrun#compat#list(s:scripthome . '/runner', 1)
		let extname = fnamemodify(fn, ':e')
		let name = fnamemodify(fn, ':t:r')
		if extname == 'vim'
			let runners[name] = 'runner script'
		endif
	endfor
	for name in keys(g:asyncrun_info_pos)
		let runners[name] = g:asyncrun_info_pos[name]
	endfor
	return runners
endfunc


"----------------------------------------------------------------------
" 
"----------------------------------------------------------------------
let g:asyncrun_info_program = {
			\ 'make': 'default makeprg',
			\ 'grep': 'default grepprg',
			\ }

if s:windows
	let g:asyncrun_info_program['wsl'] = 'program wsl'
	for t in ['msys', 'mingw32', 'mingw64', 'clang32', 'clang64', 'cygwin']
		let g:asyncrun_info_program[t] = 'builtin program'
	endfor
endif


"----------------------------------------------------------------------
" 
"----------------------------------------------------------------------
function! asyncrun#info#list_program()
	let program = {}
	for name in keys(get(g:, 'asyncrun_program', {}))
		let program[name] = 'program'
	endfor
	for rtp in split(&rtp, ',')
		let t = rtp . '/autoload/asyncrun/program'
		if isdirectory(t)
			for fn in asyncrun#compat#list(t, 1)
				let extname = fnamemodify(fn, ':e')
				let name = fnamemodify(fn, ':t:r')
				if extname == 'vim'
					let program[name] = 'program script'
				endif
			endfor
		endif
	endfor
	for fn in asyncrun#compat#list(s:scripthome . '/program', 1)
		let extname = fnamemodify(fn, ':e')
		let name = fnamemodify(fn, ':t:r')
		if extname == 'vim'
			let program[name] = 'program script'
		endif
	endfor
	for name in keys(g:asyncrun_info_program)
		let program[name] = g:asyncrun_info_program[name]
	endfor
	return program
endfunc


" echo len(asyncrun#info#list_exe_py())
" echo len(asyncrun#info#list_executable())

" echo asyncrun#info#list_runner()
" echo asyncrun#info#list_program()


