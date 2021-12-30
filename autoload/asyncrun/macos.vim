"======================================================================
"
" macos.vim - 
"
" Created by skywind on 2021/12/30
" Last Modified: 2021/12/30 15:52:58
"
"======================================================================

" vim: set ts=4 sw=4 tw=78 noet :


"----------------------------------------------------------------------
" script name
"----------------------------------------------------------------------
function! asyncrun#macos#script_name(name)
	let tmpname = fnamemodify(tempname(), ':h') . '/' . a:name
	return tmpname
endfunc


"----------------------------------------------------------------------
" write script 
"----------------------------------------------------------------------
function! asyncrun#macos#script_write(name, content)
	let tmpname = fnamemodify(tempname(), ':h') . '/' . a:name
	call writefile(a:content, tmpname)
	silent! call setfperm(tmpname, 'rwxrwxrws')
	return tmpname
endfunc


"----------------------------------------------------------------------
" return pause script
"----------------------------------------------------------------------
function! asyncrun#macos#pause_script()
	let lines = []
	if executable('bash')
		let pause = 'read -n1 -rsp "press any key to continue ..."'
		let lines += ['bash -c ''' . pause . '''']
	else
		let lines += ['echo "press enter to continue ..."']
		let lines += ['sh -c "read _tmp_"']
	endif
	return lines
endfunc


"----------------------------------------------------------------------
" write a scpt file 
"----------------------------------------------------------------------
function! asyncrun#macos#osascript(content, wait)
	let content = ['#! /usr/bin/osascript', '']
	let content += a:content
	let tmpname = asyncrun#macos#script_write('runner1.scpt', content)
	let cmd = '/usr/bin/osascript ' . shellescape(tmpname) 
	call system(cmd . ((a:wait)? '' : ' &'))
endfunc


"----------------------------------------------------------------------
" open system terminal
"----------------------------------------------------------------------
function! asyncrun#macos#open_system(title, script, profile)
	let content = ['#! /bin/sh']
	let content = ['clear']
	let content += [asyncrun#utils#set_title(a:title, 0)]
	let content += a:script
	let tmpname = asyncrun#macos#script_write('runner1.sh', content)
	let cmd = 'open -a Terminal ' . shellescape(tmpname)
	call system(cmd . ' &')
endfunc


"----------------------------------------------------------------------
" open terminal
"----------------------------------------------------------------------
function! asyncrun#macos#open_terminal(title, script, profile, active)
	let content = ['#! /bin/sh']
	let content += ['clear']
	let content += [asyncrun#utils#set_title(a:title, 0)]
	let content += a:script
	let tmpname = asyncrun#macos#script_write('runner2.sh', content)
	let osascript = []
	let osascript += ['tell application "Terminal"']
	let osascript += ['  if it is running then']
	let osascript += ['     do script "' . tmpname . '; exit"']
	let osascript += ['  else']
	let osascript += ['     do script "' . tmpname . '; exit" in window 1']
	let osascript += ['  end if']
	let x = '  set current settings of selected tab of '
	let x = x . 'window 1 to settings set "' . a:profile . '"'
	if a:profile != ''
		let osascript += [x]
	endif
	if a:active
		let osascript += ['  activate']
	endif
	let osascript += ['end tell']
	call asyncrun#macos#osascript(osascript, 1)
	return 1
endfunc


"----------------------------------------------------------------------
" utils 
"----------------------------------------------------------------------
function! s:osascript(...) abort
	call system('osascript'.join(map(copy(a:000), '" -e ".shellescape(v:val)'), ''))
	return !v:shell_error
endfunc

function! s:escape(string) abort
	return '"'.escape(a:string, '"\').'"'
endfunc

function! s:iterm_new_version() abort
	if !exists('s:iterm_is_new')
		let s:iterm_is_new = asyncrun#macos#iterm_new_version()
	endif
	return s:iterm_is_new
endfunc


"----------------------------------------------------------------------
" check version
"----------------------------------------------------------------------
function! asyncrun#macos#iterm_new_version() abort
	return s:osascript(
				\ 'on modernversion(version)',
				\   'set olddelimiters to AppleScript''s text item delimiters',
				\   'set AppleScript''s text item delimiters to "."',
				\   'set thearray to every text item of version',
				\   'set AppleScript''s text item delimiters to olddelimiters',
				\   'set major to item 1 of thearray',
				\   'set minor to item 2 of thearray',
				\   'set veryminor to item 3 of thearray',
				\   'if major < 2 then return false',
				\   'if major > 2 then return true',
				\   'if minor < 9 then return false',
				\   'if minor > 9 then return true',
				\   'if veryminor < 20140903 then return false',
				\   'return true',
				\ 'end modernversion',
				\ 'tell application "iTerm"',
				\   'if not my modernversion(version) then error',
				\ 'end tell')
endfunction


"----------------------------------------------------------------------
" spawn2
"----------------------------------------------------------------------
function! asyncrun#macos#iterm_spawn2(script, opts, activate) abort
	let script = asyncrun#utils#isolate(a:opts, [],
				\ asyncrun#utils#set_title(a:opts.title, a:opts.expanded), a:script)
	return s:osascript(
				\ 'if application "iTerm" is not running',
				\   'error',
				\ 'end if') && s:osascript(
				\ 'tell application "iTerm"',
				\   'tell the current terminal',
				\     'set oldsession to the current session',
				\     'tell (make new session)',
				\       'set name to ' . s:escape(a:opts.title),
				\       'set title to ' . s:escape(a:opts.expanded),
				\       'exec command ' . s:escape(script),
				\       a:opts.background ? 'select oldsession' : '',
				\     'end tell',
				\   'end tell',
				\   a:activate ? 'activate' : '',
				\ 'end tell')
endfunc


"----------------------------------------------------------------------
" spawn3 
"----------------------------------------------------------------------
function! asyncrun#macos#iterm_spawn3(script, opts, activate) abort
	let script = asyncrun#utils#isolate(a:opts, [],
				\ asyncrun#utils#set_title(a:opts.title, a:opts.expanded), a:script)
	" echom 'name: '. script
	return s:osascript(
				\ 'if application "iTerm" is not running',
				\   'error',
				\ 'end if') && s:osascript(
				\ 'tell application "iTerm"',
				\   'tell the current window',
				\     'set oldtab to the current tab',
				\     'set newtab to (create tab with default profile command ' . s:escape(script) . ')',
				\     'tell current session of newtab',
				\       'set name to ' . s:escape(a:opts.title),
				\       'set title to ' . s:escape(a:opts.expanded),
				\     'end tell',
				\     a:opts.background ? 'select oldtab' : '',
				\   'end tell',
				\   a:activate ? 'activate' : '',
				\ 'end tell')
endfunc


"----------------------------------------------------------------------
" spawn new iterm
"----------------------------------------------------------------------
function! asyncrun#macos#open_iterm(script, opts)
	let opts = {}
	let opts.title = get(a:opts, 'title', 'AsyncRun')
	let opts.expanded = get(a:opts, 'expanded', 1)
	let opts.background = get(a:opts, 'background', 0)
	let opts.file = asyncrun#macos#script_name(expand('%:t'))
	let active = get(a:opts, 'active', 1)
	let script = deepcopy(a:script)
	if s:iterm_new_version()
		return asyncrun#macos#iterm_spawn3(script, opts, active)
	else
		return asyncrun#macos#iterm_spawn2(script, opts, active)
	endif
endfunc

function! asyncrun#macos#iterm_activate(pid)
	if s:iterm_new_version()
		let tty = matchstr(system('ps -p '.a:pid), 'tty\S\+')
		if !empty(tty)
			return s:osascript(
						\ 'if application "iTerm" is not running',
						\   'error',
						\ 'end if') && s:osascript(
						\ 'tell application "iTerm"',
						\   'activate',
						\   'tell the current window',
						\     'repeat with atab in tabs',
						\       'repeat with asession in sessions',
						\         'if (tty) = ' . tty,
						\         'select atab',
						\       'end repeat',
						\     'end repeat',
						\   'end tell',
						\ 'end tell')
		endif
	else
		let tty = matchstr(system('ps -p '.a:pid), 'tty\S\+')
		if !empty(tty)
			return s:osascript(
						\ 'if application "iTerm" is not running',
						\   'error',
						\ 'end if') && s:osascript(
						\ 'tell application "iTerm"',
						\   'activate',
						\   'tell the current terminal',
						\      'select session id "/dev/'.tty.'"',
						\   'end tell',
						\ 'end tell')
		endif
	endif
endfunction


"----------------------------------------------------------------------
" start_command
"----------------------------------------------------------------------
function! asyncrun#macos#start_command(runner, opts)
	let script = []
	let script += ['cd ' . shellescape(getcwd())]
	let script += [a:opts.cmd]
	let op = {}
	let op.title = a:opts.cmd
	let op.active = get(a:opts, 'focus', 1)
	let op.background = get(a:opts, 'focus', 1)? 0 : 1
	if get(a:opts, 'close', 0) == 0
		let script += ['echo ""']
		let script += asyncrun#macos#pause_script()
	endif
	if a:runner == 'terminal'
		let p = get(a:opts, 'option', '')
		return asyncrun#macos#open_terminal(op.title, script, p, op.active)
	elseif a:runner == 'iterm' || a:runner == 'iterm2'
		return asyncrun#macos#open_iterm(script, op)
	endif
endfunc


"----------------------------------------------------------------------
" check environ
"----------------------------------------------------------------------
function! asyncrun#macos#check()
	if has('mac') || has('macunix') || has('osx') || has('osxdarwin')
		return 1
	elseif has('gui_macvim') || has('macvim')
		return 1
	endif
	return 0
endfunc


