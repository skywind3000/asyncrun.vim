"======================================================================
"
" locator.vim - 
"
" Created by skywind on 2024/02/20
" Last Modified: 2024/02/20 21:02:29
"
"======================================================================


"----------------------------------------------------------------------
" root locator
"----------------------------------------------------------------------
function! asyncrun#locator#detect()
	if &bt == ''
		return ''
	elseif &bt == 'nofile'
		if &ft == 'floggraph'
			if exists('b:flog_state')
				let root = get(b:flog_state, 'workdir', '')
				if root != '' && isdirectory(root)
					return root
				endif
			endif
		endif
	endif
	return ''
endfunc


