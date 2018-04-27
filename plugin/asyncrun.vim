" asyncrun.vim - Run shell commands in background and output to quickfix
"
" Maintainer: skywind3000 (at) gmail.com, 2016, 2017, 2018
" Homepage: http://www.vim.org/scripts/script.php?script_id=5431
"
" Last Modified: 2018/04/27 14:55
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
"     <root>  - Project root directory
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
"     $VIM_ROOT      - Project root directory
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
"     -save=0/1/2  - non-zero to save current/1 or all/2 modified buffer(s)
"     -program=?   - set to 'make' to use '&makeprg'
"     -raw=1       - use raw output (not match with the errorformat)
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
"     g:asyncrun_open - open quickfix window at given height
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
"     :AsyncRun make 
"     :AsyncRun -raw python $(VIM_FILEPATH)
"     :AsyncRun -cwd=<root> make
"     :AsyncRun! grep -R <cword> .
"     :noremap <F7> :AsyncRun gcc % -o %< <cr>
"
" Additional:
"     AsyncRun uses quickfix window to show job outputs, in order to 
"     see the outputs in realtime, you need open quickfix window at 
"     first by using :copen (see :help copen/cclose). Or use
"     ':call asyncrun#quickfix_toggle(8)' to open/close it rapidly.
"

" vim: set et fenc=utf-8 ff=unix sts=4 sw=4 ts=4 :


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

if !exists('g:asyncrun_hook')
	let g:asyncrun_hook = ''
endif

if !exists('g:asyncrun_last')
	let g:asyncrun_last = 0
endif

if !exists('g:asyncrun_timer')
	let g:asyncrun_timer = 25
endif

if !exists('g:asyncrun_code')
	let g:asyncrun_code = ''
endif

if !exists('g:asyncrun_status')
	let g:asyncrun_status = ''
endif

if !exists('g:asyncrun_encs')
	let g:asyncrun_encs = ''
endif

if !exists('g:asyncrun_trim')
	let g:asyncrun_trim = 0
endif

if !exists('g:asyncrun_text')
	let g:asyncrun_text = ''
endif

if !exists('g:asyncrun_local')
	let g:asyncrun_local = 1
endif

if !exists('g:asyncrun_auto')
	let g:asyncrun_auto = ''
endif

if !exists('g:asyncrun_shell')
	let g:asyncrun_shell = ''
endif

if !exists('g:asyncrun_shellflag')
	let g:asyncrun_shellflag = ''
endif

if !exists('g:asyncrun_ftrun')
	let g:asyncrun_ftrun = {}
endif

if !exists('g:asyncrun_silent')
	let g:asyncrun_silent = 1
endif

if !exists('g:asyncrun_skip')
	let g:asyncrun_skip = 0
endif

if !exists('g:asyncrun_info')
	let g:asyncrun_info = ''
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
	let msg = "required: +timers +channel +job and vim >= 7.4.1829"
	call s:ErrorMsg(msg)
endfunc

" run autocmd
function! s:AutoCmd(name)
	if has('autocmd') && ((g:asyncrun_skip / 2) % 2) == 0
		if g:asyncrun_silent
			exec 'silent doautocmd User AsyncRun'.a:name
		else
			exec 'doautocmd User AsyncRun'.a:name
		endif
	endif
endfunc

" change directory with right command
function! s:chdir(path)
	if has('nvim')
		let cmd = haslocaldir()? 'lcd' : (haslocaldir(-1, 0)? 'tcd' : 'cd')
	else
		let cmd = haslocaldir()? 'lcd' : 'cd'
	endif
	silent execute cmd . ' '. fnameescape(a:path)
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
if (v:version >= 800 || has('patch-7.4.1829')) && (!has('nvim'))
	if has('job') && has('channel') && has('timers')
		let s:asyncrun_support = 1
		let g:asyncrun_support = 1
	endif
elseif has('nvim')
	let s:asyncrun_support = 1
	let g:asyncrun_support = 1
endif


"----------------------------------------------------------------------
"- build in background
"----------------------------------------------------------------------
let s:async_nvim = has('nvim')? 1 : 0
let s:async_info = { 'text':"", 'post':'', 'postsave':'' }
let s:async_output = {}
let s:async_head = 0
let s:async_tail = 0
let s:async_code = 0
let s:async_state = 0
let s:async_start = 0
let s:async_debug = 0
let s:async_quick = 0
let s:async_scroll = 0
let s:async_congest = 0
let s:async_efm = &errorformat

" check :cbottom available ?
if s:async_nvim == 0
	let s:async_quick = (v:version >= 800 || has('patch-7.4.1997'))? 1 : 0
else
	let s:async_quick = has('nvim-0.2.0')? 1 : 0
endif

" check if we have vim 8.0.100
if s:async_nvim == 0 && v:version >= 800
	let s:async_congest = has('patch-8.0.100')? 1 : 0
	let s:async_congest = 0
endif

" quickfix window cursor check
function! s:AsyncRun_Job_Cursor()
	if &buftype == 'quickfix'
		if line('.') != line('$')
			let s:async_check_last = 0
		endif
	endif
endfunc

" find quickfix window and scroll to the bottom then return last window
function! s:AsyncRun_Job_AutoScroll()
	if s:async_quick == 0
		if &buftype == 'quickfix'
			silent exec 'normal! G'
		endif
	else
		cbottom
	endif
endfunc

