# Preface
This plugin allows you to run shell commands in background and output to quickfix window in realtime.

## Install
Copy `asyncrun.vim` to your `~/.vim/plugin` or use Vundle to install it from `skywind3000/asyncrun.vim` .

## Tutorials

#### Async run gcc to compile current file
	:AsyncRun gcc % -o %<
	:AsyncRun g++ -O3 % -o %< -lpthread 
This command will run gcc in the background and output to the quickfix window in realtime. Macro '`%`' stands for filename and '`%>`' represents filename without extension.

#### Async run make
    :AsyncRun make
	:AsyncRun make -f makefile

#### Grep key word 
    :AsyncRun! grep -R word . 
    :AsyncRun! grep -R <cword> . 
when `!` is included, auto-scroll in quickfix will be disabled. `<cword>` represents current word under cursor.

#### Compile go project
    :AsyncRun go build %:p:h
Macro '`%:p:h`' stands for current file dir. 

#### Lookup man page
    :AsyncRun! man -S 3:2:1 <cword>

#### Git push
    :AsyncRun git push origin master

#### Setup `<F7>` to compile file
    :noremap <F7> :AsyncRun gcc % -o %< <cr> 

## Manual

There are two vim commands: `:AsyncRun` and `:AsyncStop` to control async jobs.

#### AsyncRun - Run shell command

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

#### AsyncStop - Stop the running job

```VimL
:AsyncStop{!}
```

stop the running job, when "!" is included, job will be stopped by signal KILL

#### Settings:

    g:asyncrun_exit - script will be executed after finished
    g:asyncrun_bell - non-zero to ring a bell after finished
    g:asyncrun_mode - 0:async(require vim 7.4.1829) 1:sync 2:shell

#### Variables:
    g:asyncrun_code - exit code
    g:asyncrun_status - 'running', 'success' or 'failure'

#### Requirements:
vim 7.4.1829 is minimal version to support async mode. If you are use older versions, `asyncrun_mode` will fall from `0/async/default` to `1/sync`.

## More

- [Additional examples (background ctags updating, pdf conversion, ...)](https://github.com/skywind3000/asyncrun.vim/wiki/Additional-Examples)
- [Notify user job finished by playing a sound](https://github.com/skywind3000/asyncrun.vim/wiki/Playing-Sound)
- [Best practice with quickfix windows](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-Best-Practice)
- [View progress in status line](https://github.com/skywind3000/asyncrun.vim/wiki/View-Progress-in-Status-Line)


## Credits
Author: skywind3000
Please vote it if you like it: 
http://www.vim.org/scripts/script.php?script_id=5431

