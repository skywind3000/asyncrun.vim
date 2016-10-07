# Preface
This plugin allows you to run shell commands in background and output to quickfix window in realtime.

## Install
Copy `asyncrun.vim` to your `~/.vim/plugin` or use Vundle to install it from `skywind3000/asyncrun.vim` .

## Tutorials

### Async run gcc to compile current file
	:AsyncRun gcc % -o %<
	:AsyncRun g++ -O3 % -o %< -lpthread 
This command will run gcc in the background and output to the quickfix window in realtime. Macro '`%`' stands for filename and '`%>`' represents filename without extension.

### Async run make
    :AsyncRun make
	:AsyncRun make -f makefile

### Grep key word 
    :AsyncRun! grep -R word . 
    :AsyncRun! grep -R <cword> . 
when `!` is included, auto-scroll in quickfix will be disabled. `<cword>` represents current word under cursor.

### Compile go project
    :AsyncRun go build %:p:h
Macro '`%:p:h`' stands for current file dir. 

### Lookup man page
    :AsyncRun! man -S 3:2:1 <cword>

### Git push
    :AsyncRun git push origin master

### Setup `<F7>` to compile file
    :noremap <F7> :AsyncRun gcc % -o %< <cr> 

## Manual

There are two vim commands: `:AsyncRun` and `:AsyncStop` to control async jobs.

### AsyncRun - Run shell command

```VimL
:AsyncRun{!} [cmd] ...
```

run shell command in background and output to quickfix. when `!` is included, auto-scroll in quickfix will be disabled. Parameters are splited by space, if a parameter contains space, it should be escaped as backslash + space (just like ex commands).

Parameters accept macros start with '`%`', '`#`' or '`<`' :

    %:p     - File name of current buffer with full path
    %:t     - File name of current buffer without path
    %:p:h   - File path of current buffer without file name
    %:e     - File extension of current buffer
    %:t:r   - File name of current buffer without path and extension
    %       - File name relativize to current directory
    %:h:.   - File path relativize to current directory
    <cwd>   - Current directory
    <cword> - Current word under cursor
    <cfile> - Current file name under cursor

Environment variables are set before executing:

    $VIM_FILEPATH  - File name of current buffer with full path
    $VIM_FILENAME  - File name of current buffer without path
    $VIM_FILEDIR   - Full path of current buffer without the file name
    $VIM_FILEEXT   - File extension of current buffer
    $VIM_FILENOEXT - File name of current buffer without path and extension
    $VIM_CWD       - Current directory
    $VIM_RELDIR    - File path relativize to current directory
    $VIM_RELNAME   - File name relativize to current directory 
    $VIM_CWORD     - Current word under cursor
    $VIM_CFILE     - Current filename under cursor
    $VIM_GUI       - Is running under gui ?
    $VIM_VERSION   - Value of v:version
    $VIM_COLUMNS   - How many columns in vim's screen
    $VIM_LINES     - How many lines in vim's screen

These environment variables wrapped by `$(...)` (eg. `$(VIM_FILENAME)`) will also be expanded in the parameters.

### AsyncStop - Stop the running job

```VimL
:AsyncStop{!}
```

stop the running job, when "!" is included, job will be stopped by signal KILL

### Settings:

    g:asyncrun_exit - script will be executed after finished
    g:asyncrun_bell - non-zero to ring a bell after finished
    g:asyncrun_mode - 0:async(require vim 7.4.1829) 1:sync 2:shell

### Variables:
    g:asyncrun_code - exit code
    g:asyncrun_status - 'running', 'success' or 'failure'

### Requirements:
    vim 7.4.1829 is minimal version to support async mode

## More Examples

### Translate markdown to pdf

```VimL
:AsyncRun pandoc --output $(VIM_FILENOEXT).pdf %:p
```

### Invoke chrome to open current html (non-windows)

```VimL
:AsyncRun chrome %
```

### Invoke chrome to open current html (windows)

```VimL
:AsyncRun C:\Program\ Files\ (x86)\Google\Chrome\Application\chrome.exe %
```

## Best practice with quickfix window

AsyncRun uses quickfix window to show job outputs, in order to see the outputs in realtime, you need open quickfix window at first by using `:copen` (see :help copen).

A better way is to use `:botright copen` when you have multiple vertical splitted windows.

You can leave quickfix window always open or you can make a function to toggle it when you need it.

Some times when you are opening the quickfix window, you just want to read the content in it. But `:copen` will move current window to the quickfix window, so you need save current window id before `:copen` and move to previous window after `:copen` finished. 

Spliting a new window in vim will get previous window scrolled, which is annoying when you  toggle quickfix window frequently. You can use vim builtin `winsaveview()` / `winrestview()` to prevent previous window scroll before and after `:copen`.

So there are some vimscript to write, if you want to use quickfix efficiently. Fortunately, there is an `asyncrun#quickfix_toggle(height)` function for you to toggle quickfix window in a convenience way.

Use F9 to toggle quickfix window rapidly:

```VimL
:noremap <F9> :call asyncrun#quickfix_toggle(8)<cr>
```

This function will:

* Open a new quickfix window if it hasn't been open in the current tab page.
* Close a quickfix window if it has already been open in the current tab page.
* Jump back to previous window when open/close the quickfix window
* Avoid automatic scroll in previous window when open a new quickfix window

Now you can have your F9 to toggle quickfix window open or close rapidly.

## Credits
Author: skywind3000
Please vote it if you like it: 
http://www.vim.org/scripts/script.php?script_id=5431

