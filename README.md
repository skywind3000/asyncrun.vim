# Preface
This plugin allows you to run shell commands in background and output to quickfix window.

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

## Manual

There are two vim commands: `:AsyncRun` and `:AsyncStop` to control async jobs.

### AsyncRun - Run shell command

```VimL
:AsyncRun{!} [cmd] ...
```

run shell command in background and output to quickfix. when `!` is included, auto-scroll in quickfix will be disabled.

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
    $VIM_MODE      - Execute via 0:!, 1:makeprg, 2:system()
    $VIM_COLUMNS   - How many columns in vim's screen
    $VIM_LINES     - How many lines in vim's screen

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


