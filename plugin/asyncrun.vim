" asyncrun.vim - Run shell commands in background and output to quickfix
"
" Maintainer: skywind3000 (at) gmail.com
" Homepage: http://www.vim.org/scripts/script.php?script_id=5431
"
" Last change: 2016.10.16
"
" Run shell command in background and output to quickfix:
"     :AsyncRun[!] [options] {cmd} ...
"
"     when "!" is included, auto-scroll in quickfix will be disabled
"     parameters are splited by space, if a parameter contains space,
"     it should be quoted or escaped as backslash + space (unix only).
"
" Parameters will be expanded if they start with '%', '#' or '<' :
"     %:p     - File name of current buffer with full path
"     %:t     - File name of current buffer without path
"     %:p:h   - File path of current buffer without file name
"     %:e     - File extension of current buffer
"     %:t:r   - File name of current buffer without path and extension
"     %       - File name relativize to current directory
"     %:h:.   - File path relativize to current directory
"     <cwd>   - Current directory
"     <cword> - Current word under cursor
"     <cfile> - Current file name under cursor
"
" Environment variables are set before executing:
"     $VIM_FILEPATH  - File name of current buffer with full path
"     $VIM_FILENAME  - File name of current buffer without path
"     $VIM_FILEDIR   - Full path of current buffer without the file name
"     $VIM_FILEEXT   - File extension of current buffer
"     $VIM_FILENOEXT - File name of current buffer without path and extension
"     $VIM_CWD       - Current directory
"     $VIM_RELDIR    - File path relativize to current directory
"     $VIM_RELNAME   - File name relativize to current directory 
"     $VIM_CWORD     - Current word under cursor
"     $VIM_CFILE     - Current filename under cursor
"     $VIM_GUI       - Is running under gui ?
"     $VIM_VERSION   - Value of v:version
"     $VIM_MODE      - Execute via 0:!, 1:makeprg, 2:system(), 3:silent
"     $VIM_COLUMNS   - How many columns in vim's screen
"     $VIM_LINES     - How many lines in vim's screen
"
"     parameters also accept these environment variables wrapped by 
"     "$(...)", and "$(VIM_FILEDIR)" will be expanded as file directory
"
" There can be some options before [cmd]:
"     -mode=0/1/2  - start mode: 0(async, default), 1(makeprg), 2(!)
"     -cwd=?       - initial directory, (use current directory if unset)
"     -save=0/1    - non-zero to save unsaved files before executing
"     -program=?   - set to 'make' to use '&makeprg'
"
"     All options must start with a minus and position **before** `[cmd]`.
"     Since no shell command starts with a minus. So they can be 
"     distinguished from shell command easily without any ambiguity.
"
" Stop the running job by signal TERM:
"     :AsyncStop[!]
"
"     when "!" is included, job will be stopped by signal KILL
"
" Settings:
"     g:asyncrun_exit - script will be executed after finished
"     g:asyncrun_bell - non-zero to ring a bell after finished
"     g:asyncrun_mode - 0:async(require vim 7.4.1829) 1:sync 2:shell
"     g:asyncrun_encs - shell program output encoding
"
" Variables:
"     g:asyncrun_code - exit code
"     g:asyncrun_status - 'running', 'success' or 'failure'
"
" Requirements:
"     vim 7.4.1829 is minimal version to support async mode
"
" Examples:
"     :AsyncRun gcc % -o %<
"     :AsyncRun make -f Mymakefile
"     :AsyncRun! grep -R <cword> .
"     :noremap <F7> :AsyncRun gcc % -o %< <cr>
"
" Additional:
"     AsyncRun uses quickfix window to show job outputs, in order to 
"     see the outputs in realtime, you need open quickfix window at 
"     first by using :copen (see :help copen/cclose). Or use
"     ':call asyncrun#quickfix_toggle(8)' to open/close it rapidly.
"

"----------------------------------------------------------------------
"- Global Settings & Variables
"----------------------------------------------------------------------
if !exists('g:asyncrun_exit')
	let g:asyncrun_exit = ''
