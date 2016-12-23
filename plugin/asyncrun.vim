" asyncrun.vim - Run shell commands in background and output to quickfix
"
" Maintainer: skywind3000 (at) gmail.com
" Homepage: http://www.vim.org/scripts/script.php?script_id=5431
"
" Last change: 2016.12.23
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
	let msg = "required: +timers +channel +job +reltime and vim >= 7.4.1829"
	call s:ErrorMsg(msg)
endfunc

" run autocmd
function! s:AutoCmd(name)
	if has('autocmd')
		exec 'silent doautocmd User AsyncRun'.a:name
	endif
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
	if has('job') && has('channel') && has('timers') && has('reltime') 
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
let s:async_start = 0.0
let s:async_debug = 0
let s:async_quick = 0
let s:async_scroll = 0
let s:async_hold = 0
let s:async_congest = 0
let s:async_efm = &errorformat

" check :cbottom available, cursor in quick need to hold ?
if s:async_nvim == 0
	let s:async_quick = (v:version >= 800 || has('patch-7.4.1997'))? 1 : 0
	let s:async_hold = (v:version >= 800 || has('patch-7.4.2100'))? 0 : 1
else
	let s:async_quick = 0
	let s:async_hold = 1
endif

" check if we have vim 8.0.100
if s:async_nvim == 0 && v:version >= 800
	let s:async_congest = has('patch-8.0.100')? 1 : 0
	let s:async_congest = 0
endif

" scroll quickfix down
function! s:AsyncRun_Job_Scroll()
	if &buftype == 'quickfix'
		silent exec 'normal! G'
	endif
endfunc

" quickfix window cursor check
function! s:AsyncRun_Job_Cursor()
	if &buftype == 'quickfix'
		if s:async_hold != 0
			let w:asyncrun_qfview = winsaveview()
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
		noautocmd windo call s:AsyncRun_Job_Scroll()
		noautocmd silent exec ''.l:winnr.'wincmd w'
	else
		cbottom
	endif
endfunc

" restore view in old vim/neovim
function! s:AsyncRun_Job_ViewReset()
	if &buftype == 'quickfix'
		if exists('w:asyncrun_qfview')
			call winrestview(w:asyncrun_qfview)
			unlet w:asyncrun_qfview
		endif
	endif
endfunc

" it will reset cursor when caddexpr is invoked
function! s:AsyncRun_Job_QuickReset()
	if &buftype == 'quickfix'
		call s:AsyncRun_Job_ViewReset()
	else
		let l:winnr = winnr()
		noautocmd windo call s:AsyncRun_Job_ViewReset()
		noautocmd silent! exec ''.l:winnr.'wincmd w'
	endif
endfunc

" check if quickfix window can scroll now
function! s:AsyncRun_Job_CheckScroll()
	if g:asyncrun_last == 0
		if &buftype == 'quickfix'
			if s:async_hold != 0
				let w:asyncrun_qfview = winsaveview()
			endif
			return (line('.') == line('$'))
		else
			return 1
		endif
	elseif g:asyncrun_last == 1
		let s:async_check_last = 1
		let l:winnr = winnr()
		noautocmd windo call s:AsyncRun_Job_Cursor()
		noautocmd silent! exec ''.l:winnr.'wincmd w'
		return s:async_check_last
	elseif g:asyncrun_last == 2
		return 1
	else
		if &buftype == 'quickfix'
			if s:async_hold != 0
				let w:asyncrun_qfview = winsaveview()
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
	while s:async_tail < s:async_head
		let l:text = s:async_output[s:async_tail]
		if l:iconv != 0
			try
				let l:text = iconv(l:text, g:asyncrun_encs, &encoding)
			catch /.*/
			endtry
		endif
		if l:text != ''
			if l:raw == 0
				caddexpr l:text
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
	elseif s:async_hold != 0 
		call s:AsyncRun_Job_QuickReset()
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
	if a:mode == 0
		silent exec 'doautocmd QuickFixCmdPre '. name
	else
		silent exec 'doautocmd QuickFixCmdPost '. name
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
	elseif s:async_hold != 0
		call s:AsyncRun_Job_QuickReset()
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
		while l:index < l:size
			let s:async_output[s:async_head] = a:data[l:index]
			let s:async_head += 1
			let l:index += 1
		endwhile
	elseif a:event == 'exit'
		if type(a:data) == type(1)
			let s:async_code = a:data
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
	let s:async_efm = &errorformat
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
		let s:async_job = job_start(l:args, l:options)
		let l:success = (job_status(s:async_job) != 'fail')? 1 : 0
	else
		let l:callbacks = {'shell': 'AsyncRun'}
		let l:callbacks['on_stdout'] = function('s:AsyncRun_Job_NeoVim')
		let l:callbacks['on_stderr'] = function('s:AsyncRun_Job_NeoVim')
		let l:callbacks['on_exit'] = function('s:AsyncRun_Job_NeoVim')
		let s:async_job = jobstart(l:args, l:callbacks)
		let l:success = (s:async_job > 0)? 1 : 0
	endif
	if l:success != 0
		let s:async_output = {}
		let s:async_head = 0
		let s:async_tail = 0
		let l:arguments = "[".l:name."]"
		let l:title = ':AsyncRun '.l:name
		if s:async_nvim == 0
			if v:version >= 800 || has('patch-7.4.2210')
				call setqflist([], ' ', {'title':l:title})
			else
				call setqflist([], '')
			endif
		else
			call setqflist([], ' ', l:title)
		endif
		call setqflist([{'text':l:arguments}], 'a')
		let s:async_start = float2nr(reltimefloat(reltime()))
		let l:name = 'g:AsyncRun_Job_OnTimer'
		let s:async_timer = timer_start(100, l:name, {'repeat':-1})
		let s:async_state = 1
		let g:asyncrun_status = "running"
		let s:async_info.post = s:async_info.postsave
		let s:async_info.auto = s:async_info.autosave
		let s:async_info.postsave = ''
		let s:async_info.autosave = ''
		let g:asyncrun_text = s:async_info.text
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
				call jobstop(s:async_job)
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


