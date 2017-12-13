## Preface
This plugin takes the advantage of new apis in Vim 8 (and NeoVim) to enable you to run shell commands in background and read output in the quickfix window in realtime:

- Easy to use, just start your background command by `:AsyncRun` (just like old "!" cmd).
- Command is done in the background, no need to wait for the entire process to finish.
- Output are displayed in the quickfix window, errors are matched with `errorformat`.
- You can explore the error output immediately or keep working in vim while executing.
- Ring the bell or play a sound to notify you job finished while you're focusing on editing.
- Fast and lightweight, just a single self-contained `asyncrun.vim` source file.  
- Provide corresponding user experience in vim, neovim, gvim and macvim.

If that doesn't excite you, then perhaps this GIF screen capture below will change your mind.

## News

- 2017/07/12 new option `-raw=1` to use raw output (not match with the errorformat)
- 2017/06/26 new option `-cwd=<root>` to change working directory to project root, see [here]() 
- 2016/11/01 `asyncrun.vim` can now cooperate with `errormarker` now.
- 2016/10/17 Glad to announce that `asyncrun.vim` supports NeoVim now.
- 2016/10/15 `asyncrun.vim` can cooperate with `vim-fugitive`, see the bottom of the README.

## Install
Copy `asyncrun.vim` to your `~/.vim/plugin` or use Vundle to install it from `skywind3000/asyncrun.vim` .

## Example