endif

if !exists('g:asyncrun_bell')
	let g:asyncrun_bell = 0
endif

if !exists('g:asyncrun_stop')
	let g:asyncrun_stop = ''
endif

if !exists('g:asyncrun_mode')
	let g:asyncrun_mode = 0
endif

if !exists('g:asyncrun_last')
	let g:asyncrun_last = 0
endif

if !exists('g:asyncrun_timer')
	let g:asyncrun_timer = 100
endif

if !exists('g:asyncrun_code')
	let g:asyncrun_code = ''
endif

if !exists('g:asyncrun_status')
	let g:asyncrun_status = 'stop'
endif

if !exists('g:asyncrun_encs')
	let g:asyncrun_encs = ''
endif

if !exists('g:asyncrun_trim')
	let g:asyncrun_trim = 0
endif



"----------------------------------------------------------------------
"- Internal Functions
"----------------------------------------------------------------------

" error message
function! s:ErrorMsg(msg)
	echohl ErrorMsg
	echom 'ERROR: '. a:msg
	echohl NONE
endfunc

" show not support message
function! s:NotSupport()
	let l:msg = "required: +timers +channel +job +reltime and vim >= 7.4.1829"
	call s:ErrorMsg(l:msg)
endfunc

let s:asyncrun_windows = 0
let g:asyncrun_windows = 0
let s:asyncrun_support = 0
let g:asyncrun_support = 0

" check running in windows
if has('win32') || has('win64') || has('win95') || has('win16')
	let s:asyncrun_windows = 1
	let g:asyncrun_windows = 1
endif

" check has advanced mode
if v:version >= 800 || has('patch-7.4.1829') || has('nvim')
	if has('job') && has('channel') && has('timers') && has('reltime') 
		let s:asyncrun_support = 1
		let g:asyncrun_support = 1
	elseif has('nvim')
		let s:asyncrun_support = 1
		let g:asyncrun_support = 1
	endif
endif

" backup local makeprg and errorformat
function! s:MakeSave()
	let s:make_save = &l:makeprg
	let s:match_save = &l:errorformat
endfunc

" restore local makeprg and errorformat
function! s:MakeRestore()
	let &l:makeprg = s:make_save
	let &l:errorformat = s:match_save
endfunc


"----------------------------------------------------------------------
"- build in background
"----------------------------------------------------------------------
let s:async_output = {}
let s:async_head = 0
let s:async_tail = 0
let s:async_code = 0
let s:async_state = 0
let s:async_start = 0.0
let s:async_debug = 0
let s:async_quick = 0
let s:async_scroll = 0
let s:async_neovim = has('nvim')? 1 : 0

" check :cbottom available
if has('patch-7.4.1997') && (!has('nvim'))
	let s:async_quick = 1
endif

" scroll quickfix down
function! s:AsyncRun_Job_Scroll()
	if getbufvar('%', '&buftype') == 'quickfix'
		silent normal G
	endif
endfunc

" quickfix window cursor check
function! s:AsyncRun_Job_Cursor()
	if &buftype == 'quickfix'
		if s:async_neovim != 0
			let w:async_qfview = winsaveview()
		endif
		if line('.') != line('$')
			let s:async_check_last = 0
		endif
	endif
endfunc

" find quickfix window and scroll to the bottom then return last window
function! s:AsyncRun_Job_AutoScroll()
	if s:async_quick == 0
		let l:winnr = winnr()			
		windo call s:AsyncRun_Job_Scroll()
		silent exec ''.l:winnr.'wincmd w'
	else
		cbottom
	endif
endfunc

" restore view in neovim
function! s:AsyncRun_Job_NeoReset()
	if &buftype == 'quickfix'
		if exists('w:async_qfview')
			call winrestview(w:async_qfview)
			unlet w:async_qfview
		endif
	endif
endfunc