" check if quickfix window can scroll now
function! s:AsyncRun_Job_CheckScroll()
	if g:asyncrun_last == 0
		if &buftype == 'quickfix'
			return (line('.') == line('$'))
		else
			return 1
		endif
	elseif g:asyncrun_last == 1
		let s:async_check_last = 1
		let l:winnr = winnr()
		" Execute AsyncRun_Job_Cursor() in quickfix
		let l:quickfixwinnr = bufwinnr("[Quickfix List]")
		if l:quickfixwinnr != -1  " -1 mean the buffer has no window or do not exists
			noautocmd exec '' . l:quickfixwinnr . 'windo call s:AsyncRun_Job_Cursor()'
		endif
		noautocmd silent! exec ''.l:winnr.'wincmd w'
		return s:async_check_last
	elseif g:asyncrun_last == 2
		return 1
	else
		if &buftype == 'quickfix'
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
	let l:empty = [{'text':''}]
	let l:check = s:AsyncRun_Job_CheckScroll()
	let l:efm1 = &g:efm
	let l:efm2 = &l:efm
	if g:asyncrun_encs == &encoding
		let l:iconv = 0 
	endif
	if &g:efm != s:async_efm && g:asyncrun_local != 0
		let &l:efm = s:async_efm
		let &g:efm = s:async_efm
	endif
	let l:raw = (s:async_efm == '')? 1 : 0
	if s:async_info.raw == 1
		let l:raw = 1
	endif
	while s:async_tail < s:async_head
		let l:text = s:async_output[s:async_tail]
		if l:iconv != 0
			try
				let l:text = iconv(l:text, g:asyncrun_encs, &encoding)
			catch /.*/
			endtry
		endif
		let l:text = substitute(l:text, '\r$', '', 'g')
		if l:text != ''
			if l:raw == 0
				if and(g:asyncrun_skip, 1) == 0
					caddexpr l:text
				else
					noautocmd caddexpr l:text
				endif
			else
				call setqflist([{'text':l:text}], 'a')
			endif
		elseif g:asyncrun_trim == 0
			call setqflist(l:empty, 'a')
		endif
		let l:total += 1
		unlet s:async_output[s:async_tail]
		let s:async_tail += 1
		let l:count += 1
		if a:count > 0 && l:count >= a:count
			break
		endif
	endwhile
	if g:asyncrun_local != 0
		if l:efm1 != &g:efm | let &g:efm = l:efm1 | endif
		if l:efm2 != &l:efm | let &l:efm = l:efm2 | endif
	endif
	if s:async_scroll != 0 && l:total > 0 && l:check != 0
		call s:AsyncRun_Job_AutoScroll()
	endif
	return l:count
endfunc

" trigger autocmd
function! s:AsyncRun_Job_AutoCmd(mode, auto)
	if !has('autocmd') | return | endif
	let name = (a:auto == '')? g:asyncrun_auto : a:auto
	if name !~ '^\w\+$' || name == 'NONE' || name == '<NONE>'
		return
	endif
	if ((g:asyncrun_skip / 4) % 2) != 0
		return 0
	endif
	if a:mode == 0
		if g:asyncrun_silent
			silent exec 'doautocmd QuickFixCmdPre '. name
		else
			exec 'doautocmd QuickFixCmdPre '. name
		endif
	else
		if g:asyncrun_silent
			silent exec 'doautocmd QuickFixCmdPost '. name
		else
			exec 'doautocmd QuickFixCmdPost '. name
		endif
	endif
endfunc

" invoked on timer
function! g:AsyncRun_Job_OnTimer(id)
	let limit = (g:asyncrun_timer < 10)? 10 : g:asyncrun_timer
	" check on command line window
	if &ft == 'vim' && &buftype == 'nofile'
		return
	endif
	if s:async_nvim == 0
		if exists('s:async_job')
			call job_status(s:async_job)
		endif
	endif
	call s:AsyncRun_Job_Update(limit)
	if and(s:async_state, 7) == 7
		if s:async_head == s:async_tail
			call s:AsyncRun_Job_OnFinish()
		endif
	endif
endfunc

" invoked on "callback" when job output
function! s:AsyncRun_Job_OnCallback(channel, text)
	if !exists("s:async_job")
		return
	endif
	if type(a:text) != 1
		return
	endif
	let s:async_output[s:async_head] = a:text
	let s:async_head += 1
	if s:async_congest != 0 
		call s:AsyncRun_Job_Update(-1)
	endif
endfunc

" because exit_cb and close_cb are disorder, we need OnFinish to guarantee
" both of then have already invoked
function! s:AsyncRun_Job_OnFinish()
	" caddexpr '(OnFinish): '.a:what.' '.s:async_state
	if s:async_state == 0
		return -1
	endif
	if exists('s:async_job')
		unlet s:async_job
	endif
	if exists('s:async_timer')
		call timer_stop(s:async_timer)
		unlet s:async_timer
	endif
	call s:AsyncRun_Job_Update(-1)
	let l:current = localtime()
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
	endif
	let g:asyncrun_code = s:async_code
	if g:asyncrun_bell != 0
		exec "norm! \<esc>"
	endif
	if s:async_info.post != ''
		exec s:async_info.post
		let s:async_info.post = ''
	endif
	if g:asyncrun_exit != ""
		exec g:asyncrun_exit
	endif
	call s:AsyncRun_Job_AutoCmd(1, s:async_info.auto)
	call s:AutoCmd('Stop')
	redrawstatus!
	redraw
endfunc

