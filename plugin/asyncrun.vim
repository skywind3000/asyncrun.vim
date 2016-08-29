" asyncrun.vim - Run shell commands in background and output to quickfix
"
" Maintainer: skywind3000 (at) gmail.com
" Last change: 2016.8.24
"
" Run shell command in background and output to quickfix:
"     :AsyncRun{!} [cmd] ...
"
"     when "!" is included, auto-scroll in quickfix will be disabled
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
"     $VIM_MODE      - Execute via 0:!, 1:makeprg, 2:system()
"     $VIM_COLUMNS   - How many columns in vim's screen
"     $VIM_LINES     - How many lines in vim's screen
"
" Stop the running job by signal TERM:
"     :AsyncStop{!}
"
"     when "!" is included, job will be stopped by signal KILL
"
" Settings:
"     g:asyncrun_exit - script will be executed after finished
"     g:asyncrun_bell - non-zero to ring a bell after finished
"     g:asyncrun_mode - 0:async(require vim 7.4.1829) 1:sync 2:shell
"
" Variables:
"     g:asyncrun_code - exit code
"     g:asyncrun_status - 'running', 'success' or 'failure'
"
" Requirements:
"     vim 7.4.1829 is minimal version to support async mode
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

if !exists('g:asyncrun_save')
	let g:asyncrun_save = 0
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
if v:version >= 800 || has('patch-7.4.1829')
	if has('job') && has('channel') && has('timers') && has('reltime') 
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

" save file
function! s:CheckSave()
	if bufname('%') == '' || getbufvar('%', '&modifiable') == 0
		return
	endif
	if g:asyncrun_save == 1
		silent exec "update"
	elseif g:asyncrun_save == 2
		silent exec "wa"
	endif
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

" check :cbottom available
if has('patch-7.4.1997')
	let s:async_quick = 1
endif

" scroll quickfix down
function! s:AsyncRun_Job_Scroll()
	if getbufvar('%', '&buftype') == 'quickfix'
		silent normal G
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

" invoked on timer or finished
function! s:AsyncRun_Job_Update(count)
	let l:count = 0
	while s:async_tail < s:async_head
		let l:text = s:async_output[s:async_tail]
		if l:text != '' 
			caddexpr l:text
		endif
		unlet s:async_output[s:async_tail]
		let s:async_tail += 1
		let l:count += 1
		if a:count > 0 && l:count >= a:count
			break
		endif
	endwhile
	if s:async_scroll != 0
		call s:AsyncRun_Job_AutoScroll()
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
	if a:text == ''
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
	else
		let s:async_state = or(s:async_state, 4)
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
	if s:async_code == 0
		caddexpr "[Finished in ".l:last." seconds]"
		let g:asyncrun_status = "success"
	else
		let l:text = 'with code '.s:async_code
		caddexpr "[Finished in ".l:last." seconds ".l:text."]"
		let g:asyncrun_status = "failure"
	endif
	let s:async_state = 0
	if s:async_scroll != 0
		call s:AsyncRun_Job_AutoScroll()
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