" neoview will reset cursor when caddexpr is invoked
function! s:AsyncRun_Job_NeoRestore()
	if &buftype == 'quickfix'
		call s:AsyncRun_Job_NeoReset()
	else
		let l:winnr = winnr()
		windo call s:AsyncRun_Job_NeoReset()
		silent exec ''.l:winnr.'wincmd w'
	endif
endfunc

" check if quickfix window can scroll now
function! s:AsyncRun_Job_CheckScroll()
	if g:asyncrun_last == 0
		if &buftype == 'quickfix'
			if s:async_neovim != 0
				let w:async_qfview = winsaveview()
			endif
			return (line('.') == line('$'))
		else
			return 1
		endif
	elseif g:asyncrun_last == 1
		let s:async_check_last = 1
		let l:winnr = winnr()
		windo call s:AsyncRun_Job_Cursor()
		silent exec ''.l:winnr.'wincmd w'
		return s:async_check_last
	elseif g:asyncrun_last == 2
		return 1
	else
		if &buftype == 'quickfix'
			if s:async_neovim != 0
				let w:async_qfview = winsaveview()
			endif
			return (line('.') == line('$'))
		else
			return (!pumvisible())
		endif
	endif
endfunc

" invoked on timer or finished
function! s:AsyncRun_Job_Update(count)
	let l:iconv = (g:asyncrun_encs != "")? 1 : 0
	let l:count = 0
	let l:total = 0
	let l:check = s:AsyncRun_Job_CheckScroll()
	if g:asyncrun_encs == &encoding
		let l:iconv = 0 
	endif
	while s:async_tail < s:async_head
		let l:text = s:async_output[s:async_tail]
		if l:iconv != 0
			try
				let l:text = iconv(l:text, g:asyncrun_encs, &encoding)
			catch /.*/
			endtry
		endif
		if l:text != ''
			caddexpr l:text
		elseif g:asyncrun_trim == 0
			caddexpr "\n"
		endif
		let l:total += 1
		unlet s:async_output[s:async_tail]
		let s:async_tail += 1
		let l:count += 1
		if a:count > 0 && l:count >= a:count
			break
		endif
	endwhile
	if s:async_scroll != 0 && l:total > 0 && l:check != 0
		call s:AsyncRun_Job_AutoScroll()
	elseif s:async_neovim != 0 
		call s:AsyncRun_Job_NeoRestore()
	endif
	return l:count
endfunc

" invoked on timer
function! g:AsyncRun_Job_OnTimer(id)
	if exists('s:async_job')
		call job_status(s:async_job)
	endif
	call s:AsyncRun_Job_Update(5 + g:asyncrun_timer)
endfunc

" invoked on "callback" when job output
function! g:AsyncRun_Job_OnCallback(channel, text)
	if !exists("s:async_job")
		return
	endif
	if type(a:text) != 1
		return
	endif
	let s:async_output[s:async_head] = a:text
	let s:async_head += 1
	if g:asyncrun_timer <= 0
		call s:AsyncRun_Job_Update(-1)
	endif
endfunc

" because exit_cb and close_cb are disorder, we need OnFinish to guarantee
" both of then have already invoked
function! s:AsyncRun_Job_OnFinish(what)
	" caddexpr '(OnFinish): '.a:what.' '.s:async_state
	if s:async_state == 0
		return -1
	endif
	if a:what == 0
		let s:async_state = or(s:async_state, 2)
	elseif a:what == 1
		let s:async_state = or(s:async_state, 4)
	else
		let s:async_state = 7
	endif
	if and(s:async_state, 7) != 7
		return -2
	endif
	if exists('s:async_job')
		unlet s:async_job
	endif
	if exists('s:async_timer')
		call timer_stop(s:async_timer)
		unlet s:async_timer
	endif
	call s:AsyncRun_Job_Update(-1)
	let l:current = float2nr(reltimefloat(reltime()))
	let l:last = l:current - s:async_start
	let l:check = s:AsyncRun_Job_CheckScroll()
	if s:async_code == 0
		let l:text = "[Finished in ".l:last." seconds]"
		call setqflist([{'text':l:text}], 'a')
		let g:asyncrun_status = "success"
	else
		let l:text = 'with code '.s:async_code
		let l:text = "[Finished in ".l:last." seconds ".l:text."]"
		call setqflist([{'text':l:text}], 'a')
		let g:asyncrun_status = "failure"
	endif
	let s:async_state = 0
	if s:async_scroll != 0 && l:check != 0
		call s:AsyncRun_Job_AutoScroll()
	elseif has('nvim')
		call s:AsyncRun_Job_NeoRestore()
	endif
	let g:asyncrun_code = s:async_code
	if g:asyncrun_bell != 0
		exec 'norm! \<esc>'
	endif
	redrawstatus!
	redraw
	if g:asyncrun_exit != ""
		exec g:asyncrun_exit
	endif
