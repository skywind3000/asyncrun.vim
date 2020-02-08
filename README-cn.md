# 特性说明

本插件使用 Vim 8 / NeoVim 的异步机制，让你在后台运行 shell 命令，并将结果实时显示到 Vim 的 Quickfix 窗口中：

- 使用简单，输入 `:AsyncRun {command}` 即可在后台执行你的命令（和传统的 `!` 命令类似）。
- 命令会在后台运行，不会阻碍 Vim 操作，不需要等待整个命令结束你就继续操作 Vim。
- 进程的输出会实时的显示在下方的 quickfix 窗口里，编译信息会自动同 `errorformat` 匹配。
- 你可以立即浏览错误输出，或者在任务执行的同时继续编辑你的文件。
- 当任务结束时，播放一个铃声提醒你，避免你眼睛盯着代码忘记编译已经结束。
- 丰富的参数和配置项目，可以自由指定运行方式，命令初始目录，autocmd 触发等。
- 除了异步任务+quickfix 外，还提供多种运行方式，比如一键在内置终端里运行命令。
- 快速和轻量级，无其他依赖，仅仅单个 `asyncrun.vim` 源文件。
- 同时为 Vim/NeoVim/GVim/MacVim 提供一致的用户体验。

If that doesn't excite you, then perhaps this GIF screen capture below will change your mind.

# 新闻

