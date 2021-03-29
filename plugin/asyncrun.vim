" asyncrun.vim - Run shell commands in background and output to quickfix
"
" Maintainer: skywind3000 (at) gmail.com, 2016, 2017, 2018, 2019, 2020
" Homepage: http://www.vim.org/scripts/script.php?script_id=5431
"
" Last Modified: 2021/03/29 08:58
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
"     $VIM_PATHNOEXT - File name with full path but without extension
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
"     Parameters also accept these environment variables wrapped by
"     "$(...)", and "$(VIM_FILEDIR)" will be expanded as file directory.
"
"     It is safe to use "$(...)" than "%:xx" when filenames contain spaces.
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
" Modes:
"     -mode=async     - run in quickfix window (default)
"     -mode=make      - run in makeprg
"     -mode=bang      - run in !xxx
"     -mode=system    - run in new system window (windows) or ! (others)
"     -mode=terminal  - run in a reusable terminal window
"
" Variables:
"     g:asyncrun_code - exit code
"     g:asyncrun_status - 'running', 'success' or 'failure'
"
" Requirements:
"     vim 7.4.1829 is minimal version to support async mode
"     vim 8.1.1 is minial version to use "-mode=term"
"
" Examples:
"     :AsyncRun gcc % -o %<
"     :AsyncRun make
"     :AsyncRun -raw -cwd=$(VIM_FILEDIR) python "$(VIM_FILEPATH)"
"     :AsyncRun -cwd=<root> make
"     :AsyncRun! grep -n -R <cword> .
"     :noremap <F7> :AsyncRun gcc % -o %< <cr>
"
" Run in the internal terminal:
"     :AsyncRun -mode=term bash
"     :AsyncRun -mode=term -pos=tab bash
"     :AsyncRun -mode=term -pos=curwin bash
"     :AsyncRun -mode=term -pos=top -rows=15 bash
"     :AsyncRun -mode=term -pos=bottom -rows=15 bash
"     :AsyncRun -mode=term -pos=left -cols=40 bash
"     :AsyncRun -mode=term -pos=right -cols=40 bash
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

" script will be executed after finished.
let g:asyncrun_exit = get(g:, 'asyncrun_exit', '')

" non-zero to ring a bell after finished.
let g:asyncrun_bell = get(g:, 'asyncrun_bell', 0)

" stoponexit option of job_start
let g:asyncrun_stop = get(g:, 'asyncrun_stop', '')

" specify how to run your command
let g:asyncrun_mode = get(g:, 'asyncrun_mode', 0)

" command hook
let g:asyncrun_hook = get(g:, 'asyncrun_hook', '')

" quickfix scroll mode
let g:asyncrun_last = get(g:, 'asyncrun_last', 0)

" speed for each timer
let g:asyncrun_timer = get(g:, 'asyncrun_timer', 25)

" previous exit code
let g:asyncrun_code = get(g:, 'asyncrun_code', '')

" status: 'running', 'success' or 'failure'
let g:asyncrun_status = get(g:, 'asyncrun_status', '')

" command encoding
let g:asyncrun_encs = get(g:, 'asyncrun_encs', '')

" trim empty lines ?
let g:asyncrun_trim = get(g:, 'asyncrun_trim', 0)

" user text
let g:asyncrun_text = get(g:, 'asyncrun_text', '')

" enable local errorformat ?
let g:asyncrun_local = get(g:, 'asyncrun_local', 1)

" name of autocmd in QuickFixCmdPre / QuickFixCmdPost
let g:asyncrun_auto = get(g:, 'asyncrun_auto', '')

" specify shell rather than &shell
let g:asyncrun_shell = get(g:, 'asyncrun_shell', '')

" specify shell cmd flag rather than &shellcmdflag
let g:asyncrun_shellflag = get(g:, 'asyncrun_shellflag', '')

" external runners for '-mode=terminal'
let g:asyncrun_runner = get(g:, 'asyncrun_runner', {})

" command modifier for '-program=xxx'
let g:asyncrun_program = get(g:, 'asyncrun_program', {})

" silent the autocmds ?
let g:asyncrun_silent = get(g:, 'asyncrun_silent', 1)

" skip autocmds
let g:asyncrun_skip = get(g:, 'asyncrun_skip', 0)

" last args 
let g:asyncrun_info = get(g:, 'asyncrun_info', '')

" 0: no save, 1: save current buffer, 2: save all modified buffers.
let g:asyncrun_save = get(g:, 'asyncrun_save', 0)

" enable stdin ?
if !exists('g:asyncrun_stdin')
	let g:asyncrun_stdin = has('win32') || has('win64') || has('win95')
endif

" external script for '-mode=4'
let g:asyncrun_script = get(g:, 'asyncrun_script', '')

" strict to execute vim script
let g:asyncrun_strict = get(g:, 'asyncrun_strict', 0)