endfunc

" invoked on "close_cb" when channel closed
function! g:AsyncRun_Job_OnClose(channel)
	" caddexpr "[close]"
	let s:async_debug = 1
	let l:limit = 512
	while ch_status(a:channel) == 'buffered'
		let l:text = ch_read(a:channel)
		if l:text == '' " important when child process is killed
			let l:limit -= 1
			if l:limit < 0 | break | endif
		endif
		call g:AsyncRun_Job_OnCallback(a:channel, l:text)
	endwhile
	let s:async_debug = 0
	call s:AsyncRun_Job_Update(-1)
	call s:AsyncRun_Job_OnFinish(1)
	if exists('s:async_job')
		call job_status(s:async_job)
	endif
endfunc

" invoked on "exit_cb" when job exited
function! g:AsyncRun_Job_OnExit(job, message)
	" caddexpr "[exit]: ".a:message." ".type(a:message)
	let s:async_code = a:message
	call s:AsyncRun_Job_OnFinish(0)
endfunc

" invoked on neovim when stderr/stdout/exit
function! g:AsyncRun_Job_NeoVim(job_id, data, event)
	if a:event == 'stdout' || a:event == 'stderr'
		let l:index = 0
		let l:size = len(a:data)
		while l:index < l:size
			let s:async_output[s:async_head] = a:data[l:index]
			let s:async_head += 1
			let l:index += 1
		endwhile
		call s:AsyncRun_Job_Update(-1)
	elseif a:event == 'exit'
		call s:AsyncRun_Job_OnFinish(2)
	endif
endfunc