- 2020/01/21 使用 `-mode=term` 在内置终端里运行你的命令，见 [这里](https://github.com/skywind3000/asyncrun.vim/wiki/Specify-how-to-run-your-command).
- 2018/04/17 支持 range 了，可以 Vim 中选中一段文本，然后 `:%AsyncRun cat`。
- 2018/04/16 更好的支持 makeprg/grepprg，允许他俩包含 `%` 和 `$*` 了。
- 2018/03/11 新增配置 [g:asyncrun_open](#quickfix-window) 设置后可以自动打开 quickfix 窗口。
- 2017/07/12 新增参数 `-raw=1` 启用后会跳过 errorformat 匹配，直接在 qf 中显示原始文本。
- 2017/06/26 新增参数 `-cwd=<root>` 可以指定在项目的根目录运行命令，见 [project-root](#project-root).
- 2016/11/01 `asyncrun.vim` 可以同 `errormarker` 协同。
- 2016/10/17 高兴的宣布，`asyncrun.vim` 支持 NeoVim 了。
- 2016/10/15 `asyncrun.vim` 可以同 `vim-fugitive` 协作，见 README 底部。

# 安装

拷贝 `asyncrun.vim` 到你的 `~/.vim/plugin` 目录，或者用 vim-plug/Vundle 之类的包管理工具从 `skywind3000/asyncrun.vim` 位置安装。

# 例子

![](https://raw.githubusercontent.com/skywind3000/asyncrun.vim/master/doc/screenshot.gif)

演示了：异步调用 gcc 进行编译，异步运行 grep。

# 内容目录

<!-- TOC -->

- [使用例子](#使用例子)
- [使用手册](#使用手册)
    - [AsyncRun - 运行 shell 命令](#asyncrun---运行-shell-命令)
    - [AsyncStop - Stop the running job](#asyncstop---stop-the-running-job)
    - [Function (API)](#function-api)
    - [Settings](#settings)
    - [Variables](#variables)
    - [Autocmd](#autocmd)
    - [Project Root](#project-root)
    - [Running modes](#running-modes)
    - [Internal Terminal](#internal-terminal)
    - [Quickfix window](#quickfix-window)
    - [Range support](#range-support)
    - [Requirements](#requirements)
    - [Cooperate with vim-fugitive:](#cooperate-with-vim-fugitive)
- [Language Tips](#language-tips)
- [More Topics](#more-topics)
- [Cooperate with other Plugins](#cooperate-with-other-plugins)
- [History](#history)
- [Credits](#credits)

<!-- /TOC -->

## 使用例子

**异步运行 gcc 编译当前的文件**

	:AsyncRun gcc % -o %<
	:AsyncRun g++ -O3 "%" -o "%<" -lpthread 

上面的命令会在后台运行 gcc 命令，并把编译输出实时显示到 quickfix 窗口中，标记 '`%`' 代表当前正在编辑的文件名，而 '`%<`' 代表去掉扩展名的文件名。

**异步运行 make**

    :AsyncRun make
	:AsyncRun make -f makefile

记得在执行 `AsyncRun` 命令前，提前使用 `copen` 命令打开 quickfix 窗口，不然你看不到任何内容。

**Grep 关键字**

    :AsyncRun! grep -n -R word . 
    :AsyncRun! grep -n -R <cword> . 
    
当 `AsyncRun` 命令后面追加一个叹号时，quickfix 将不会自动滚动，保持在第一行。`<cword>` 代表光标下面的单词。

**编译 go 项目**

    :AsyncRun go build "%:p:h"

标记 '`%:p:h`' 表示当前文件的所在目录。 

**查看 man page**

    :AsyncRun! man -S 3:2:1 <cword>

**异步 git push**

    :AsyncRun git push origin master

**初始化 `<F7>` 来编译文件**

    :noremap <F7> :AsyncRun gcc "$(VIM_FILEPATH)" -o "$(VIM_FILEDIR)/$(VIM_FILENAME)" <cr> 

文件可能会包含空格，所以正式使用推荐用 `$(...)` 的宏形，后面有表格说明可用宏。

**运行 Python 脚本**

    :AsyncRun -raw python %

使用 `-raw` 参数可以在 quickfix 中显示原始输出（不进行 errorformat 匹配），记得用 `let $PYTHONNUNBUFFERED=1` 来禁止 python 的行缓存，这样可以实时查看结果。很多程序在后台运行时都会将输出全部缓存住直到调用 flush 或者程序结束，python 可以设置该变量来禁用缓存，让你实时看到输出，而无需每次手工调用 `sys.stdout.flush()`。

关于缓存的更多说明见 [这里](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ#cant-see-the-realtime-output-when-running-a-python-script).

## 使用手册

本插件有且只提供了两条命令：`:AsyncRun` 以及 `:AsyncStop` 来控制你的任务。

### AsyncRun - 运行 shell 命令

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
    $VIM_PATHNOEXT - Current file name with full path but without extension
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

| Option | Default Value | Description |
|-|-|-|
| `-mode=?` | "async" | specify how to run the command as `-mode=?`, available modes are `"async"` (default), `"terminal"` (in internal terminal), `"bang"` (with `!` command) and `"os"` (in external os terminal), see [running modes](#running-modes) for details. |
| `-cwd=?` | `unset` | initial directory (use current directory if unset), for example use `-cwd=<root>` to run commands in [project root directory](#project-root), or `-cwd=$(VIM_FILEDIR)` to run commands in current buffer's parent directory. |
| `-save=?` | 0 | use `-save=1` to save current file, `-save=2` to save all modified files before executing |
| `-program=?` | `unset` | set to `make` to use `&makeprg`, `grep` to use `&grepprt` and `wsl` to execute commands in WSL (windows 10) |
| `-post=?` | `unset` | vimscript to exec after job finished, spaces **must** be escaped to '\ ' |
| `-auto=?` | `unset` | event name to trigger `QuickFixCmdPre`/`QuickFixCmdPost` [name] autocmd 
| `-raw` | `unset` | use raw output if provided, and `&errorformat` will be ignored. |
| `-strip` | `unset` | remove the heading/trailing messages if provided (omit command and "[Finished in ...]" message). |
| `-pos=?` | "bottom" | When using internal terminal with `-mode=term`, `-pos` is used to specify where to split the terminal window, it can be one of `"tab"`, `"curwin"`, `"top"`, `"bottom"`, `"left"` and `"right"` |
| `-rows=num` | 0 | When using a horizontal split terminal, this value represents the height of terminal window. |
| `-cols=num` | 0 | When using a vertical split terminal, this value represents the width of terminal window. |

All options must start with a minus and position **before** `[cmd]`. Since no shell command  string starts with a minus. So they can be distinguished from shell command easily without any ambiguity. 

Don't worry if you do have a shell command starting with '-', Just put a placeholder `@` before your command to tell asyncrun explicitly: "stop parsing options now, the following string is all my command".

### AsyncStop - Stop the running job

```VimL
:AsyncStop[!]
```

stop the running job, when "!" is included, job will be stopped by signal KILL

### Function (API)

Function form is convenient for vimscript:

```VimL
:call asyncrun#run(bang, opts, command)
```

parameters:

- `bang`: an empty string or a single bang character `"!"`, same as bang sign in `AsyncRun!`.
- `opts`: a dictionary contains: `mode`, `cwd`, `raw` and `errorformat` etc.
- `command`: the shell command you want to execute.

### Settings

- g:asyncrun_exit - script will be executed after finished.
- g:asyncrun_bell - non-zero to ring a bell after finished.
- g:asyncrun_mode - specify how to run your command, see [here](https://github.com/skywind3000/asyncrun.vim/wiki/Specify-how-to-run-your-command).
- g:asyncrun_encs - set shell encoding if it's different from `&encoding`, see [encoding](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-encoding-problem-when-using-Chinese-or-Japanese).
- g:asyncrun_trim - non-zero to trim the empty lines in the quickfix window.
- g:asyncrun_auto - event name to trigger QuickFixCmdPre/QuickFixCmdPost, see [FAQ](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ#can-asyncrunvim-trigger-an-autocommand-quickfixcmdpost-to-get-some-plugin-like-errormaker-processing-the-content-in-quickfix-).
- g:asyncrun_open - above zero to open quickfix window at given height after command starts.
- g:asyncrun_save - non-zero to save current(1) or all(2) modified buffer(s) before executing.
- g:asyncrun_timer - how many messages should be inserted into quickfix every 100ms interval.
- g:asyncrun_wrapper - enable to setup a command prefix.
- g:asyncrun_stdin - non-zero to enable stdin (useful for cmake on windows).

For more information of above options, please visit **[option details](https://github.com/skywind3000/asyncrun.vim/wiki/Options)**.


### Variables

- g:asyncrun_code - exit code
- g:asyncrun_status - 'running', 'success' or 'failure'

### Autocmd

```VimL
autocmd User AsyncRunPre   - triggered before executing
autocmd User AsyncRunStart - triggered after starting successfully
autocmd User AsyncRunStop  - triggered when job finished
```

Note, `AsyncRunPre` is always likely to be invoked, but `AsyncRunStart` and `AsyncRunStop` will only be invoked if the job starts successfully. 

When previous job is still running or vim job slot is full, AsyncRun may fail. In this circumstance, `AsyncRunPre` will be invoked but `AsyncRunStart` and `AsyncRunStop` will have no chance to trigger.

### Project Root

Vim is lack of project management, as files usually belong to projects, you can do nothing to the project if you don't have any information about where the project locates. Inspired by CtrlP, this feature (new in version 1.3.12) is very useful when you've something to do with the whole project. 

Macro `<root>` or `$(VIM_ROOT)` in the command line or in the `-cwd` option will be expanded as the **Project Root Directory** of the current file:

```VimL
:AsyncRun make
:AsyncRun -cwd=<root> make
```

The first `make` will run in the vim's current directory (which `:pwd` returns), while the second one will run in the project root directory of current file. This feature is very useful when you have something (make / grep) to do with the whole project.

The project root is the nearest ancestor directory of the current file which contains one of these directories or files: `.svn`, `.git`, `.hg`, `.root` or `.project`. If none of the parent directories contains these root markers, the directory of the current file is used as the project root. The root markers can also be configurated, see [Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root).

### Running modes

The default behavior is to run async command and output to quickfix window. However there is a `-mode=?` option can allow you specify how to run your command:

| mode | description |
|--|--|
| async | default behavior, run async command and output to quickfix window |
| bang | same as `!` |
| term | open a reusable built-in terminal window and run your command |
| os | (windows only) open a new cmd.exe window and run your command in it |

For more information, please see [here](https://github.com/skywind3000/asyncrun.vim/wiki/Specify-how-to-run-your-command).

### Internal Terminal

AsyncRun is capable to run commands in Vim/NeoVim's internal terminal with the `-mode=term` option. You can specify how to open the terminal window by `-pos=?`, available positions are:

- `-pos=tab`: open the terminal in a new tab.
- `-pos=curwin`: open the terminal in the current window.
- `-pos=top`: open the terminal above the current window.
- `-pos=bottom`: open the terminal below the current window.
- `-pos=left`: open the terminal on the left side.
- `-pos=right`: open the terminal on the right side.

Examples:

```VimL
:AsyncRun -mode=term -pos=tab python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=bottom -rows=10 python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=right -cols=80 python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=curwin python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=curwin -hidden python "$(VIM_FILEPATH)"
```

When using a split (`-pos` is one of `top`, `bottom`, `left` and `right`), AsyncRun will firstly reuse a finished previous terminal window if it exists, if not, AsyncRun will create a new terminal window in given position.

### Quickfix window

AsyncRun displays its output in quickfix window, so if you don't use `:copen {height}` to open quickfix window, you won't see any output. For convenience there is an option `g:asyncrun_open` for you:

    :let g:asyncrun_open = 8

Setting `g:asyncrun_open` to 8 will open quickfix window automatically at 8 lines height after command starts.

### Range support

AsyncRun can take a range of lines in the current buffer as command's stdin after version `1.3.27`. You can try:

```VimL
:%AsyncRun cat
```

the whole buffer will be the input of command `cat`. you will see the content of your current buffer will be output to the quickfix window.


```VimL
:10,20AsyncRun python
```

text between line 10-20 will be taken as the stdin of python. code in that range will be executed by python and the output will display in the quickfix window.

```VimL
:'<,'>AsyncRun -raw perl
```

The visual selection (line-wise) will be taken as stdin.


### Requirements

Vim 7.4.1829 is minimal version to support async mode. If you are use older versions, `g:asyncrun_mode` will fall back from `0/async` to `1/sync`. NeoVim 0.1.4 or later is also supported. 

Recommend to use Vim 8.0 or later. 

### Cooperate with vim-fugitive:

asyncrun.vim can cooperate with `vim-fugitive`, see [here](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#fugitive).

![](https://raw.githubusercontent.com/skywind3000/asyncrun.vim/master/doc/cooperate_with_fugitive.gif)


## Language Tips

- [Better way for C/C++ developing with AsyncRun](https://github.com/skywind3000/asyncrun.vim/wiki/Better-way-for-C-and-Cpp-development-in-Vim-8)

## More Topics

- [Additional examples (background ctags updating, pdf conversion, ...)](https://github.com/skywind3000/asyncrun.vim/wiki/Additional-Examples)
- [Notify user job finished by playing a sound](https://github.com/skywind3000/asyncrun.vim/wiki/Playing-Sound)
- [View progress in status line or vim airline](https://github.com/skywind3000/asyncrun.vim/wiki/Display-Progress-in-Status-Line-or-Airline)
- [Best practice with quickfix window](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-Best-Practice)
- [Scroll the quickfix window only if the cursor is on the last line](https://github.com/skywind3000/asyncrun.vim/wiki/Scroll-the-quickfix-window-only-if-cursor-is-on-the-last-line)
- [Replace old ':make' command with asyncrun](https://github.com/skywind3000/asyncrun.vim/wiki/Replace-old-make-command-with-AsyncRun)
- [Quickfix encoding problem when using Chinese or Japanese](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-encoding-problem-when-using-Chinese-or-Japanese)
- [Example for updating and adding cscope files](https://github.com/skywind3000/asyncrun.vim/wiki/Example-for-updating-and-adding-cscope)
- [The project root directory of the current file](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root)
- [Specify how to run your command](https://github.com/skywind3000/asyncrun.vim/wiki/Specify-how-to-run-your-command)

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

- 2.2.6 (2020-02-06): new: parameter `-hidden` when using `-mode=term` to set `bufhidden` to `hidden`.
- 2.2.5 (2020-02-05): more safe to start a terminal.
- 2.2.4 (2020-02-05): exit when starting terminal failed in current window with `-pos=curwin`.
- 2.2.3 (2020-02-05): new `-program=wsl` to run command in wsl (windows 10 only).
- 2.2.2 (2020-02-05): new `-pos=curwin` to open terminal in current window.
- 2.2.1 (2020-01-20): set noreletivenumber for terminal window.
- 2.2.0 (2020-01-18): new `-focus=0` option for `-mode=term` to prevent focus change.
- 2.1.9 (2020-01-12): polish `-mode=term`, omit `number` and `signcolunm` in terminal.
- 2.1.8 (2020-01-11): new options `errorformat` in `asyncrun#run(...)`.
- 2.1.4 (2020-01-09): correct command encoding on windows and fixed minor issues.
- 2.1.0 (2020-01-09): new mode `-mode=term` to run command in a reusable terminal window.
- 2.0.8 (2019-04-28): handle `tcd` (introduced in 8.1.1218). use grepformat when `-program=grep`.
- 2.0.7 (2019-01-27): restore `g:asyncrun_stdin` because rg will break if stdin is pipe.
- 2.0.6 (2019-01-26): more adaptive to handle stdin and remove 'g:asyncrun_stdin'
- 2.0.5 (2019-01-14): enable stdin by default on windows (fix cmake stdin warning on windows).
- 2.0.4 (2019-01-13): new option `g:asyncrun_stdin`, set to 1 to enable stdin .
- 2.0.3 (2019-01-04): new macro `$VIM_PATHNOEXT` (by @PietroPate)
- 2.0.2 (2018-12-25): new `-strip` and `-append` option to control quickfix (by @bennyyip)
- 2.0.1 (2018-04-29): new option `g:asyncrun_save` to save files.
- 2.0.0 (2018-04-27): improve neovim compatability, handle `tcd` command in neovim.
- 1.3.27 (2018-04-17): AsyncRun now supports range, try: `:%AsyncRun cat`
- 1.3.26 (2018-04-16): new option `g:asyncrun_wrapper` to enable setup a command prefix
- 1.3.25 (2018-04-16): handle makeprg/grepprg correctly, accept `%` and `$*` macros. close [#96](https://github.com/skywind3000/asyncrun.vim/issues/96) [#84](https://github.com/skywind3000/asyncrun.vim/issues/84) and [#35](https://github.com/skywind3000/asyncrun.vim/issues/35)
- 1.3.24 (2018-04-13): remove trailing ^M on windows.
- 1.3.23 (2018-04-03): back compatible to vim 7.3, can fall back to mode 1 in old vim.
- 1.3.22 (2018-03-11): new option `g:asyncrun_open` to open quickfix window automatically at given height.
- 1.3.21 (2018-03-02): fixed: float point reltime issues
- 1.3.20 (2018-02-08): fixed: [Incorrect background job status](https://github.com/skywind3000/asyncrun.vim/issues/25) (@antoinemadec)
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