"----------------------------------------------------------------------
" asyncrun - run
"----------------------------------------------------------------------
function! asyncrun#run(bang, opts, args)
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
	let l:retval = ''

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
		let l:opts.text = s:StringReplace(l:opts.text, l:replace, l:val)
	endfor

	" combine options
	if type(a:opts) == type({})
		for [l:key, l:val] in items(a:opts)
			let l:opts[l:key] = l:val
		endfor
	endif

	" check if need to save
	if get(l:opts, 'save', '')
		try | silent update | catch | endtry
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

	if l:mode >= 10 
		let l:opts.cmd = l:command
		let l:opts.mode = l:mode
		if g:asyncrun_hook != ''
			exec 'call '. g:asyncrun_hook .'(l:opts)'
		endif
		return
	endif

	if l:opts.cwd != ''
		let l:opts.savecwd = getcwd()
		try
			silent exec cd . fnameescape(l:opts.cwd)
		catch /.*/
			echohl ErrorMsg
			echom "E344: Can't find directory \"".l:opts.cwd."\" in -cwd"
			echohl NONE
			return
		endtry
	endif

	if l:mode == 0 && s:asyncrun_support != 0
		let s:async_info.postsave = opts.post
		let s:async_info.autosave = opts.auto
		let s:async_info.text = opts.text
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
			py p.wait()
			if has('patch-7.4.145')
				let l:retval = pyeval('text')
			else
				py text = text.replace('\\', '\\\\').replace('"', '\\"')
				py text = text.replace('\n', '\\n').replace('\r', '\\r')
				py vim.command('let l:retval = "%s"'%text)
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
			py3 p.wait()
			if has('patch-7.4.145')
				let l:retval = py3eval('text')
			else
				py3 text = text.replace('\\', '\\\\').replace('"', '\\"')
				py3 text = text.replace('\n', '\\n').replace('\r', '\\r')
				py3 vim.command('let l:retval = "%s"'%text)
			endif
		else
			let l:retval = system(l:command)
		endif
		let g:asyncrun_text = opts.text
		if opts.post != ''
			exec opts.post
		endif
	elseif l:mode <= 5
		if s:asyncrun_windows != 0 && has('gui_running')
			let l:ccc = shellescape(s:ScriptWrite(l:command, 1))
			if l:mode == 4
				silent exec '!start cmd /C '. l:ccc
			else
				silent exec '!start /b cmd /C '. l:ccc
			endif
			redraw
		else
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

	if l:opts.cwd != ''
		silent exec cd fnameescape(l:opts.savecwd)
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
	return '1.3.0'
endfunc


"----------------------------------------------------------------------
" Commands
"----------------------------------------------------------------------
command! -bang -nargs=+ -complete=file AsyncRun 
	\ call asyncrun#run('<bang>', '', <q-args>)

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