" start background build
function! g:AsyncRun_Job_Start(cmd)
	let l:running = 0
	let l:empty = 0
	if s:asyncrun_support == 0
		call s:NotSupport()
		return -1
	endif
	if exists('s:async_job')
		if !has('nvim')
			if job_status(s:async_job) == 'run'
				let l:running = 1
			endif
		else
			if s:async_job > 0
				let l:running = 1
			endif
		endif
	endif
	if type(a:cmd) == 1
		if a:cmd == '' | let l:empty = 1 | endif
	elseif type(a:cmd) == 3
		if a:cmd == [] | let l:empty = 1 | endif
	endif
	if s:async_state != 0 || l:running != 0
		call s:ErrorMsg("background job is still running")
		return -2
	endif
	if l:empty != 0
		call s:ErrorMsg("empty arguments")
		return -3
	endif
	if !filereadable(&shell)
		let l:text = "invalid config in &shell and &shellcmdflag"
		call s:ErrorMsg(l:text . ", &shell must be an executable.")
		return -4
	endif
	let l:args = [&shell, &shellcmdflag]
	let l:name = []
	if type(a:cmd) == 1
		let l:name = a:cmd
		if s:asyncrun_windows == 0
			let l:args += [a:cmd]
		else
			let l:tmp = fnamemodify(tempname(), ':h') . '\asyncrun.cmd'
			let l:run = ['@echo off', a:cmd]
			call writefile(l:run, l:tmp)
			let l:args += [shellescape(l:tmp)]
		endif
	elseif type(a:cmd) == 3
		if s:asyncrun_windows == 0
			let l:temp = []
			for l:item in a:cmd
				if index(['|', '`'], l:item) < 0
					let l:temp += [fnameescape(l:item)]
				else
					let l:temp += ['|']
				endif
			endfor
			let l:args += [join(l:temp, ' ')]
		else
			let l:args += a:cmd
		endif
		let l:vector = []
		for l:x in a:cmd
			let l:vector += ['"'.l:x.'"']
		endfor
		let l:name = join(l:vector, ', ')
	endif
	if s:async_neovim == 0
		let l:options = {}
		let l:options['callback'] = 'g:AsyncRun_Job_OnCallback'
		let l:options['close_cb'] = 'g:AsyncRun_Job_OnClose'
		let l:options['exit_cb'] = 'g:AsyncRun_Job_OnExit'
		let l:options['out_io'] = 'pipe'
		let l:options['err_io'] = 'out'
		let l:options['out_mode'] = 'nl'
		let l:options['err_mode'] = 'nl'
		let l:options['stoponexit'] = 'term'
		if g:asyncrun_stop != ''
			let l:options['stoponexit'] = g:asyncrun_stop
		endif
		let s:async_job = job_start(l:args, l:options)
		let l:success = (job_status(s:async_job) != 'fail')? 1 : 0
	else
		let l:callbacks = {'shell': 'AsyncRun'}
		let l:callbacks['on_stdout'] = function('g:AsyncRun_Job_NeoVim')
		let l:callbacks['on_stderr'] = function('g:AsyncRun_Job_NeoVim')
		let l:callbacks['on_exit'] = function('g:AsyncRun_Job_NeoVim')
		let s:async_job = jobstart(l:args, l:callbacks)
		let l:success = (s:async_job > 0)? 1 : 0
	endif
	if l:success != 0
		let s:async_output = {}
		let s:async_head = 0
		let s:async_tail = 0
		let l:arguments = "[".l:name."]"
		let l:title = ':AsyncRun '.l:name
		if s:async_neovim == 0
			if has('patch-7.4.2210')
				call setqflist([], ' ', {'title':l:title})
			else
				call setqflist([], '')
			endif
		else
			call setqflist([], ' ', l:title)
		endif
		call setqflist([{'text':l:arguments}], 'a')
		let s:async_start = float2nr(reltimefloat(reltime()))
		if g:asyncrun_timer > 0 && s:async_neovim == 0
			let l:options = {'repeat':-1}
			let l:name = 'g:AsyncRun_Job_OnTimer'
			let s:async_timer = timer_start(100, l:name, l:options)
		endif
		let s:async_state = 1
		let g:asyncrun_status = "running"
		redrawstatus!
	else
		unlet s:async_job
		call s:ErrorMsg("Background job start failed '".a:cmd."'")
		return -5
	endif
	return 0
endfunc

" stop background job
function! g:AsyncRun_Job_Stop(how)
	let l:how = a:how
	if s:asyncrun_support == 0
		call s:NotSupport()
		return -1
	endif
	if l:how == '' | let l:how = 'term' | endif
	if exists('s:async_job')
		if s:async_neovim == 0
			if job_status(s:async_job) == 'run'
				call job_stop(s:async_job, l:how)
			else
				return -2
			endif
		else
			if s:async_job > 0
				call jobstop(s:async_job)
			endif
		endif
	else
		return -3
	endif
	return 0
endfunc

" get job status
function! g:AsyncRun_Job_Status()
	if exists('s:async_job')
		if s:async_neovim == 0
			return job_status(s:async_job)
		else
			return 'run'
		endif
	else
		return 'none'
	endif
endfunc



"----------------------------------------------------------------------
" Replace string
"----------------------------------------------------------------------
function! s:StringReplace(text, old, new)
	let l:data = split(a:text, a:old, 1)
	return join(l:data, a:new)
endfunc


