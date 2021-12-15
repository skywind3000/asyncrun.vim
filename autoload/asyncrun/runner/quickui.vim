"======================================================================
"
" quickui.vim - 
"
" Created by skywind on 2021/12/15
" Last Modified: 2021/12/15 06:20:38
"
"======================================================================

function! s:callback(args)
	if s:post_script != ''
		exec s:post_script
		let s:post_script = ''
	endif
endfunc

function! asyncrun#runner#quickui#run(argv)
	let argv = a:argv
	let opts = {}
	let opts.pause = (get(argv, 'close', 0) == 0)? 1 : 0
	let opts.color = 'QuickBG'
	" unsilent echom argv
	if has_key(argv, 'post')
		let s:post_script = argv.post
		let opts.callback = function('s:callback')
	endif
	call quickui#terminal#dialog(argv.cmd, opts)
endfunc


