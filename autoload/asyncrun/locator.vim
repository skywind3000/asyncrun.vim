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
function! asyncrun#locator#buffer_path()
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
	let path = asyncrun#locator#buffer_path()
	if path != '' && (isdirectory(path) || filereadable(path))
		return asyncrun#get_root(path)
	endif
	return ''
endfunc