" invoked on "close_cb" when channel closed
function! s:AsyncRun_Job_OnClose(channel)
	" caddexpr "[close]"
	let s:async_debug = 1
	let l:limit = 128
	let l:options = {'timeout':0}
	while ch_status(a:channel) == 'buffered'
		let l:text = ch_read(a:channel, l:options)
		if l:text == '' " important when child process is killed
			let l:limit -= 1
			if l:limit < 0 | break | endif
		else
			call s:AsyncRun_Job_OnCallback(a:channel, l:text)
		endif
	endwhile
	let s:async_debug = 0
	if exists('s:async_job')
		call job_status(s:async_job)
	endif
	let s:async_state = or(s:async_state, 4)
endfunc

" invoked on "exit_cb" when job exited
function! s:AsyncRun_Job_OnExit(job, message)
	" caddexpr "[exit]: ".a:message." ".type(a:message)
	let s:async_code = a:message
	let s:async_state = or(s:async_state, 2)
endfunc

" invoked on neovim when stderr/stdout/exit
function! s:AsyncRun_Job_NeoVim(job_id, data, event)
	if a:event == 'stdout' || a:event == 'stderr'
		let l:index = 0
		let l:size = len(a:data)
		let cache = (a:event == 'stdout')? s:neovim_stdout : s:neovim_stderr
		while l:index < l:size
			let cache .= a:data[l:index]
			if l:index + 1 < l:size
				let s:async_output[s:async_head] = cache
				let s:async_head += 1
				let cache = ''
			endif
			let l:index += 1
		endwhile
		if a:event == 'stdout'
			let s:neovim_stdout = cache
		else
			let s:neovim_stderr = cache
		endif
	elseif a:event == 'exit'
		if type(a:data) == type(1)
			let s:async_code = a:data
		endif
		if s:neovim_stdout != ''
			let s:async_output[s:async_head] = s:neovim_stdout
			let s:async_head += 1
		endif
		if s:neovim_stderr != ''
			let s:async_output[s:async_head] = s:neovim_stderr
			let s:async_head += 1
		endif
		let s:async_state = or(s:async_state, 6)
	endif
endfunc


"----------------------------------------------------------------------
" AsyncRun Interface
"----------------------------------------------------------------------

" start background build
function! s:AsyncRun_Job_Start(cmd)
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
	if g:asyncrun_shell == ''
		if !executable(&shell)
			let l:text = "invalid config in &shell and &shellcmdflag"
			call s:ErrorMsg(l:text . ", &shell must be an executable.")
			return -4
		endif
		let l:args = [&shell, &shellcmdflag]
	else
		if !executable(g:asyncrun_shell)
			let l:text = "invalid config in g:asyncrun_shell"
			call s:ErrorMsg(l:text . ", it must be an executable.")
			return -4
		endif
		let l:args = [g:asyncrun_shell, g:asyncrun_shellflag]
	endif
	let l:name = []
	if type(a:cmd) == 1
		let l:name = a:cmd
		if s:asyncrun_windows == 0
			let l:args += [a:cmd]
		else
			let l:tmp = fnamemodify(tempname(), ':h') . '\asyncrun.cmd'
			let l:run = ['@echo off', a:cmd]
			call writefile(l:run, l:tmp)
			let l:args += [l:tmp]
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
	let s:async_state = 0
	let s:async_output = {}
	let s:async_head = 0
	let s:async_tail = 0
	let s:async_efm = &errorformat
	let s:async_info.post = s:async_info.postsave
	let s:async_info.auto = s:async_info.autosave
	let s:async_info.postsave = ''
	let s:async_info.autosave = ''
	let g:asyncrun_text = s:async_info.text
	call s:AutoCmd('Pre')
	if s:async_nvim == 0
		let l:options = {}
		let l:options['callback'] = function('s:AsyncRun_Job_OnCallback')
		let l:options['close_cb'] = function('s:AsyncRun_Job_OnClose')
		let l:options['exit_cb'] = function('s:AsyncRun_Job_OnExit')
		let l:options['out_io'] = 'pipe'
		let l:options['err_io'] = 'out'
		let l:options['in_io'] = 'null'
		let l:options['out_mode'] = 'nl'
		let l:options['err_mode'] = 'nl'
		let l:options['stoponexit'] = 'term'
		if g:asyncrun_stop != ''
			let l:options['stoponexit'] = g:asyncrun_stop
		endif
		if s:async_info.range > 0
			let l:options['in_io'] = 'buffer'
			let l:options['in_mode'] = 'nl'
			let l:options['in_buf'] = s:async_info.range_buf
			let l:options['in_top'] = s:async_info.range_top
			let l:options['in_bot'] = s:async_info.range_bot
		endif
		let s:async_job = job_start(l:args, l:options)
		let l:success = (job_status(s:async_job) != 'fail')? 1 : 0
	else
		let l:callbacks = {'shell': 'AsyncRun'}
		let l:callbacks['on_stdout'] = function('s:AsyncRun_Job_NeoVim')
		let l:callbacks['on_stderr'] = function('s:AsyncRun_Job_NeoVim')
		let l:callbacks['on_exit'] = function('s:AsyncRun_Job_NeoVim')
		let s:neovim_stdout = ''
		let s:neovim_stderr = ''
		let s:async_job = jobstart(l:args, l:callbacks)
		let l:success = (s:async_job > 0)? 1 : 0
		if l:success != 0
			if s:async_info.range > 0
				let l:top = s:async_info.range_top
				let l:bot = s:async_info.range_bot
				let l:lines = getline(l:top, l:bot)
				if exists('*chansend')
					call chansend(s:async_job, l:lines)
				elseif exists('*jobsend')
					call jobsend(s:async_job, l:lines)
				endif
			endif
			if exists('*chanclose')
				call chanclose(s:async_job, 'stdin')
			elseif exists('*jobclose')
				call jobclose(s:async_job, 'stdin')
			endif
		endif
	endif
	if l:success != 0
		let s:async_state = or(s:async_state, 1)
		let g:asyncrun_status = "running"
		let s:async_start = localtime()
		let l:arguments = "[".l:name."]"
		let l:title = ':AsyncRun '.l:name
		if s:async_nvim == 0
			if v:version >= 800 || has('patch-7.4.2210')
				call setqflist([], ' ', {'title':l:title})
			else
				call setqflist([], ' ')
			endif
		else
			call setqflist([], ' ', l:title)
		endif
		call setqflist([{'text':l:arguments}], 'a')
		let l:name = 'g:AsyncRun_Job_OnTimer'
		let s:async_timer = timer_start(100, l:name, {'repeat':-1})
		call s:AsyncRun_Job_AutoCmd(0, s:async_info.auto)
		call s:AutoCmd('Start')
		redrawstatus!
	else
		unlet s:async_job
		call s:ErrorMsg("Background job start failed '".a:cmd."'")
		redrawstatus!
		return -5
	endif
	return 0