" start background build
function! g:AsyncRun_Job_Start(cmd)
	let l:running = 0
	let l:empty = 0
	if s:asyncrun_support == 0
		call s:NotSupport()
		return -1
	endif
	if exists('s:async_job')
		if job_status(s:async_job) == 'run'
			let l:running = 1
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
	elseif l:empty == 0
		let l:args = []
		let l:name = []
		if has('win32') || has('win64') || has('win16') || has('win95')
			let l:args = ['cmd.exe', '/C']
		else
			let l:args = ['/bin/sh', '-c']
		endif
		if type(a:cmd) == 1
			let l:args += [a:cmd]
			let l:name = a:cmd
		elseif type(a:cmd) == 3
			if s:asyncrun_windows == 0
				let l:temp = []
				for l:item in a:cmd
					if l:item != '|'
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
		if job_status(s:async_job) != 'fail'
			let s:async_output = {}
			let s:async_head = 0
			let s:async_tail = 0
			if type(a:cmd) == 1
				exec "cexpr \'[".fnameescape(l:name)."]\'"
			else
				let l:arguments = l:name
				exec "cexpr \'[\'.l:arguments.\']\'"
			endif
			let s:async_start = float2nr(reltimefloat(reltime()))
			if g:asyncrun_timer > 0
				let l:options = {'repeat':-1}
				let l:name = 'g:AsyncRun_Job_OnTimer'
				let s:async_timer = timer_start(1000, l:name, l:options)
			endif
			let s:async_state = 1
			let g:asyncrun_status = "running"
			redrawstatus!
		else
			unlet s:async_job
			call s:ErrorMsg("Background job start failed '".a:cmd."'")
			return -3
		endif
	else
		call s:ErrorMsg("empty arguments")
		return -4
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
		if job_status(s:async_job) == 'run'
			call job_stop(s:async_job, l:how)
		else
			return -2
		endif
	else
		return -3
	endif
	return 0
endfunc

" get job status
function! g:AsyncRun_Job_Status()
	if exists('s:async_job')
		return job_status(s:async_job)
	else
		return 'none'
	endif
endfunc


"----------------------------------------------------------------------
" AsyncRun
"----------------------------------------------------------------------
function! s:AsyncRun(bang, ...)
	let $VIM_FILEPATH = expand("%:p")
	let $VIM_FILENAME = expand("%:t")
	let $VIM_FILEDIR = expand("%:p:h")
	let $VIM_FILENOEXT = expand("%:t:r")
	let $VIM_FILEEXT = "." . expand("%:e")
	let $VIM_CWD = getcwd()
	let $VIM_RELDIR = expand("%:h:.")
	let $VIM_RELNAME = expand("%:p:.")
	let $VIM_CWORD = expand("<cword>")
	let $VIM_CFILE = expand("<cfile>")
	let $VIM_VERSION = ''.v:version
	let $VIM_GUI = '0'
	let $VIM_SVRNAME = v:servername
	let $VIM_COLUMNS = &columns
	let $VIM_LINES = &lines
	let l:text = ''
	if has("gui_running")
		let $VIM_GUI = '1'
	endif
	let l:cmd = []
	if a:0 == 0
		echohl ErrorMsg
		echom "E471: Argument required"
		echohl NONE
		return
	endif
	call s:CheckSave()
	if a:bang == '!'
		let s:async_scroll = 0
	else
		let s:async_scroll = 1
	endif
	for l:index in range(a:0)
		let l:item = a:{l:index + 1}
		let l:name = l:item
		if index(['%', '%<', '#', '#<'], l:item) >= 0
			let l:name = expand(l:item)
		elseif index(['%:', '#:'], l:item[:1]) >= 0
			let l:name = expand(l:item)
		elseif l:item == '<cwd>'
			let l:name = getcwd()
		elseif (l:item[0] == '<') && (l:item[-1:] == '>')
			let l:name = expand(l:item)
		endif
		let l:cmd += [l:name]
	endfor
	let l:part = []
	for l:item in l:cmd
		let l:part += [shellescape(l:item)]
	endfor
	let l:command = join(l:part, ' ')
	if g:asyncrun_mode == 0 && s:asyncrun_support != 0
		call g:AsyncRun_Job_Start(l:cmd)
	elseif g:asyncrun_mode <= 1 && has('quickfix')
		call s:MakeSave()
		let &l:makeprg = l:command
		exec "make!"
		call s:MakeRestore()
	else
		if s:asyncrun_windows != 0
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
			silent exec '!start cmd /C '. l:ccc
			redraw!
		else
			exec '!' . l:command
		endif
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
command! -bang -nargs=* AsyncRun call s:AsyncRun('<bang>', <f-args>)
command! -bang -nargs=0 AsyncStop call s:AsyncStop('<bang>')