![](https://raw.githubusercontent.com/skywind3000/asyncrun.vim/master/doc/screenshot.gif)

## Tutorials

#### Async run gcc to compile current file
	:AsyncRun gcc % -o %<
	:AsyncRun g++ -O3 "%" -o "%<" -lpthread 
This command will run gcc in the background and output to the quickfix window in realtime. Macro '`%`' stands for filename and '`%<`' represents filename without extension.

#### Async run make
    :AsyncRun make
	:AsyncRun make -f makefile

#### Grep key word 
    :AsyncRun! grep -R word . 
    :AsyncRun! grep -R <cword> . 
when `!` is included, auto-scroll in quickfix will be disabled. `<cword>` represents current word under cursor.

#### Compile go project
    :AsyncRun go build "%:p:h"
Macro '`%:p:h`' stands for current file dir. 

#### Lookup man page
    :AsyncRun! man -S 3:2:1 <cword>

#### Git push
    :AsyncRun git push origin master

#### Setup `<F7>` to compile file
    :noremap <F7> :AsyncRun gcc "%" -o "%<" <cr> 

File name may contain spaces, therefore, it's safe to quote them.

#### Run a python script
    :AsyncRun -raw python %

New option `-raw` will display the raw output (without matching to errorformat), you need the latest AsyncRun (after 1.3.13) to use this option. 

## Manual

There are two vim commands: `:AsyncRun` and `:AsyncStop` to control async jobs.

#### AsyncRun - Run shell command

```VimL
:AsyncRun[!] [options] {cmd} ...
```

run shell command in background and output to quickfix. when `!` is included, auto-scroll in quickfix will be disabled. Parameters are splited by space, if a parameter contains space, it should be **quoted** or escaped as backslash + space (unix only).


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
	<root>  - Project root directory

Environment variables are set before executing:

    $VIM_FILEPATH  - File name of current buffer with full path
    $VIM_FILENAME  - File name of current buffer without path
    $VIM_FILEDIR   - Full path of current buffer without the file name
    $VIM_FILEEXT   - File extension of current buffer
    $VIM_FILENOEXT - File name of current buffer without path and extension
    $VIM_CWD       - Current directory
    $VIM_RELDIR    - File path relativize to current directory
    $VIM_RELNAME   - File name relativize to current directory 
	$VIM_ROOT      - Project root directory
    $VIM_CWORD     - Current word under cursor
    $VIM_CFILE     - Current filename under cursor
    $VIM_GUI       - Is running under gui ?
    $VIM_VERSION   - Value of v:version
    $VIM_COLUMNS   - How many columns in vim's screen
    $VIM_LINES     - How many lines in vim's screen
	$VIM_SVRNAME   - Value of v:servername for +clientserver usage 

These environment variables wrapped by `$(...)` (eg. `$(VIM_FILENAME)`) will also be expanded in the parameters. Macro `$(VIM_ROOT)` and `<root>` (new in version 1.3.12) indicate the [Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root) of the current file. 

There can be some options before your `[cmd]`:

    -mode=0/1/2 - start mode: 0(async, default), 1(:make), 2(:!)
    -cwd=?      - initial directory, (use current directory if unset)
    -save=0/1/2 - non-zero to save current(1) or all(2) modified buffer(s) before executing.
    -program=?  - set to `make` to use `&makeprg`, `grep` to use `&grepprg` 
	-post=?     - vimscript to exec after this job finished, spaces **must** be escaped to '\ '
	-auto=?     - event name to trigger "QuickFixCmdPre/QuickFixCmdPost [name]" autocmd
	-raw=1      - use raw output (output will not match with the errorformat) 

All options must start with a minus and position **before** `[cmd]`. Since no shell command  string starts with a minus. So they can be distinguished from shell command easily without any ambiguity. 

Don't worry if you do have a shell command starting with '-', Just put a placeholder `@` before your command to tell asyncrun explicitly: "stop parsing options now, the following string is all my command".


#### AsyncStop - Stop the running job

```VimL
:AsyncStop[!]
```

stop the running job, when "!" is included, job will be stopped by signal KILL

#### Settings:

- g:asyncrun_exit - script will be executed after finished
- g:asyncrun_bell - non-zero to ring a bell after finished
- g:asyncrun_mode - 0:async(require vim 7.4.1829) 1:sync 2:shell
- g:asyncrun_encs - set shell encoding if it's different from `&encoding`, see [encoding](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-encoding-problem-when-using-Chinese-or-Japanese)
- g:asyncrun_trim - non-zero to trim the empty lines in the quickfix window.
- g:asyncrun_auto - event name to trigger QuickFixCmdPre/QuickFixCmdPost, see [FAQ](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ#can-asyncrunvim-trigger-an-autocommand-quickfixcmdpost-to-get-some-plugin-like-errormaker-processing-the-content-in-quickfix-)
- g:asyncrun_timer - how many messages should be inserted into quickfix every 100ms interval.

#### Variables:
- g:asyncrun_code - exit code
- g:asyncrun_status - 'running', 'success' or 'failure'

#### Autocmd:

```VimL
autocmd User AsyncRunPre   - triggered before executing
autocmd User AsyncRunStart - triggered after starting successfully
autocmd User AsyncRunStop  - triggered when job finished
```

Note, `AsyncRunPre` is always likely to be invoked, but `AsyncRunStart` and `AsyncRunStop` will only be invoked if the job starts successfully. 

When previous job is still running or vim job slot is full, AsyncRun may fail. In this circumstance, `AsyncRunPre` will be invoked but `AsyncRunStart` and `AsyncRunStop` will have no chance to trigger.

#### Project Root

Vim is lack of project management, as files usually belong to projects, you can do nothing to the project if you don't have any information about where the project locates. Inspired by CtrlP, this feature (new in version 1.3.12) is very useful when you've something to do with the whole project. 

Macro `<root>` or `$(VIM_ROOT)` in the command line or in the `-cwd` option will be expanded as the **Project Root Directory** of the current file:

```VimL
:AsyncRun make
:AsyncRun -cwd=<root> make
```

The first `make` will run in the vim's current directory (which `:pwd` returns), while the second one will run in the project root directory of current file. This feature is very useful when you have something (make / grep) to do with the whole project.

The project root is the nearest ancestor directory of the current file which contains one of these directories or files: `.svn`, `.git`, `.hg`, `.root` or `.project`. If none of the parent directories contains these root markers, the directory of the current file is used as the project root. The root markers can also be configurated, see [Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root).

#### Requirements:
Vim 7.4.1829 is minimal version to support async mode. If you are use older versions, `g:asyncrun_mode` will fall back from `0/async` to `1/sync`. NeoVim 0.1.4 or later is also supported. 

Recommend to use Vim 8.0 or later. 

#### Cooperate with vim-fugitive:

asyncrun.vim can cooperate with `vim-fugitive`, see [here](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#fugitive).

![](https://raw.githubusercontent.com/skywind3000/asyncrun.vim/master/doc/cooperate_with_fugitive.gif)


## More

- [Additional examples (background ctags updating, pdf conversion, ...)](https://github.com/skywind3000/asyncrun.vim/wiki/Additional-Examples)
- [Notify user job finished by playing a sound](https://github.com/skywind3000/asyncrun.vim/wiki/Playing-Sound)
- [View progress in status line or vim airline](https://github.com/skywind3000/asyncrun.vim/wiki/Display-Progress-in-Status-Line-or-Airline)
- [Best practice with quickfix window](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-Best-Practice)
- [Scroll the quickfix window only if the cursor is on the last line](https://github.com/skywind3000/asyncrun.vim/wiki/Scroll-the-quickfix-window-only-if-cursor-is-on-the-last-line)
- [Replace old ':make' command with asyncrun](https://github.com/skywind3000/asyncrun.vim/wiki/Replace-old-make-command-with-AsyncRun)
- [Quickfix encoding problem when using Chinese or Japanese](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-encoding-problem-when-using-Chinese-or-Japanese)
- [Example for updating and adding cscope files](https://github.com/skywind3000/asyncrun.vim/wiki/Example-for-updating-and-adding-cscope)
- [The project root directory of the current file](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root)

Don't forget to read the [Frequently Asked Questions](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ).

## Cooperate with other Plugins

| Name | Description |
|------|-------------|
| [vim-fugitive](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#fugitive)  | perfect cooperation, asyncrun gets Gfetch/Gpush running in background |
| [errormarker](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins) | perfect cooperation, errormarker will display the signs on the error or warning lines |
| [airline](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#vim-airline) | very well, airline will display status of background jobs |
| [sprint](https://github.com/pedsm/sprint) | nice plugin who uses asyncrun to provide an IDE's run button to runs your code |
| [netrw](https://github.com/skywind3000/asyncrun.vim/wiki/Get-netrw-using-asyncrun-to-save-remote-files) | netrw can save remote files on background now. Experimental, take your own risk | 


See: [Cooperate with famous plugins](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins)

## History

- 1.3.19 (2017-12-13): new option `g:asyncrun_skip` to skip specific autocmd.
- 1.3.18 (2017-12-12): fixed: windo breaks commands (especially in neovim).
- 1.3.17 (2017-08-06): fixed: process hang when mode is 5.
- 1.3.16 (2017-08-05): fixed: g:asyncrun_mode issue (Joel Taylor)
- 1.3.15 (2017-07-30): fixed: remove trailing new line in neovim.
- 1.3.14 (2017-07-27): improve asyncrun#get_root(), allow user indicate the rootmarkers
- 1.3.13 (2017-07-12): new option (-raw) to use raw output (not match with the errorformat).
- 1.3.12 (2017-06-25): new macro `<root>` or $(VIM_ROOT) to indicate project root directory.
- 1.3.11 (2017-05-19): new option (-save=2) to save all modified files.
- 1.3.10 (2017-05-04): remove trailing `^M` in NeoVim 2.0 on windows 
- 1.3.9 (2016-12-23): minor bugs fixed, improve performance and compatibility.
- 1.3.8 (2016-11-17): new autocmd AsyncRunPre/AsyncRunStart/AsyncRunStop, fixed cmd line window conflict. 
- 1.3.7 (2016-11-13): new option 'g:asyncrun_timer' to prevent gui freeze by massive output.
- 1.3.6 (2016-11-08): improve performance in quickfix_toggle, fixed small issue in bell ringing.
- 1.3.5 (2016-11-02): new option "g:asyncrun_auto" to trigger QuickFixCmdPre/QuickFixCmdPost.
- 1.3.4 (2016-10-28): new option "g:asyncrun_local" to use local value of errorformat rather the global value. 
- 1.3.3 (2016-10-21): prevent job who reads stdin from getting hanging, fixed an issue in fast exiting jobs.
- 1.3.2 (2016-10-19): new "-post" option to run a vimscript after the job finished
- 1.3.1 (2016-10-18): fixed few issues of arguments passing in different modes
- 1.3.0 (2016-10-17): add support to neovim, better CJK characters handling.
- 1.2.0 (2016-10-16): refactor, correct arguments parsing, cmd options and &makeprg supports
- 1.1.1 (2016-10-13): use the vim native &shell and &shellcmdflag config to execute commands.
- 1.1.0 (2016-10-12): quickfix window scroll only if cursor is on the last line
- 1.0.3 (2016-10-10): reduce quickfix output latency.
- 1.0.2 (2016-10-09): fixed an issue in replacing macros in parameters.
- 1.0.1 (2016-10-07): Add a convenient way to toggle quickfix window (asyncrun#quickfix_toggle)
- 1.0.0 (2016-09-21): can fall back to sync mode to compatible older vim versions.
- 0.0.3 (2016-09-15): new arguments now accept environment variables wrapped by $(...)
- 0.0.2 (2016-09-12): some improvements and more documents for a tiny tutorial.
- 0.0.1 (2016-09-08): improve arguments parsing
- 0.0.0 (2016-08-24): initial version

## Credits
Trying best to provide the most simply and convenience experience in the asynchronous-jobs. 

Author: skywind3000
Please vote it if you like it: 
http://www.vim.org/scripts/script.php?script_id=5431