"----------------------------------------------------------------------
" Trim leading and tailing spaces
"----------------------------------------------------------------------
function! s:StringStrip(text)
	return substitute(a:text, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunc


"----------------------------------------------------------------------
" extract options from command
"----------------------------------------------------------------------
function! s:ExtractOpt(command) 
	let cmd = a:command
	let opts = {}
	while cmd =~# '^-\%(\w\+\)\%([= ]\|$\)'
		let opt = matchstr(cmd, '^-\zs\w\+')
		if cmd =~ '^-\w\+='
			let val = matchstr(cmd, '^-\w\+=\zs\%(\\.\|\S\)*')
		else
			let val = (opt == 'cwd')? '' : 1
		endif
		if opt == 'cwd'
			let opts.cwd = fnamemodify(expand(val), ':p:s?[^:]\zs[\\/]$??')
		elseif index(['mode', 'program', 'save'], opt) >= 0
			let opts[opt] = substitute(val, '\\\(\s\)', '\1', 'g')
		endif
		let cmd = substitute(cmd, '^-\w\+\%(=\%(\\.\|\S\)*\)\=\s*', '', '')
	endwhile
	let cmd = substitute(cmd, '^\s*\(.\{-}\)\s*$', '\1', '')
	let cmd = substitute(cmd, '^@\s*', '', '')
	let opts.cwd = get(opts, 'cwd', '')
	let opts.mode = get(opts, 'mode', '')
	let opts.save = get(opts, 'save', '')
	let opts.program = get(opts, 'program', '')
	if 0
		echom 'cwd:'. opts.cwd
		echom 'mode:'. opts.mode
		echom 'save:'. opts.save
		echom 'program:'. opts.program
		echom 'command:'. cmd
	endif
	return [cmd, opts]
endfunc


"----------------------------------------------------------------------
" AsyncRun
"----------------------------------------------------------------------
function! s:AsyncRun(bang, mods, args)
	let l:macros = {}
	let l:macros['VIM_FILEPATH'] = expand("%:p")
	let l:macros['VIM_FILENAME'] = expand("%:t")
	let l:macros['VIM_FILEDIR'] = expand("%:p:h")
	let l:macros['VIM_FILENOEXT'] = expand("%:t:r")
	let l:macros['VIM_FILEEXT'] = "." . expand("%:e")
	let l:macros['VIM_CWD'] = getcwd()
	let l:macros['VIM_RELDIR'] = expand("%:h:.")
	let l:macros['VIM_RENAME'] = expand("%:p:.")
	let l:macros['VIM_CWORD'] = expand("<cword>")
	let l:macros['VIM_CFILE'] = expand("<cfile>")
	let l:macros['VIM_VERSION'] = ''.v:version
	let l:macros['VIM_SVRNAME'] = v:servername
	let l:macros['VIM_COLUMNS'] = ''.&columns
	let l:macros['VIM_LINES'] = ''.&lines
	let l:macros['VIM_GUI'] = has('gui_running')? 1 : 0
	let l:macros['<cwd>'] = getcwd()
	let l:command = s:StringStrip(a:args)
	let cd = haslocaldir()? 'lcd ' : 'cd '

	" extract options
	let [l:command, l:opts] = s:ExtractOpt(l:command)

	" replace macros and setup environment variables
	for [l:key, l:val] in items(l:macros)
		let l:replace = (l:key[0] != '<')? '$('.l:key.')' : l:key
		if l:key[0] != '<'
			exec 'let $'.l:key.' = l:val'
		endif
		let l:command = s:StringReplace(l:command, l:replace, l:val)
		let l:opts.cwd = s:StringReplace(l:opts.cwd, l:replace, l:val)
	endfor

	" check if need to save
	if get(l:opts, 'save', '')
		try
			silent update
		catch /.*/
		endtry
	endif

	if a:bang == '!'
		let s:async_scroll = 0
	else
		let s:async_scroll = 1
	endif

	" check mode
	let l:mode = g:asyncrun_mode

	if l:opts.mode != ''
		let l:mode = l:opts.mode
	endif

	" process makeprg/grepprg in -program=?
	let l:program = ""

	if l:opts.program == 'make'
		let l:program = &makeprg
	elseif l:opts.program == 'grep'
		let l:program = &grepprg
	endif

	if l:program != ''
		if l:program =~# '\$\*'
			let l:command = s:StringReplace(l:program, '\$\*', l:command)
		elseif l:command != ''
			let l:command = l:program . ' ' . l:command
		else
			let l:command = l:program
		endif
		let l:command = s:StringStrip(l:command)
	endif

	if l:command =~ '^\s*$'
		echohl ErrorMsg
		echom "E471: Command required"
		echohl NONE
		return
	endif

	if l:opts.cwd != ''
		let l:opts.savecwd = getcwd()
		try
			exec cd . fnameescape(l:opts.cwd)
		catch /.*/
			echohl ErrorMsg
			echom "E344: Can't find directory \"".l:opts.cwd."\" in -cwd"
			echohl NONE
			return
		endtry
	endif

	if l:mode == 0 && s:asyncrun_support != 0
		call g:AsyncRun_Job_Start(l:command)
	elseif l:mode <= 1 && has('quickfix')
		call s:MakeSave()
		let &l:makeprg = l:command
		exec "make!"
		call s:MakeRestore()
	elseif l:mode <= 3
		if s:asyncrun_windows != 0 && has('gui_running')
			let l:tmp = fnamemodify(tempname(), ':h') . '\asyncrun.cmd'
			let l:run = ['@echo off', l:command, 'pause']
			if v:version >= 700
				call writefile(l:run, l:tmp)
			else
				exe 'redir ! > '.fnameescape(l:tmp)
				silent echo "@echo off"
				silent echo l:cmd
				silent echo "pause"
				redir END
			endif
			let l:ccc = shellescape(l:tmp)
			if l:mode == 2
				silent exec '!start cmd /C '. l:ccc
			else
				silent exec '!start /b cmd /C '. l:ccc
			endif
			redraw
		else
			if l:mode == 2
				exec '!' . l:command
			else
				call system(l:command . ' &')
			endif
		endif
	elseif l:mode == 4
		exec '!'. l:command
	elseif l:mode == 5
		if s:asyncrun_windows != 0
		else
		endif
	endif

	if l:opts.cwd != ''
		exec cd fnameescape(l:opts.savecwd)
	endif
endfunc


"----------------------------------------------------------------------
" AsyncStop
"----------------------------------------------------------------------
function! s:AsyncStop(bang)
	if a:bang == ''
		call g:AsyncRun_Job_Stop('term')
	else
		call g:AsyncRun_Job_Stop('kill')
	endif
endfunc


"----------------------------------------------------------------------
" Commands
"----------------------------------------------------------------------
command! -bang -nargs=+ -complete=file AsyncRun 
	\ call s:AsyncRun('<bang>', '', <q-args>)

command! -bang -nargs=0 AsyncStop call s:AsyncStop('<bang>')



"----------------------------------------------------------------------
" Fast command to toggle quickfix
"----------------------------------------------------------------------
function! asyncrun#quickfix_toggle(size, ...)
	function! s:WindowCheck(mode)
		if getbufvar('%', '&buftype') == 'quickfix'
			let s:quickfix_open = 1
			return
		endif
		if a:mode == 0
			let w:quickfix_save = winsaveview()
		else
			call winrestview(w:quickfix_save)
		endif
	endfunc
	let s:quickfix_open = 0
	let l:winnr = winnr()			
	windo call s:WindowCheck(0)
	if a:0 == 0
		if s:quickfix_open == 0
			exec 'botright copen '. ((a:size > 0)? a:size : ' ')
			wincmd k
		else
			cclose
		endif
	elseif a:1 == 0
		if s:quickfix_open != 0
			cclose
		endif
	else
		if s:quickfix_open == 0
			exec 'botright copen '. ((a:size > 0)? a:size : ' ')
			wincmd k
		endif
	endif
	windo call s:WindowCheck(1)
	try
		silent exec ''.l:winnr.'wincmd w'
	catch /.*/
	endtry
endfunc




