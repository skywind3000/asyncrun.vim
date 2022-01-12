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
" strip string
"----------------------------------------------------------------------
function! asyncrun#utils#strip(text)
	return substitute(a:text, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunc


"----------------------------------------------------------------------
" Replace string
"----------------------------------------------------------------------
function! asyncrun#utils#replace(text, old, new)
	let l:data = split(a:text, a:old, 1)
	return join(l:data, a:new)
endfunc


"----------------------------------------------------------------------
" display require message
"----------------------------------------------------------------------
function! asyncrun#utils#require(what)
	call asyncrun#utils#errmsg('require: ' . a:what . ' ')
endfunc


"----------------------------------------------------------------------
" shellescape 
"----------------------------------------------------------------------
function! asyncrun#utils#shellescape(...) abort
	let args = []
	for arg in a:000
		if arg =~# '^[A-Za-z0-9_/.-]\+$'
			let args += [arg]
		elseif &shell =~# 'c\@<!sh'
			let args += [substitute(shellescape(arg), '\\\n', '\n', 'g')]
		else
			let args += [shellescape(arg)]
		endif
	endfor
	return join(args, ' ')
endfunction


"----------------------------------------------------------------------
" tempname
"----------------------------------------------------------------------
function! asyncrun#utils#tempname() abort
	let temp = tempname()
	if has('win32')
		return fnamemodify(fnamemodify(temp, ':h'), ':p').fnamemodify(temp, ':t')
	endif
	return temp
endfunction


"----------------------------------------------------------------------
" isolate environ
"----------------------------------------------------------------------
function! asyncrun#utils#isolate(request, keep, ...) abort
	let keep = ['SHELL', 'HOME'] + a:keep
	let command = ['cd ' . shellescape(getcwd())]
	for line in split(system('env'), "\n")
		let var = matchstr(line, '^\w\+\ze=')
		if !empty(var) && var !~# '^\%(_\|SHLVL\|PWD\|VIM\|VIMRUNTIME\|MYG\=VIMRC\)$' && index(keep, var) < 0
			if &shell =~# 'csh'
				let command += split('setenv '.var.' '.shellescape(eval('$'.var)), "\n")
			else
				let command += split('export '.var.'='.asyncrun#utils#shellescape(eval('$'.var)), "\n")
			endif
		endif
	endfor
	for cmd in a:000
		if type(cmd) == type('')
			let command += [cmd]
		elseif type(cmd) == type(0)
			let command += [cmd]
		elseif type(cmd) == type([])
			let command += cmd
		endif
	endfor
	let temp = type(a:request) == type({}) ? a:request.file . '.script' : asyncrun#utils#tempname()
	call writefile(command, temp)
	return 'env -i ' . join(map(copy(keep), 'v:val."=". asyncrun#utils#shellescape(eval("$".v:val))." "'), '') . &shell . ' ' . temp
endfunction


"----------------------------------------------------------------------
" set title
"----------------------------------------------------------------------
function! asyncrun#utils#set_title(title, expanded)
	return asyncrun#utils#shellescape('printf',
				\ '\033]1;%s\007\033]2;%s\007',
				\ a:title, a:expanded)
endfunction


