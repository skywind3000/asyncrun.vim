"======================================================================
"
" locator.vim - 
"
" Created by skywind on 2024/02/20
" Last Modified: 2024/02/20 21:02:29
"
"======================================================================


"----------------------------------------------------------------------
" guess current buffer's directory
"----------------------------------------------------------------------
function! asyncrun#locator#nofile_buffer_path()
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
		return ''
	endif
	let path = asyncrun#locator#nofile_buffer_path()
	if path != '' && (isdirectory(path) || filereadable(path))
		return asyncrun#get_root(path)
	endif
	return ''
endfunc


