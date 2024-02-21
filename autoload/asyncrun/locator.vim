"======================================================================
"
" locator.vim - 
"
" Created by skywind on 2024/02/20
" Last Modified: 2024/02/20 21:02:29
"
"======================================================================


"----------------------------------------------------------------------
" initialize
"----------------------------------------------------------------------
let s:windows = has('win32') || has('win64') || has('win16') || has('win95')


"----------------------------------------------------------------------
" special buffer
"----------------------------------------------------------------------
function! asyncrun#locator#special_buffer_path() abort
	if &bt != ''
		return ''
	endif
	let name = bufname('%')
	if name =~ '\v^fugitive\:[\\\/][\\\/][\\\/]'
		let path = strpart(name, s:windows? 12 : 11)
		let pos = stridx(path, '.git')
		if pos >= 0
			let path = strpart(path, 0, pos)
		endif
		return fnamemodify(path, ':h')
	elseif name =~ '^diffview:\/\/'
		let part = strpart(name, 11)
		let pos = stridx(part, '/.git/:')
		if pos > 0
			return strpart(part, 0, pos)
		endif
	endif
	return ''
endfunc


"----------------------------------------------------------------------
" guess current buffer's directory
"----------------------------------------------------------------------
function! asyncrun#locator#nofile_buffer_path() abort
	if &bt == ''
		return ''
	elseif &bt == 'nofile'
		if &ft == 'floggraph'
			if exists('b:flog_state')
				return get(b:flog_state, 'workdir', '')
			endif
		elseif &ft == 'agit_stat' || &ft == 'agit_diff'
			if exists('t:git')
				if has_key(t:git, 'git_root')
					return t:git['git_root']
				endif
			endif
		elseif &ft == 'magit'
			if exists('b:magit_top_dir')
				return b:magit_top_dir
			endif
		elseif &ft == 'NeogitStatus' && has('nvim')
			try
				let t = luaeval('require("neogit.lib.git").repo.git_root')
				return t
			catch
			endtry
		elseif &ft == 'DiffviewFiles' && has('nvim')
			let t = getline(1)
			if t != '' && isdirectory(t)
				return t
			endif
		endif
		if exists('b:git_dir')
			return b:git_dir
		endif
	endif
	return ''
endfunc


"----------------------------------------------------------------------
" root locator
"----------------------------------------------------------------------
function! asyncrun#locator#detect()
	if &bt == ''
		return asyncrun#locator#special_buffer_path()
	endif
	let path = asyncrun#locator#nofile_buffer_path()
	if path != '' && (isdirectory(path) || filereadable(path))
		return asyncrun#get_root(path)
	endif
	return ''
endfunc