" terminal job name
let g:asyncrun_name = ''



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
		let cmd = haslocaldir()? ((haslocaldir() == 1)? 'lcd' : 'tcd') : 'cd'
	endif
	silent execute cmd . ' '. fnameescape(a:path)
endfunc

" safe shell escape for neovim
function! s:shellescape(path)
	if s:asyncrun_windows == 0
		return shellescape(a:path)
	endif
	let hr = shellescape(a:path)
	if &ssl != 0
		let hr = s:StringReplace(hr, "'", '"')
	endif
	return hr
endfunc

" save/restore view
function! s:save_restore_view(mode)
	if a:mode == 0
		let w:__asyncrun_view__ = winsaveview()
	elseif exists('w:__asyncrun_view__')
		call winrestview(w:__asyncrun_view__)
		unlet w:__asyncrun_view__
	endif
endfunc

let s:asyncrun_windows = 0
let g:asyncrun_windows = 0
let s:asyncrun_support = 0
let g:asyncrun_support = 0
let s:asyncrun_gui = has('gui_running')
let g:asyncrun_gui = has('gui_running')

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

" check is gui loaded in neovim
if has('nvim')
	if exists('g:GuiLoaded')
		if g:GuiLoaded != 0
			let s:asyncrun_gui = 1
			let g:asyncrun_gui = 1
		endif
	elseif exists('*nvim_list_uis') && len(nvim_list_uis()) > 0
		let uis = nvim_list_uis()[0]
		let s:asyncrun_gui = get(uis, 'ext_termcolors', 0)? 0 : 1
		let g:asyncrun_gui = s:asyncrun_gui
	elseif exists("+termguicolors") && (&termguicolors) != 0
		let s:asyncrun_gui = 1
		let g:asyncrun_gui = 1
	endif
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
let s:async_term = {}

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
	if g:asyncrun_local != 0
		let &l:efm = s:async_info.errorformat
		let &g:efm = s:async_info.errorformat
	endif
	let l:raw = (&efm == '')? 1 : 0
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
		if !s:async_info.strip
			call setqflist([{'text':l:text}], 'a')
		endif
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
	let g:asyncrun_name = ''
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
	let l:args = []
	if g:asyncrun_shell == ''
		let l:args += split(&shell)
		let l:args += split(&shellcmdflag)
	else
		let l:args += split(g:asyncrun_shell)
		let l:args += split(g:asyncrun_shellflag)
	endif
	let s:async_info.errorformat = s:async_efm
	let l:name = []
	if type(a:cmd) == 1
		let l:name = a:cmd
		if s:asyncrun_windows == 0
			let l:args += [a:cmd]
		else
			let l:tmp = s:ScriptWrite(a:cmd, 0)
			if s:async_nvim == 0
				let l:args += [l:tmp]
			else
				let l:args = s:shellescape(l:tmp)
			endif
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
		elseif exists('*ch_close_in')
			if g:asyncrun_stdin != 0
				let l:options['in_io'] = 'pipe'
			endif
		endif
		let s:async_job = job_start(l:args, l:options)
		let l:success = (job_status(s:async_job) != 'fail')? 1 : 0
		if l:success && l:options['in_io'] == 'pipe'
			silent! call ch_close_in(job_getchannel(s:async_job))
		endif
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
		if !s:async_info.append
			if s:async_nvim == 0
				if v:version >= 800 || has('patch-7.4.2210')
					call setqflist([], ' ', {'title':l:title})
				else
					call setqflist([], ' ')
				endif
			else
				call setqflist([], ' ', l:title)
			endif
		endif
		if !s:async_info.strip
			call setqflist([{'text':l:arguments}], 'a')
		endif
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
					call s:AutoCmd('Interrupt')
					return 0
				else
					return -2
				endif
			else
				return -3
			endif
		else
			if s:async_job > 0
				call s:AutoCmd('Interrupt')
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
	let opts.strip = get(opts, 'strip', '')
	let opts.append = get(opts, 'append', '')
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
function! asyncrun#script_write(command, pause)
	let tmpname = fnamemodify(tempname(), ':h') . '\asyncrun.cmd'
	let command = a:command
	if s:asyncrun_windows != 0
		let lines = ["@echo off\r"]
		let $VIM_COMMAND = a:command
		let $VIM_PAUSE = (a:pause)? 'pause' : ''
		let lines += ["call %VIM_COMMAND% \r"]
		let lines += ["set VIM_EXITCODE=%ERRORLEVEL%\r"]
		let lines += ["call %VIM_PAUSE% \r"]
		let lines += ["exit %VIM_EXITCODE%\r"]
	else
		let shell = (g:asyncrun_shell != '')? g:asyncrun_shell : (&shell)
		let lines = ['#! ' . shell]
		let lines += [command]
		if a:pause != 0
			if executable('bash')
				let pause = 'read -n1 -rsp "press any key to continue ..."'
				let lines += ['bash -c ''' . pause . '''']
			else
				let lines += ['echo "press enter to continue ..."']
				let lines += ['sh -c "read _tmp_"']
			endif
		endif
		let tmpname = fnamemodify(tempname(), ':h') . '/asyncrun.sh'
	endif
	if v:version >= 700
		call writefile(lines, tmpname)
	else
		exe 'redir ! > '.fnameescape(tmpname)
		for line in lines
			silent echo line
		endfor
		redir END
	endif
	if s:asyncrun_windows == 0
		if exists('*setfperm')
			silent! call setfperm(tmpname, 'rwxrwxrws')
		endif
	endif
	return tmpname
endfunc

" write script to a file and return filename
function! s:ScriptWrite(command, pause)
	return asyncrun#script_write(a:command, a:pause)
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
	if f == '%'
		let f = expand('%')
		if &bt == 'terminal' || &bt == 'nofile'
			let f = ''
		endif
	elseif f =~ '^\~[\/\\]'
		let f = expand(f)
	endif
	let f = fnamemodify(f, ':p')
	if s:asyncrun_windows
		let f = substitute(f, "\\", '/', 'g')
	endif
	if f =~ '\/$'
		let f = fnamemodify(f, ':h')
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
function! s:find_root(path, markers, strict)
	function! s:guess_root(filename, markers)
		let fullname = asyncrun#fullname(a:filename)
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
				if newname =~ '[\*\?\[\]]'
					if glob(newname) != ''
						return pivot
					endif
				elseif filereadable(newname)
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
	if a:path == '%'
		if exists('b:asyncrun_root') && b:asyncrun_root != ''
			return b:asyncrun_root
		elseif exists('t:asyncrun_root') && t:asyncrun_root != ''
			return t:asyncrun_root
		elseif exists('g:asyncrun_root') && g:asyncrun_root != ''
			return g:asyncrun_root
		endif
	endif
	let root = s:guess_root(a:path, a:markers)
	if root != ''
		return asyncrun#fullname(root)
	elseif a:strict != 0
		return ''
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
		if type(a:1) == type([])
			let markers = a:1
		endif
	endif
	let strict = (a:0 >= 2)? (a:2) : 0
	let l:hr = s:find_root(a:path, markers, strict)
	if s:asyncrun_windows
		let l:hr = s:StringReplace(l:hr, '/', "\\")
	endif
	return l:hr
endfunc

function! asyncrun#path_join(home, name)
	return s:path_join(a:home, a:name)
endfunc

" change to unix
function! asyncrun#path_win2unix(winpath, prefix)
	let prefix = a:prefix
	let path = a:winpath
	if path =~ '^\a:[/\\]'
		let drive = tolower(strpart(path, 0, 1))
		let name = strpart(path, 3)
		let p = s:path_join(prefix, drive)
		let p = s:path_join(p, name)
		return tr(p, '\', '/')
	elseif path =~ '^[/\\]'
		let drive = tolower(strpart(getcwd(), 0, 1))
		let name = strpart(path, 1)
		let p = s:path_join(prefix, drive)
		let p = s:path_join(p, name)
		return tr(p, '\', '/')
	else
		return tr(a:winpath, '\', '/')
	endif
endfunc


"----------------------------------------------------------------------
" init terminal in current window
"----------------------------------------------------------------------
function! s:terminal_init(opts)
	let command = a:opts.cmd
	let hidden = get(a:opts, 'hidden', 0)
	let shell = (has('nvim') == 0)? 1 : 0
	let pos = get(a:opts, 'pos', 'bottom')
	let pos = (pos == 'background')? 'hide' : pos
	let cwd = get(a:opts, 'cwd', '')
	let cwd = (cwd != '' && isdirectory(cwd))? cwd : ''
	if get(a:opts, 'safe', get(g:, 'asyncrun_term_safe', 0)) != 0
		let command = s:ScriptWrite(command, 0)
		if stridx(command, ' ') >= 0
			let command = s:shellescape(command)
		endif
		let shell = 0
	endif
	if shell
		if s:asyncrun_windows != 0
			let exe = ($ComSpec == '')? 'cmd.exe' : $ComSpec
			let command = exe . ' /C ' . command
		else
			let args = []
			if g:asyncrun_shell != ''
				let args += split(g:asyncrun_shell)
				let args += split(g:asyncrun_shellflag)
			else
				let args += split(&shell)
				let args += split(&shellcmdflag)
			endif
			let args += [command]
			let command = args
		endif
	endif
	if has('nvim') == 0
		if pos != 'hide'
			let opts = {'curwin':1, 'norestore':1, 'term_finish':'open'}
			let opts.term_kill = 'term'
			let opts.exit_cb = function('s:terminal_exit')
			let close = get(a:opts, 'close', 0)
			if close
				let opts.term_finish = 'close'
			endif
			if has('patch-8.1.0230')
				if cwd != ''
					let opts.cwd = cwd
				endif
			endif
			try
				let bid = term_start(command, opts)
			catch /^.*/
				call s:ErrorMsg('E37: No write since last change')
				return -1
			endtry
			let jid = (bid > 0)? term_getjob(bid) : -1
			let success = (bid > 0)? 1 : 0
		else
			let opts = {'stoponexit':'term'}
			let opts.exit_cb = function('s:terminal_exit')
			if cwd != ''
				let opts.cwd = cwd
			endif
			let jid = job_start(command, opts)
			let bid = -1
			let success = (job_status(jid) != 'fail')? 1 : 0
		endif
		let pid = (success)? (job_info(jid)['process']) : -1
	else
		let opts = {}
		let opts.on_exit = function('s:terminal_exit')
		if cwd != ''
			let opts.cwd = cwd
		endif
		if pos != 'hide'
			try
				enew
			catch /^.*/
				call s:ErrorMsg('E37: No write since last change')
				return -1
			endtry
			let jid = termopen(command, opts)
			let bid = (&bt == 'terminal')? winbufnr(0) : -1
		else
			let jid = jobstart(command, opts)
			let jid = (jid > 0)? jid : -1
			let bid = -1
		endif
		let success = (jid > 0)? 1 : 0
		let pid = (success)? jid : -1
	endif
	if success == 0
		call s:ErrorMsg('Process creation failed')
		return -1
	endif
	if pos != 'hide'
		setlocal nonumber signcolumn=no norelativenumber
		let b:asyncrun_cmd = a:opts.cmd
		let b:asyncrun_name = get(a:opts, 'name', '')
		if get(a:opts, 'listed', 1) == 0
			setlocal nobuflisted
		endif
		exec has('nvim')? 'startinsert' : ''
		if has_key(a:opts, 'hidden')
			exec 'setlocal bufhidden=' . (hidden? 'hide' : '')
		endif
	endif
	let opts = {}
	let opts.name = get(a:opts, 'name', '')
	let opts.post = get(a:opts, 'post', '')
	let opts.cmd = get(a:opts, 'cmd', '')
	if has_key(a:opts, 'exit')
		let opts.exit = a:opts.exit
	endif
	let opts.pid = pid
	let opts.jid = jid
	let opts.bid = bid
	let s:async_term[pid] = opts
	return pid
endfunc


"----------------------------------------------------------------------
" init terminal in current window
"----------------------------------------------------------------------
function! s:terminal_open(opts)
	let previous = getcwd()
	if a:opts.cwd != ''
		silent! call s:chdir(a:opts.cwd)
	endif
	let hr = s:terminal_init(a:opts)
	if a:opts.cwd != ''
		silent! call s:chdir(previous)
	endif
	return hr
endfunc


"----------------------------------------------------------------------
" exit callback
"----------------------------------------------------------------------
function! s:terminal_exit(...)
	if has('nvim') == 0
		let pid = job_info(a:1)['process']
	else
		let pid = a:1
	endif
	let code = a:2
	if !has_key(s:async_term, pid)
		return -1
	endif
	let opts = s:async_term[pid]
	unlet s:async_term[pid]
	let g:asyncrun_code = code
	let g:asyncrun_name = opts.name
	if opts.post != ''
		exec opts.post
	endif
	if has_key(opts, 'exit')
		let F = function(opts.exit)
		call F(opts.name, code)
	endif
endfunc


"----------------------------------------------------------------------
" run in a terminal
"----------------------------------------------------------------------
function! s:start_in_terminal(opts)
	let pos = get(a:opts, 'pos', 'bottom')
	if has('patch-8.1.1') == 0 && has('nvim-0.3') == 0
		call s:ErrorMsg("Terminal is not available in this vim")
		return -1
	endif
	let avail = -1
	for ii in range(winnr('$'))
		let wid = ii + 1
		if getwinvar(wid, '&bt') == 'terminal'
			if has('nvim') == 0
				let bid = winbufnr(wid)
				if term_getstatus(bid) == 'finished'
					let avail = wid
					break
				endif
			else
				let ch = getwinvar(wid, '&channel')
				let status = (jobwait([ch], 0)[0] == -1)? 1 : 0
				if status == 0
					let avail = wid
					break
				endif
			endif
		endif
	endfor
	let focus = get(a:opts, 'focus', 1)
	if pos ==? 'tab'
		if get(a:opts, 'reuse', 0) == 0
			exec "tab split"
			if pos ==# 'TAB'
				exec "-tabmove"
			endif
		else
			let avail = -1
			for i in range(tabpagenr('$'))
				if tabpagewinnr(i + 1, '$') == 1
					let bid = tabpagebuflist(i + 1)[0]
					if getbufvar(bid, '&bt', '') == 'terminal'
						if has('nvim') == 0
							if term_getstatus(bid) == 'finished'
								let avail = i + 1
								break
							endif
						else
							let ch = getbufvar(bid, '&channel')
							let status = (jobwait([ch], 0)[0] == -1)? 1 : 0
							if status == 0
								let avail = i + 1
								break
							endif
						endif
					endif
				endif
			endfor
			if avail < 0
				exec "tab split"
				if pos ==# 'TAB'
					exec "-tabmove"
				endif
			else
				exec 'tabn ' . avail
			endif
		endif
		let hr = s:terminal_open(a:opts)
		if hr >= 0
			if focus == 0
				exec has('nvim')? 'stopinsert' : ''
				exec 'tabprevious'
			endif
		endif
		return 0
	elseif pos == 'cur' || pos == 'curwin' || pos == 'current'
		let hr = s:terminal_open(a:opts)
		return 0
	elseif pos == 'hide' || pos == 'background'
		let hr = s:terminal_open(a:opts)
		return 0
	endif
	let uid = win_getid()
	keepalt noautocmd windo call s:save_restore_view(0)
	keepalt noautocmd call win_gotoid(uid)
	let origin = win_getid()
	if avail < 0 || get(a:opts, 'reuse', 1) == 0
		let rows = get(a:opts, 'rows', '')
		let cols = get(a:opts, 'cols', '')
		if pos == 'top'
			exec "leftabove " . rows . "split"	
		elseif pos == 'bottom' || pos == 'bot'
			exec "rightbelow " . rows . "split"
		elseif pos == 'left'
			exec "leftabove " . cols . "vs"
		elseif pos == 'right'
			exec "rightbelow " . cols . "vs"
		else
			exec "rightbelow " . rows . "split"
		endif
	endif
	if avail > 0 
		exec "normal! ". avail . "\<c-w>\<c-w>"
	endif
	let uid = win_getid()
	keepalt noautocmd call win_gotoid(origin)
	keepalt noautocmd windo call s:save_restore_view(1)
	keepalt noautocmd call win_gotoid(origin)
	noautocmd call win_gotoid(uid)
	let hr = s:terminal_open(a:opts)
	if focus == 0 && hr >= 0
		exec has('nvim')? 'stopinsert' : ''
		call win_gotoid(origin)
	endif
	return 0
endfunc


"----------------------------------------------------------------------
" run command
"----------------------------------------------------------------------
function! s:run(opts)
	let l:opts = deepcopy(a:opts)
	let l:command = a:opts.cmd
	let l:retval = ''
	let l:mode = g:asyncrun_mode
	let l:runner = ''
	let l:opts.origin = l:opts.cmd

	if a:opts.mode != ''
		let l:mode = a:opts.mode
	endif

	" mode alias
	let l:modemap = {'async':0, 'make':1, 'bang':2, 'python':3, 'os':4,
				\ 'hide':5, 'terminal': 6, 'execute':1, 'term':6, 'system':4}

	let l:modemap['external'] = 4
	let l:modemap['quickfix'] = 0
	let l:modemap['vim'] = 2
	let l:modemap['wait'] = 3

	let l:mode = get(l:modemap, l:mode, l:mode)

	" alias "-mode=raw" to "-mode=async -raw=1"
	if type(l:mode) == type('') && l:mode == 'raw'
		let l:mode = 0
		let l:opts.raw = 1
	elseif type(l:mode) == 0 && l:mode == 6
		let pos = get(l:opts, 'pos', '')
		if has_key(g:asyncrun_runner, pos)
			let l:runner = pos
		elseif pos == 'bang' || pos == 'vim'
			let l:mode = 2
		elseif pos == 'extern' || pos == 'external'
			let l:mode = 4
		elseif pos == 'system' || pos == 'os'
			let l:mode = 4
		elseif pos == 'quickfix'
			let l:mode = 0
			let l:opts.raw = 1
		endif
	endif

	" process makeprg/grepprg in -program=?
	let l:program = ""

	let s:async_efm = a:opts.errorformat

	if l:opts.program == 'make'
		let l:program = &makeprg
	elseif l:opts.program == 'grep'
		let l:program = &grepprg
		let s:async_efm = &grepformat
	elseif l:opts.program == 'wsl'
		if s:asyncrun_windows != 0
			let root = ($SystemRoot == '')? 'C:/Windows' : $SystemRoot
			let t1 = root . '/system32/wsl.exe'
			let t2 = root . '/sysnative/wsl.exe'
			let tt = executable(t1)? t1 : (executable(t2)? t2 : '')
			if tt == ''
				call s:ErrorMsg("not find wsl in your system")
				return
			endif
			let cmd = s:shellescape(substitute(tt, '\\', '\/', 'g'))
			let dist = get(l:opts, 'dist', get(g:, 'asyncrun_dist', ''))
			if dist != ''
				let cmd = cmd . ' -d ' . dist
			endif
			let l:command = cmd . ' ' . l:command
		else
			call s:ErrorMsg("only available for Windows")
			return ''
		endif
	elseif l:opts.program != ''
		let name = l:opts.program
		let test = ['cygwin', 'msys', 'mingw32', 'mingw64']
		if index(test, name) >= 0
			unsilent let l:command = s:program_msys(l:opts)
		else
			if has_key(g:asyncrun_program, name) == 0
				call s:ErrorMsg(name . " not found in g:asyncrun_program")
				return ''
			endif
			let F = g:asyncrun_program[name]
			if type(F) == type('')
				let F = function(F)
			endif
			unsilent let l:command = F(l:opts)
		endif
		if l:command == ''
			return ''
		endif
		let l:opts.cmd = l:command
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
		return ''
	elseif l:mode == 7
		if s:asyncrun_windows != 0 && s:asyncrun_gui != 0
			let l:mode = 4
		else
			let script = get(g:, 'asyncrun_script', '')
			let l:mode = (script == '')? 2 : 4
		endif
	endif

	let g:asyncrun_cmd = l:command
	let t = s:StringStrip(l:command)

	if strpart(t, 0, 1) == ':' && g:asyncrun_strict == 0
		exec strpart(t, 1)
		return ''
	elseif l:runner != ''
		let F = g:asyncrun_runner[l:runner]
		if type(F) == type('')
			let F = function(F)
		endif
		let obj = deepcopy(l:opts)
		let obj.cmd = command
		let obj.src = a:opts.cmd
		call F(obj)
		return ''
	endif

	if exists('g:asyncrun_open')
		let s:asyncrun_open = g:asyncrun_open
		if has_key(a:opts, 'open')
			let s:asyncrun_open = a:opts.open
		endif
		if has_key(a:opts, 'silent')
			if a:opts.silent
				let s:asyncrun_open = 0
			endif
		endif
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
		let s:async_info.strip = opts.strip
		let s:async_info.append = opts.append
		if s:AsyncRun_Job_Start(l:command) != 0
			call s:AutoCmd('Error')
		endif
	elseif l:mode <= 1 && has('quickfix')
		call s:AutoCmd('Pre')
		call s:AutoCmd('Start')
		let l:makesave = &l:makeprg
		let l:script = s:ScriptWrite(l:command, 0)
		if s:asyncrun_windows != 0
			let &l:makeprg = s:shellescape(l:script)
		else
			let &l:makeprg = 'source '. s:shellescape(l:script)
		endif
		let l:efm1 = &g:efm
		let l:efm2 = &l:efm
		if g:asyncrun_local != 0
			let &g:efm = s:async_efm
			let &l:efm = s:async_efm
		endif
		if has('autocmd')
			call s:AsyncRun_Job_AutoCmd(0, opts.auto)
			exec "noautocmd make!"
			call s:AsyncRun_Job_AutoCmd(1, opts.auto)
		else
			exec "make!"
		endif
		if g:asyncrun_local != 0
			if l:efm1 != &g:efm | let &g:efm = l:efm1 | endif
			if l:efm2 != &l:efm | let &l:efm = l:efm2 | endif
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
		let autocmd = get(opts, 'autocmd', 0)
		if autocmd != 0
			call s:AutoCmd('Pre')
			call s:AutoCmd('Start')
		endif
		exec '!'. escape(l:command, '%#')
		let g:asyncrun_text = opts.text
		if opts.post != ''
			exec opts.post
		endif
		if autocmd != 0
			call s:AutoCmd('Stop')
		endif
	elseif l:mode == 3
		let autocmd = get(opts, 'autocmd', 0)
		if autocmd != 0
			call s:AutoCmd('Pre')
			call s:AutoCmd('Start')
		endif
		if s:asyncrun_windows == 0
			let l:retval = system(l:command)
			let g:asyncrun_shell_error = v:shell_error
		elseif has('nvim')
			let l:retval = system(l:command)
			let g:asyncrun_shell_error = v:shell_error
		elseif has('python3')
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
		elseif has('python')
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
		else
			let l:retval = system(l:command)
			let g:asyncrun_shell_error = v:shell_error
		endif
		let g:asyncrun_text = opts.text
		if opts.post != ''
			exec opts.post
		endif
		if autocmd != 0
			call s:AutoCmd('Stop')
		endif
	elseif l:mode <= 5
		let script = get(g:, 'asyncrun_script', '')
		if script != '' && l:mode == 4
			let $VIM_COMMAND = l:command
			let l:command = script . ' ' . l:command
			if s:asyncrun_windows
				let ccc = s:shellescape(s:ScriptWrite(l:command, 0))
				silent exec '!start /b cmd /C '. ccc
			else
				call system(l:command . ' &')
			endif
		elseif s:asyncrun_windows
			if l:mode == 4
				let l:ccc = s:shellescape(s:ScriptWrite(l:command, 1))
				silent exec '!start cmd /C '. l:ccc
			else
				let l:ccc = s:shellescape(s:ScriptWrite(l:command, 0))
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
	elseif l:mode == 6
		let opts.cmd = l:command
		call s:start_in_terminal(opts)
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
	let l:macros['VIM_PATHNOEXT'] = expand("%:p:r")
	let l:macros['VIM_FILEEXT'] = "." . expand("%:e")
	let l:macros['VIM_FILETYPE'] = (&filetype)
	let l:macros['VIM_CWD'] = getcwd()
	let l:macros['VIM_RELDIR'] = expand("%:h:.")
	let l:macros['VIM_RELNAME'] = expand("%:p:.")
	let l:macros['VIM_CWORD'] = expand("<cword>")
	let l:macros['VIM_CFILE'] = expand("<cfile>")
	let l:macros['VIM_CLINE'] = line('.')
	let l:macros['VIM_VERSION'] = ''.v:version
	let l:macros['VIM_SVRNAME'] = v:servername
	let l:macros['VIM_COLUMNS'] = ''.&columns
	let l:macros['VIM_LINES'] = ''.&lines
	let l:macros['VIM_GUI'] = has('gui_running')? 1 : 0
	let l:macros['VIM_ROOT'] = asyncrun#get_root('%')
	let l:macros['VIM_HOME'] = expand(split(&rtp, ',')[0])
	let l:macros['VIM_PRONAME'] = fnamemodify(l:macros['VIM_ROOT'], ':t')
	let l:macros['VIM_DIRNAME'] = fnamemodify(l:macros['VIM_CWD'], ':t')
	let l:macros['VIM_PWD'] = l:macros['VIM_CWD']
	let l:macros['<cwd>'] = l:macros['VIM_CWD']
	let l:macros['<root>'] = l:macros['VIM_ROOT']
	let l:macros['<pwd>'] = l:macros['VIM_PWD']
	let l:retval = ''

	" handle: empty extension
	if expand("%:e") == ''
		let l:macros['VIM_FILEEXT'] = ''
	endif

	" extract options
	let [l:command, l:opts] = s:ExtractOpt(s:StringStrip(a:args))

	" check lazy load
	if get(l:opts, 'mode', '') == 'load'
		return ''
	endif

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

	" update marcros
	let l:macros['VIM_RUNNAME'] = get(l:opts, 'name', '')

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
		let l:macros['VIM_DIRNAME'] = fnamemodify(l:macros['VIM_CWD'], ':t')
		let l:macros['<cwd>'] = l:macros['VIM_CWD']
	endif

	" windows can use $(WSL_XXX)
	if s:asyncrun_windows != 0
		let wslnames = ['FILEPATH', 'FILENAME', 'FILEDIR', 'FILENOEXT']
		let wslnames += ['PATHNOEXT', 'FILEEXT', 'FILETYPE', 'RELDIR']
		let wslnames += ['RELNAME', 'CFILE', 'ROOT', 'HOME', 'CWD']
		for name in wslnames
			let src = l:macros['VIM_' . name]
			let l:macros['WSL_' . name] = asyncrun#path_win2unix(src, '/mnt')
		endfor
	endif

	" replace macros and setup environment variables
	for [l:key, l:val] in items(l:macros)
		let l:replace = (l:key[0] != '<')? '$('.l:key.')' : l:key
		if l:key[0] != '<'
			if strpart(l:key, 0, 4) != 'WSL_'
				exec 'let $'.l:key.' = l:val'
			endif
		endif
		let l:command = s:StringReplace(l:command, l:replace, l:val)
		let l:opts.text = s:StringReplace(l:opts.text, l:replace, l:val)
	endfor

	" config
	let l:opts.cmd = l:command
	let l:opts.macros = l:macros
	let l:opts.mode = get(l:opts, 'mode', g:asyncrun_mode)
	let l:opts.errorformat = get(l:opts, 'errorformat', &errorformat)
	let s:async_scroll = (a:bang == '!')? 0 : 1

	" check if need to save
	let l:save = get(l:opts, 'save', '')

	if l:save == ''
		let l:save = ''. g:asyncrun_save
	endif

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
" asyncrun - version
"----------------------------------------------------------------------
function! asyncrun#version()
	return '2.8.6'
endfunc


"----------------------------------------------------------------------
" Commands
"----------------------------------------------------------------------
command! -bang -nargs=+ -range=0 -complete=file AsyncRun
			\ call asyncrun#run('<bang>', '', <q-args>, <count>, <line1>, <line2>)

command! -bar -bang -nargs=0 AsyncStop call asyncrun#stop('<bang>')


"----------------------------------------------------------------------
" run command in msys
"----------------------------------------------------------------------
function! s:program_msys(opts)
	let tmpname = fnamemodify(tempname(), ':h') . '\asyncruz.cmd'
	let script = fnamemodify(tempname(), ':h') . '\asyncrun.sh'
	let program = a:opts.program
	if s:asyncrun_windows == 0
		call s:ErrorMsg('program ' . program . ' is only for windows')
		return ''
	endif
	let lines = ["@echo off\r"]
	let lines += ["set CHERE_INVOKING=enabled_from_arguments\r"]
	if program == 'cygwin'
		let home = get(g:, 'asyncrun_cygwin', '')
		if home == ''
			call s:ErrorMsg('g:asyncrun_cygwin needs to set to cygwin root')
			return ''
		endif
		if !isdirectory(home)
			call s:Errormsg('path not find in g:asyncrun_cygwin')
			return ''
		endif
		let bash = s:path_join(home, 'bin/bash.exe')
		if !executable(bash)
			call s:ErrorMsg('invalid path in g:asyncrun_cygwin')
			return ''
		endif
		let mount = '/cygdrive'
		let prefix = 'CYGWIN_'
	elseif program == 'msys' || program == 'mingw32' || program == 'mingw64'
		let home = get(g:, 'asyncrun_msys', '')
		if home == ''
			call s:ErrorMsg('g:asyncrun_msys needs to set to msys root')
			return ''
		endif
		if !isdirectory(home)
			call s:ErrorMsg('path not find in g:asyncrun_msys')
			return ''
		endif
		let bash = s:path_join(home, 'usr/bin/bash.exe')
		if !executable(bash)
			call s:ErrorMsg('invalid path in g:asyncrun_msys')
			return ''
		endif
		let lines += ["set MSYSTEM=" . toupper(program) . "\r"]
		let mount = '/'
		let prefix = 'MSYS_'
	endif
	let bash = s:StringReplace(bash, '/', "\\")
	let path = asyncrun#path_win2unix(fnamemodify(script, ':p'), mount)
	let flag = ' --login ' . (get(a:opts, 'inter', '')? '-i' : '')
	let text = s:shellescape(bash) . flag . ' "' . path . '"'
	let lines += ['call ' . text . "\r"]
	call writefile(lines, tmpname)
	let command = a:opts.cmd
	let names = ['FILEPATH', 'FILENAME', 'FILEDIR', 'FILENOEXT']
	let names += ['PATHNOEXT', 'FILEEXT', 'FILETYPE', 'RELDIR']
	let names += ['RELNAME', 'CFILE', 'ROOT', 'HOME', 'CWD']
	let lines = ['#! /bin/sh']
	for name in names
		let src = a:opts.macros['VIM_' . name]
		let dst = asyncrun#path_win2unix(src, mount)
		let target = '$(' . prefix . name . ')'
		let command = s:StringReplace(command, target, dst)
		let lines += ['export '. prefix . name . "='" . dst . "'"]
	endfor
	let lines += ['unset VIM']
	let lines += ['unset VIMRUNTIME']
	let cwd = asyncrun#path_win2unix(getcwd(), mount)
	let lines += ["cd '" . cwd . "'"]
	let lines += [command]
	call writefile(lines, script)
	return tmpname
endfunc


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
	keepalt noautocmd windo call s:WindowCheck(0)
	keepalt noautocmd silent! exec ''.l:winnr.'wincmd w'
	if l:mode == 0
		if s:quickfix_open != 0
			silent! cclose
		endif
	elseif l:mode == 1
		if s:quickfix_open == 0
			keepalt exec 'botright copen '. ((a:size > 0)? a:size : ' ')
			keepalt wincmd k
		endif
	elseif l:mode == 2
		if s:quickfix_open == 0
			keepalt exec 'botright copen '. ((a:size > 0)? a:size : ' ')
			keepalt wincmd k
		else
			silent! cclose
		endif
	endif
	keepalt noautocmd windo call s:WindowCheck(1)
	keepalt noautocmd silent! exec ''.l:winnr.'wincmd w'
endfunc



"----------------------------------------------------------------------
" auto open quickfix window
"----------------------------------------------------------------------
if has("autocmd")
	function! s:check_quickfix()
		let height = get(g:, "asyncrun_open", 0)
		if exists('s:asyncrun_open')
			let height = s:asyncrun_open
		endif
		" echo 'height: '.height . ' ' .s:asyncrun_open
		if height > 0
			call asyncrun#quickfix_toggle(height, 1)
		endif
	endfunc
	augroup asyncrun_augroup
		au!
		au User AsyncRunStart call s:check_quickfix()
	augroup END
endif


" vim: set ts=4 sw=4 tw=78 noet :


