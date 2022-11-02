"======================================================================
"
" capture.vim - 
"
" Created by skywind on 2022/11/02
" Last Modified: 2022/11/02 17:21:04
"
"======================================================================

if !exists('g:asyncrun_capture_file')
	if isdirectory(expand('~/.vim'))
		let g:asyncrun_capture_file = expand('~/.vim/capture.tmp')
	else
		let base = expand('~/.cache/vim')
		if !isdirectory(base)
			silent! call mkdir(base, 'p')
		endif
		let g:asyncrun_capture_file = base . '/capture.tmp'
	endif
endif

function! asyncrun#program#capture#translate(opts)
	let cmd = asyncrun#utils#strip(a:opts.cmd)
	let tmp = g:asyncrun_capture_file
	let tee = ''
	if a:opts.code != 6
	endif
	if executable('tee')
		let tee = 'tee'
	elseif executable('busybox')
		let tee = 'busybox tee'
	else
		call asyncrun#utils#errmsg('not find tee')
		return cmd
	endif
	let s:history_cmd = cmd
	let cmd = cmd . ' | ' . shellescape(tee) . ' ' . shellescape(tmp)
	let a:opts.post = 'call asyncrun#program#capture#update()'
	let a:opts.safe = 1
	return cmd
endfunc


function! asyncrun#program#capture#update()
	let tmp = g:asyncrun_capture_file
	if filereadable(tmp)
		let msg = get(s:, 'history_cmd', '')
		let msg = '[' . msg . ']'
		cexpr msg
		let save = &l:makeencoding
		if g:asyncrun_encs != ''
			let &l:makeencoding = g:asyncrun_encs
		endif
		exec 'caddf ' . fnameescape(g:asyncrun_capture_file)
		let &l:makeencoding = save
		cfirst
		silent! call delete(tmp)
		let s:history_cmd = ''
		call asyncrun#utils#quickfix_request()
	endif
endfunc