endfunc


" stop background job
function! s:AsyncRun_Job_Stop(how)
	let l:how = (a:how != '')? a:how : 'term'
	if s:asyncrun_support == 0
		call s:NotSupport()
		return -1
	endif
	while s:async_head > s:async_tail
		let s:async_head -= 1
		unlet s:async_output[s:async_head]
	endwhile
	if exists('s:async_job')
		if s:async_nvim == 0
			if job_status(s:async_job) == 'run'
				if job_stop(s:async_job, l:how)
					return 0
				else
					return -2
				endif
			else
				return -3
			endif
		else
			if s:async_job > 0
				silent! call jobstop(s:async_job)
			endif
		endif
	else
		return -4
	endif
	return 0
endfunc


" get job status
function! s:AsyncRun_Job_Status()
	if exists('s:async_job')
		if s:async_nvim == 0
			return job_status(s:async_job)
		else
			return 'run'
		endif
	else
		return 'none'
	endif
endfunc



"----------------------------------------------------------------------
" Utilities
"----------------------------------------------------------------------

" Replace string
function! s:StringReplace(text, old, new)
	let l:data = split(a:text, a:old, 1)
	return join(l:data, a:new)
endfunc

" Trim leading and tailing spaces
function! s:StringStrip(text)
	return substitute(a:text, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunc

" extract options from command
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
		let opts[opt] = substitute(val, '\\\(\s\)', '\1', 'g')
		let cmd = substitute(cmd, '^-\w\+\%(=\%(\\.\|\S\)*\)\=\s*', '', '')
	endwhile
	let cmd = substitute(cmd, '^\s*\(.\{-}\)\s*$', '\1', '')
	let cmd = substitute(cmd, '^@\s*', '', '')
	let opts.cwd = get(opts, 'cwd', '')
	let opts.mode = get(opts, 'mode', '')
	let opts.save = get(opts, 'save', '')
	let opts.program = get(opts, 'program', '')
	let opts.post = get(opts, 'post', '')
	let opts.text = get(opts, 'text', '')
	let opts.auto = get(opts, 'auto', '')
	let opts.raw = get(opts, 'raw', '')
	if 0
		echom 'cwd:'. opts.cwd
		echom 'mode:'. opts.mode
		echom 'save:'. opts.save
		echom 'program:'. opts.program
		echom 'command:'. cmd
	endif
	return [cmd, opts]
endfunc

" write script to a file and return filename
function! s:ScriptWrite(command, pause)
	let l:tmp = fnamemodify(tempname(), ':h') . '\asyncrun.cmd'
	if s:asyncrun_windows != 0
		let l:line = ['@echo off', 'call '.a:command]
		if a:pause != 0
			let l:line += ['pause']
		endif
	else
		let l:line = ['#! '.&shell]
		let l:line += [a:command]
		if a:pause != 0
			let l:line += ['read -n1 -rsp "press any key to confinue ..."']
		endif
		let l:tmp = tempname()
	endif
	if v:version >= 700
		call writefile(l:line, l:tmp)
	else
		exe 'redir ! > '.fnameescape(l:tmp)
		for l:index in range(len(l:line))
			silent echo l:line[l:index]
		endfor
		redir END
	endif
	return l:tmp
endfunc

" full file name
function! asyncrun#fullname(f)
	let f = a:f
	if f =~ "'."
		try
			redir => m
			silent exe ':marks' f[1]
			redir END
			let f = split(split(m, '\n')[-1])[-1]
			let f = filereadable(f)? f : ''
		catch
			let f = '%'
		endtry
	endif
	let f = (f != '%')? f : expand('%')
	let f = fnamemodify(f, ':p')
	if s:asyncrun_windows
		let f = substitute(f, "\\", '/', 'g')
	endif
	if len(f) > 1
		let size = len(f)
		if f[size - 1] == '/'
			let f = strpart(f, 0, size - 1)
		endif
	endif
	return f
endfunc

" join two path
function! s:path_join(home, name)
    let l:size = strlen(a:home)
    if l:size == 0 | return a:name | endif
    let l:last = strpart(a:home, l:size - 1, 1)
    if has("win32") || has("win64") || has("win16") || has('win95')
		let l:first = strpart(a:name, 0, 1)
		if l:first == "/" || l:first == "\\"
			let head = strpart(a:home, 1, 2)
			if index([":\\", ":/"], head) >= 0
				return strpart(a:home, 0, 2) . a:name
			endif
			return a:name
		elseif index([":\\", ":/"], strpart(a:name, 1, 2)) >= 0
			return a:name
		endif
        if l:last == "/" || l:last == "\\"
            return a:home . a:name
        else
            return a:home . '/' . a:name
        endif
    else
		if strpart(a:name, 0, 1) == "/"
			return a:name
		endif
        if l:last == "/"
            return a:home . a:name
        else
            return a:home . '/' . a:name
        endif
    endif
endfunc

" find project root
function! s:find_root(path, markers)
    function! s:guess_root(filename, markers)
        let fullname = asyncrun#fullname(a:filename)
        if exists('b:asyncrun_root')
			return b:asyncrun_root
        endif
        if fullname =~ '^fugitive:/'
            if exists('b:git_dir')
                return fnamemodify(b:git_dir, ':h')
            endif
            return '' " skip any fugitive buffers early
        endif
		let pivot = fullname
		if !isdirectory(pivot)
			let pivot = fnamemodify(pivot, ':h')
		endif
		while 1
			let prev = pivot
			for marker in a:markers
				let newname = s:path_join(pivot, marker)
				if filereadable(newname)
					return pivot
				elseif isdirectory(newname)
					return pivot
				endif
			endfor
			let pivot = fnamemodify(pivot, ':h')
			if pivot == prev
				break
			endif
		endwhile
        return ''
	endfunc
	let root = s:guess_root(a:path, a:markers)
	if len(root)
		return asyncrun#fullname(root)
	endif
	" Not found: return parent directory of current file / file itself.
	let fullname = asyncrun#fullname(a:path)
	if isdirectory(fullname)
		return fullname
	endif
	return asyncrun#fullname(fnamemodify(fullname, ':h'))
endfunc

" get project root
function! asyncrun#get_root(path, ...)
	let markers = ['.project', '.git', '.hg', '.svn', '.root']
	if exists('g:asyncrun_rootmarks')
		let markers = g:asyncrun_rootmarks
	endif
	if a:0 > 0
		let markers = a:1
	endif
	let l:hr = s:find_root(a:path, markers)
	if s:asyncrun_windows
		let l:hr = s:StringReplace(l:hr, '/', "\\")
	endif
	return l:hr
endfunc

function! asyncrun#path_join(home, name)
	return s:path_join(a:home, a:name)
endfunc



"----------------------------------------------------------------------
" run command
"----------------------------------------------------------------------
function! s:run(opts)
	let l:opts = a:opts
	let l:command = a:opts.cmd
	let l:retval = ''
	let l:mode = g:asyncrun_mode

	if a:opts.mode != ''
		let l:mode = a:opts.mode
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
		let s:async_program_cmd = ''
		silent exec 'AsyncRun -program=parse @ '. l:command
		let l:command = s:async_program_cmd
	endif

	if l:command =~ '^\s*$'
		echohl ErrorMsg
		echom "E471: Command required"
		echohl NONE
		return
	endif

	let l:wrapper = get(g:, 'asyncrun_wrapper', '')

	if l:wrapper != ''
		let l:command = l:wrapper . ' ' . l:command
	endif

	if l:mode >= 10 
		let l:opts.cmd = l:command
		if g:asyncrun_hook != ''
			exec 'call '. g:asyncrun_hook .'(l:opts)'
		endif
		return
	endif

	if l:mode == 0 && s:asyncrun_support != 0
		let s:async_info.postsave = opts.post
		let s:async_info.autosave = opts.auto
		let s:async_info.text = opts.text
		let s:async_info.raw = opts.raw
		let s:async_info.range = opts.range
		let s:async_info.range_top = opts.range_top
		let s:async_info.range_bot = opts.range_bot
		let s:async_info.range_buf = opts.range_buf
		if s:AsyncRun_Job_Start(l:command) != 0
			call s:AutoCmd('Error')
		endif
	elseif l:mode <= 1 && has('quickfix')
		call s:AutoCmd('Pre')
		call s:AutoCmd('Start')
		let l:makesave = &l:makeprg
		let l:script = s:ScriptWrite(l:command, 0)
		if s:asyncrun_windows != 0
			let &l:makeprg = shellescape(l:script)
		else
			let &l:makeprg = 'source '. shellescape(l:script)
		endif
		if has('autocmd')
			call s:AsyncRun_Job_AutoCmd(0, opts.auto)
			exec "noautocmd make!"
			call s:AsyncRun_Job_AutoCmd(1, opts.auto)
		else
			exec "make!"
		endif
		let &l:makeprg = l:makesave
		if s:asyncrun_windows == 0
			try | call delete(l:script) | catch | endtry
		endif
		let g:asyncrun_text = opts.text
		if opts.post != ''
			exec opts.post
		endif
		call s:AutoCmd('Stop')
	elseif l:mode <= 2
		call s:AutoCmd('Pre')
		call s:AutoCmd('Start')
		exec '!'. escape(l:command, '%#')
		let g:asyncrun_text = opts.text
		if opts.post != ''
			exec opts.post
		endif
		call s:AutoCmd('Stop')
	elseif l:mode == 3
		if s:asyncrun_windows != 0 && has('python')
			let l:script = s:ScriptWrite(l:command, 0)
			py import subprocess, vim
			py argv = {'args': vim.eval('l:script'), 'shell': True}
			py argv['stdout'] = subprocess.PIPE
			py argv['stderr'] = subprocess.STDOUT
			py p = subprocess.Popen(**argv)
			py text = p.stdout.read()
			py p.stdout.close()
			py c = p.wait()
			if has('patch-7.4.145')
				let l:retval = pyeval('text')
				let g:asyncrun_shell_error = pyeval('c')
			else
				py text = text.replace('\\', '\\\\').replace('"', '\\"')
				py text = text.replace('\n', '\\n').replace('\r', '\\r')
				py vim.command('let l:retval = "%s"'%text)
				py vim.command('let g:asyncrun_shell_error = %d'%c)
			endif
		elseif s:asyncrun_windows != 0 && has('python3')
			let l:script = s:ScriptWrite(l:command, 0)
			py3 import subprocess, vim
			py3 argv = {'args': vim.eval('l:script'), 'shell': True}
			py3 argv['stdout'] = subprocess.PIPE
			py3 argv['stderr'] = subprocess.STDOUT
			py3 p = subprocess.Popen(**argv)
			py3 text = p.stdout.read()
			py3 p.stdout.close()
			py3 c = p.wait()
			if has('patch-7.4.145')
				let l:retval = py3eval('text')
				let g:asyncrun_shell_error = py3eval('c')
			else
				py3 text = text.replace('\\', '\\\\').replace('"', '\\"')
				py3 text = text.replace('\n', '\\n').replace('\r', '\\r')
				py3 vim.command('let l:retval = "%s"'%text)
				py3 vim.command('let g:asyncrun_shell_error = %d'%c)
			endif
		else
			let l:retval = system(l:command)
			let g:asyncrun_shell_error = v:shell_error
		endif
		let g:asyncrun_text = opts.text
		if opts.post != ''
			exec opts.post
		endif
	elseif l:mode <= 5
		if s:asyncrun_windows != 0 && (has('gui_running') || has('nvim'))
			if l:mode == 4
				let l:ccc = shellescape(s:ScriptWrite(l:command, 1))
				silent exec '!start cmd /C '. l:ccc
			else
				let l:ccc = shellescape(s:ScriptWrite(l:command, 0))
				silent exec '!start /b cmd /C '. l:ccc
			endif
			redraw
		else
			let l:ccc = shellescape(s:ScriptWrite(l:command, 0))
			if l:mode == 4
				exec '!' . escape(l:command, '%#')
			else
				call system(l:command . ' &')
			endif
		endif
		let g:asyncrun_text = opts.text
		if opts.post != ''
			exec opts.post
		endif
	endif

	return l:retval
endfunc


"----------------------------------------------------------------------
" asyncrun - run
"----------------------------------------------------------------------
function! asyncrun#run(bang, opts, args, ...)
	let l:macros = {}
	let l:macros['VIM_FILEPATH'] = expand("%:p")
	let l:macros['VIM_FILENAME'] = expand("%:t")
	let l:macros['VIM_FILEDIR'] = expand("%:p:h")
	let l:macros['VIM_FILENOEXT'] = expand("%:t:r")
	let l:macros['VIM_FILEEXT'] = "." . expand("%:e")
	let l:macros['VIM_CWD'] = getcwd()
	let l:macros['VIM_RELDIR'] = expand("%:h:.")
	let l:macros['VIM_RELNAME'] = expand("%:p:.")
	let l:macros['VIM_CWORD'] = expand("<cword>")
	let l:macros['VIM_CFILE'] = expand("<cfile>")
	let l:macros['VIM_VERSION'] = ''.v:version
	let l:macros['VIM_SVRNAME'] = v:servername
	let l:macros['VIM_COLUMNS'] = ''.&columns
	let l:macros['VIM_LINES'] = ''.&lines
	let l:macros['VIM_GUI'] = has('gui_running')? 1 : 0
	let l:macros['VIM_ROOT'] = asyncrun#get_root('%')
	let l:macros['<cwd>'] = l:macros['VIM_CWD']
	let l:macros['<root>'] = l:macros['VIM_ROOT']
	let l:retval = ''

	" extract options
	let [l:command, l:opts] = s:ExtractOpt(s:StringStrip(a:args))
	
	" combine options
	if type(a:opts) == type({})
		for [l:key, l:val] in items(a:opts)
			let l:opts[l:key] = l:val
		endfor
	endif

	" parse makeprg/grepprg and return
	if l:opts.program == 'parse'
		let s:async_program_cmd = l:command
		return s:async_program_cmd
	endif

	" update info (current running command text)
	let g:asyncrun_info = a:args

	" setup range
	let l:opts.range = 0
	let l:opts.range_top = 0
	let l:opts.range_bot = 0
	let l:opts.range_buf = 0

	if a:0 >= 3
		if a:1 > 0 && a:2 <= a:3
			let l:opts.range = 2
			let l:opts.range_top = a:2
			let l:opts.range_bot = a:3
			let l:opts.range_buf = bufnr('%')
		endif
	endif

	" check cwd
	if l:opts.cwd != ''
		for [l:key, l:val] in items(l:macros)
			let l:replace = (l:key[0] != '<')? '$('.l:key.')' : l:key
			let l:opts.cwd = s:StringReplace(l:opts.cwd, l:replace, l:val)
		endfor
		let l:opts.savecwd = getcwd()
		silent! call s:chdir(l:opts.cwd)
		let l:macros['VIM_CWD'] = getcwd()
		let l:macros['VIM_RELDIR'] = expand("%:h:.")
		let l:macros['VIM_RELNAME'] = expand("%:p:.")
		let l:macros['VIM_CFILE'] = expand("<cfile>")
		let l:macros['<cwd>'] = l:macros['VIM_CWD']
	endif

	" replace macros and setup environment variables
	for [l:key, l:val] in items(l:macros)
		let l:replace = (l:key[0] != '<')? '$('.l:key.')' : l:key
		if l:key[0] != '<'
			exec 'let $'.l:key.' = l:val'
		endif
		let l:command = s:StringReplace(l:command, l:replace, l:val)
		let l:opts.text = s:StringReplace(l:opts.text, l:replace, l:val)
	endfor

	" config
	let l:opts.cmd = l:command
	let l:opts.macros = l:macros
	let l:opts.mode = get(l:opts, 'mode', g:asyncrun_mode)
	let s:async_scroll = (a:bang == '!')? 0 : 1
	
	" check if need to save
	let l:save = get(l:opts, 'save', '')

	if l:save == '1'
		silent! update 
	elseif l:save
		silent! wall
	endif

	" run command
	let l:retval = s:run(l:opts)

	" restore cwd
	if l:opts.cwd != ''
		silent! call s:chdir(l:opts.savecwd)
	endif

	return l:retval
endfunc


"----------------------------------------------------------------------
" asyncrun - stop
"----------------------------------------------------------------------
function! asyncrun#stop(bang)
	if a:bang == ''
		return s:AsyncRun_Job_Stop('term')
	else
		return s:AsyncRun_Job_Stop('kill')
	endif
endfunc



"----------------------------------------------------------------------
" asyncrun - status
"----------------------------------------------------------------------
function! asyncrun#status()
	return s:AsyncRun_Job_Status()
endfunc



"----------------------------------------------------------------------
" asyncrun -version
"----------------------------------------------------------------------
function! asyncrun#version()
	return '2.0.0'
endfunc


"----------------------------------------------------------------------
" Commands
"----------------------------------------------------------------------
command! -bang -nargs=+ -range=0 -complete=file AsyncRun 
	\ call asyncrun#run('<bang>', '', <q-args>, <count>, <line1>, <line2>)

command! -bang -nargs=0 AsyncStop call asyncrun#stop('<bang>')



"----------------------------------------------------------------------
" Fast command to toggle quickfix
"----------------------------------------------------------------------
function! asyncrun#quickfix_toggle(size, ...)
	let l:mode = (a:0 == 0)? 2 : (a:1)
	function! s:WindowCheck(mode)
		if &buftype == 'quickfix'
			let s:quickfix_open = 1
			return
		endif
		if a:mode == 0
			let w:quickfix_save = winsaveview()
		else
			if exists('w:quickfix_save')
				call winrestview(w:quickfix_save)
				unlet w:quickfix_save
			endif
		endif
	endfunc
	let s:quickfix_open = 0
	let l:winnr = winnr()			
	noautocmd windo call s:WindowCheck(0)
	noautocmd silent! exec ''.l:winnr.'wincmd w'
	if l:mode == 0
		if s:quickfix_open != 0
			silent! cclose
		endif
	elseif l:mode == 1
		if s:quickfix_open == 0
			exec 'botright copen '. ((a:size > 0)? a:size : ' ')
			wincmd k
		endif
	elseif l:mode == 2
		if s:quickfix_open == 0
			exec 'botright copen '. ((a:size > 0)? a:size : ' ')
			wincmd k
		else
			silent! cclose
		endif
	endif
	noautocmd windo call s:WindowCheck(1)
	noautocmd silent! exec ''.l:winnr.'wincmd w'
endfunc



"----------------------------------------------------------------------
" debug
"----------------------------------------------------------------------
function! s:execute(mode)
	if a:mode == 0		" Execute current filename
		let l:fname = shellescape(expand("%:p"))
		if (has('gui_running') || has('nvim')) && (s:asyncrun_windows != 0)
			if !has('nvim')
				silent exec '!start cmd /C '. l:fname .' & pause'
			else
				call asyncrun#run('', {'mode':4}, l:fname)
			endif
		else
			exec '!' . l:fname
		endif
	elseif a:mode == 1	" Execute current filename without extname
		let l:fname = shellescape(expand("%:p:r"))
		if (has('gui_running') || has('nvim')) && (s:asyncrun_windows != 0)
			if !has('nvim')
				silent exec '!start cmd /C '. l:fname .' & pause'
			else
				call asyncrun#run('', {'mode':4}, l:fname)
			endif
		else
			exec '!' . l:fname
		endif
	elseif a:mode == 2
		let l:fname = shellescape(expand("%"))
		if (has('gui_running') || has('nvim')) && (s:asyncrun_windows != 0)
			if !has('nvim')
				silent exec '!start cmd /C emake -e '. l:fname .' & pause'
			else
				call asyncrun#run('', {'mode':4}, "emake -e ". l:fname)
			endif
		else
			exec '!emake -e ' . l:fname
		endif
	elseif a:mode == 3
		let l:makeprg = get(g:, 'asyncrun_mp_run', '')
		let l:fname = shellescape(expand("%"))
		if l:makeprg == ''
			if executable('make')
				let l:makeprg = 'make run -f'
			elseif executable('mingw32-make')
				let l:makeprg = 'mingw32-make run -f'
			elseif executable('mingw64-make')
				let l:makeprg = 'mingw64-make run -f'
			else
				redraw 
				call s:ErrorMsg('cannot find make/mingw32-make')
				return
			endif
		endif
		if (has('gui_running') || has('nvim')) && (s:asyncrun_windows != 0)
			let l:cmdline = l:makeprg. ' '.l:fname 
			if !has('nvim')
				silent exec '!start cmd /C '.l:cmdline . ' & pause'
			else
				call asyncrun#run('', {'mode':4}, l:cmdline)
			endif
		else
			exec '!'.l:makeprg.' '.l:fname
		endif
	elseif a:mode == 4
		let ext = tolower(expand("%:e"))
		if index(['c', 'cc', 'cpp', 'h', 'mak', 'em', 'emk', 'm'], ext) >= 0
			call s:execute(2)
		elseif index(['mm', 'py', 'pyw', 'cxx', 'java', 'pyx'], ext) >= 0
			call s:execute(2)
		elseif index(['c', 'cpp', 'python', 'java', 'go'], &ft) >= 0
			call s:execute(2)
		elseif index(['javascript'], &ft) >= 0
			call s:execute(2)
		else
			call s:execute(3)
		endif
	endif
endfunc


"----------------------------------------------------------------------
" asyncrun - execute
"----------------------------------------------------------------------
function! asyncrun#execute(mode, cwd, save)
	let savecwd = getcwd()
	let l:ext = tolower(expand("%:e"))
	if a:save | silent! wall | endif
	if bufname('%') == '' | return | endif
	let l:dest = ''
	if a:cwd == 1
		let l:dest = expand('%:p:h')
	elseif a:cwd == 2
		let l:dest = asyncrun#get_root('%')
	endif
	if l:dest != ''
		silent! call s:chdir(l:dest)
	endif
	if a:mode == '0' || a:mode == 'filename' || a:mode == 'file'
		call s:execute(0)
	elseif a:mode == '1' || a:mode == 'main' || a:mode == 'exe'
		call s:execute(1)
	elseif a:mode == '2' || a:mode == 'emake'
		call s:execute(2)
	elseif a:mode == '3' || a:mode == 'make'
		call s:execute(3)
	elseif a:mode == '4' || a:mode == 'auto' || a:mode == 'automake'
		call s:execute(4)
	elseif &ft == 'cpp' || &ft == 'c'
		call s:execute(1)
	elseif index(['c', 'cpp', 'cc', 'm', 'mm', 'cxx'], l:ext) >= 0
		call s:execute(1)
	elseif index(['h', 'hh', 'hpp'], l:ext) >= 0
		call s:execute(1)
	elseif index(['mak', 'emake', 'em', 'emk'], l:ext) >= 0
		call s:execute(2)
	elseif l:ext == 'mk'
		call s:execute(3)
	elseif &ft == 'vim'
		exec 'source '. fnameescape(expand('%'))
	elseif (has('gui_running') || has('nvim')) && s:asyncrun_windows != 0
		let cmd = get(g:asyncrun_ftrun, &ft, '')
		let fname = shellescape(expand('%'))
		if cmd == ''
			if &ft == 'python'
				let cmd = 'python'
			elseif &ft == 'javascript'
				let cmd = 'node'
			elseif &ft == 'sh'
				let cmd = 'sh'
			elseif &ft == 'lua'
				let cmd = 'lua'
			elseif &ft == 'perl'
				let cmd = 'perl'
			elseif &ft == 'ruby'
				let cmd = 'ruby'
			elseif &ft == 'php'
				let cmd = 'php'
			elseif l:ext == 'vbs'
				let l:cmd = 'cscript -nologo'
			elseif l:ext == 'ps1'
				let cmd = 'powershell -file'
			elseif l:ext == 'zsh'
				let cmd = 'zsh'
			elseif index(['osa', 'scpt', 'applescript'], l:ext) >= 0
				let cmd = 'osascript'
			endif
		endif
		if l:cmd == ''
			call s:execute(0)
		elseif !has('nvim')
			silent exec '!start cmd /C '. cmd . ' ' . fname . ' & pause'
		else
			call asyncrun#run('', {'mode':4}, cmd . ' ' . fname)
		endif
	else
		let cmd = get(g:asyncrun_ftrun, &ft, '')
		if cmd != ''
			exec '!'. cmd . ' ' . shellescape(expand("%"))
		elseif &ft == 'python'
			exec '!python ' . shellescape(expand("%"))
		elseif &ft == 'javascript' 
			exec '!node ' . shellescape(expand("%"))
		elseif &ft == 'sh'
			exec '!sh ' . shellescape(expand("%"))
		elseif &ft == 'lua'
			exec '!lua ' . shellescape(expand("%"))
		elseif &ft == 'perl'
			exec '!perl ' . shellescape(expand("%"))
		elseif &ft == 'ruby'
			exec '!ruby ' . shellescape(expand("%"))
		elseif &ft == 'php'
			exec '!php ' . shellescape(expand("%"))
		elseif &ft == 'zsh'
			exec '!zsh ' . shellescape(expand("%"))
		elseif index(['osa', 'scpt', 'applescript'], l:ext) >= 0
			exec '!osascript '. shellescape(expand('%'))
		else
			call s:execute(0)
		endif
	endif
	if l:dest != ''
		call s:chdir(savecwd)
	endif
endfunc


" auto open quickfix window
if has("autocmd")
	function! s:check_quickfix()
		let height = get(g:, "asyncrun_open", 0)
		if height > 0
			call asyncrun#quickfix_toggle(height, 1)
		endif
	endfunc
	augroup asyncrun_augroup
		au!
		au User AsyncRunStart call s:check_quickfix()
	augroup END
endif



