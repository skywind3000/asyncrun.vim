# Preface

This plugin takes the advantage of new APIs in Vim 8 (and NeoVim) to enable you to run shell commands in the background and read the output in the quickfix window in realtime:

- Easy to use, start your background command by `:AsyncRun` (just like old `!` cmd).
- The command is running in the background, no need to wait for the entire process to finish.
- Output is displayed in the quickfix window, errors are matched with `errorformat`.
- You can explore the error output immediately or keep working in vim while executing.
- Ring the bell or play a sound to notify your job is finished while you're focusing on editing.
- Customizable runners and command modifiers bring you the dark power of asyncrun.
- Fast and lightweight, just a single self-contained `asyncrun.vim` source file.  
- Provide corresponding user experience in vim, neovim, gvim, and macvim.

If that doesn't excite you, then perhaps this GIF screen capture below will change your mind.

【[README in Chinese | 中文文档](README-cn.md)】

# News

- 2021/12/15 new [extra runners](#extra-runners) to run command in a tmux, or floaterm window.
- 2020/02/18 [asynctasks](https://github.com/skywind3000/asynctasks.vim) uses asyncrun to introduce vscode's task system to vim.
- 2020/01/21 run command in internal terminal with `-mode=term` see [here](#internal-terminal).
- 2020/04/17 AsyncRun now supports command range, try: `:%AsyncRun cat`.

# Install

Install with vim-plug:

```VimL
Plug 'skywind3000/asyncrun.vim'
```

# Example

![](https://github.com/skywind3000/images/raw/master/p/asyncrun/screenshot.gif)

Remember to open vim's quickfix window by `:copen` (or setting  `g:asyncrun_open`) before invoking `AsyncRun`, otherwise, you will not see any output.

# Contents

<!-- TOC -->

- [Preface](#preface)
- [News](#news)
- [Install](#install)
- [Example](#example)
- [Contents](#contents)
  - [Tutorials](#tutorials)
  - [Manual](#manual)
    - [AsyncRun - Run shell command](#asyncrun---run-shell-command)
    - [AsyncStop - Stop the running job](#asyncstop---stop-the-running-job)
    - [Function (API)](#function-api)
    - [Settings](#settings)
    - [Variables](#variables)
    - [Autocmd](#autocmd)
    - [Project Root](#project-root)
    - [Running Modes](#running-modes)
    - [Internal Terminal](#internal-terminal)
    - [Terminal Name](#terminal-name)
    - [Quickfix window](#quickfix-window)
    - [Range support](#range-support)
  - [Advanced Topics](#advanced-topics)
    - [Extra Runners](#extra-runners)
    - [Customize Runner](#customize-runner)
    - [Command Modifier](#command-modifier)
    - [Requirements](#requirements)
    - [Cooperate with vim-fugitive:](#cooperate-with-vim-fugitive)
  - [Language Tips](#language-tips)
  - [More Topics](#more-topics)
  - [Cooperate with other Plugins](#cooperate-with-other-plugins)
- [History](#history)
- [Credits](#credits)

<!-- /TOC -->

## Tutorials

**Async run gcc to compile current file**

	:AsyncRun gcc "$(VIM_FILEPATH)" -o "$(VIM_FILEDIR)/$(VIM_FILENOEXT)"
	:AsyncRun g++ -O3 "$(VIM_FILEPATH)" -o "$(VIM_FILEDIR)/$(VIM_FILENOEXT)" -lpthread 

This command will run gcc in the background and output to the quickfix window in real time. Macro '`$(VIM_FILEPATH)`' stands for filename with full path and '`$(VIM_FILENOEXT)`' represents filename without extension.

**Async run make**

    :AsyncRun make
	:AsyncRun make -f makefile

Remember to open the quickfix window by `:copen` before using the `AsyncRun` command, if you don't open it, you will not see any output.

**Grep key word**

    :AsyncRun! grep -R -n word . 
    :AsyncRun! grep -R -n <cword> . 

when `!` is included, auto-scroll in quickfix will be disabled. `<cword>` represents current word under cursor.

**Compile go project**

    :AsyncRun go build "$(VIM_FILEDIR)"

Macro '`$(VIM_FILEDIR)`' stands for the current file dir. 

**Lookup man page**

    :AsyncRun! man -S 3:2:1 <cword>

**Git push**

    :AsyncRun git push origin master

**Git push from project root**

    :AsyncRun -cwd=<root> git push origin master

Use `-cwd=?` to specify the working directory, macro `<root>` or `$(VIM_ROOT)` represents current [Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root).

**Setup `<F7>` to compile file**

    :noremap <F7> :AsyncRun gcc "$(VIM_FILEPATH)" -o "$(VIM_FILEDIR)/$(VIM_FILENAME)" <cr> 

File name may contain spaces, therefore, it's safe to quote them.

**Run a python script**

    :AsyncRun -cwd=$(VIM_FILEDIR) python "$(VIM_FILEPATH)"

New option `-raw` will display the raw output (without matching to errorformat). Remember to put `let $PYTHONUNBUFFERED=1` in your `.vimrc` to disable python stdout buffering, see [here](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ#cant-see-the-realtime-output-when-running-a-python-script).

**Run a python script in a new terminal**

    :AsyncRun -cwd=$(VIM_FILEDIR) -mode=term -pos=TAB  python "$(VIM_FILEPATH)"

This will run python in the internal-terminal (vim 8.2 or nvim-0.4.0 is required) in a new tabpage.

**A good assistant to asyncrun**

[asynctasks.vim](https://github.com/skywind3000/asynctasks.vim) a plugin built upon asyncrun, an easy way to use asyncrun. It allows you to manage your building, testing, and deploying tasks in a global or project local configuration, and run them by their names.

## Manual

There are two vim commands: `:AsyncRun` and `:AsyncStop` to control async jobs.

### AsyncRun - Run shell command

```VimL
:AsyncRun[!] [options] {cmd} ...
```

Run shell command in the background and output to quickfix. when `!` is included, auto-scroll in quickfix will be disabled. Parameters are split by space, if a parameter contains space, it should be **quoted** or escaped as backslash + space (Unix only).

Macro variables in the parameters will be expanded before executing:

    $(VIM_FILEPATH)  - File name of current buffer with full path
    $(VIM_FILENAME)  - File name of current buffer without path
    $(VIM_FILEDIR)   - Full path of current buffer without the file name
    $(VIM_FILEEXT)   - File extension of current buffer
    $(VIM_FILENOEXT) - File name of current buffer without path and extension
    $(VIM_PATHNOEXT) - Current file name with full path but without extension
    $(VIM_CWD)       - Current directory
    $(VIM_RELDIR)    - File path relativize to current directory
    $(VIM_RELNAME)   - File name relativize to current directory 
    $(VIM_ROOT)      - Project root directory
    $(VIM_CWORD)     - Current word under cursor
    $(VIM_CFILE)     - Current filename under cursor
    $(VIM_GUI)       - Is running under gui ?
    $(VIM_VERSION)   - Value of v:version
    $(VIM_COLUMNS)   - How many columns in vim's screen
    $(VIM_LINES)     - How many lines in vim's screen
    $(VIM_SVRNAME)   - Value of v:servername for +clientserver usage
    $(VIM_PRONAME)   - Name of current project root directory
    $(VIM_DIRNAME)   - Name of current directory

Environment variables with same name, like `$VIM_FILENAME`, are also initialized. Thus your child process can access them with `getenv(xxx)` at any time.

Some macros variables have their short names starting with '`<`' :

    <cwd>   - Current directory
    <cword> - Current word under cursor
    <cfile> - Current file name under cursor
    <root>  - Project root directory

They are also acceptable. So, you can use both `$(VIM_ROOT)` or its alias `<root>` to represent [Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root) of the current file. Macro variables can be quoted with `"..."` in the command string when file name contains spaces (like normal shell command escaping), but they **should not** be quoted in the `-cwd=?` option.

There can be some options before your `[cmd]`:

| Option | Default | Description |
|:-|:-:|-|
| `-mode=?` | "async" | specify how to run the command as `-mode=?`, available modes are `"async"` (default), `"bang"` (with `!` command) and `"terminal"` (in internal terminal), see [running modes](#running-modes) for details. |
| `-cwd=?` | `unset` | initial directory (use current directory if unset), for example use `-cwd=<root>` to run commands in [project root directory](#project-root), or `-cwd=$(VIM_FILEDIR)` to run commands in current buffer's parent directory. |
| `-save=?` | 0 | use `-save=1` to save current file, `-save=2` to save all modified files before executing. |
| `-program=?` | `unset` | set to `make` to use `&makeprg`, `grep` to use `&grepprt` and `wsl` to execute commands in WSL (windows 10), see [command modifiers](#command-modifier). |
| `-post=?` | `unset` | vimscript to exec after job finished, spaces **must** be escaped to '\ ' |
| `-auto=?` | `unset` | event name to trigger `QuickFixCmdPre`/`QuickFixCmdPost` [name] autocmd. |
| `-raw` | `unset` | use raw output if present, and `&errorformat` will be ignored. |
| `-strip` | `unset` | remove the heading/trailing messages if it is present (omit command and "[Finished in ...]" message). |
| `-errorformat=?` | `unset` | errorformat for error matching, if it is unprovided, use current `&errorformat` value. Beware that `%` needs to be escaped into `\%`. |
| `-silent` | `unset` | provide `-silent` to prevent open quickfix window (will override `g:asyncrun_open` temporarily) |
| `-scroll=?` | `unset` | set to `0` to prevent quickfix auto-scrolling |
| `-once` | `unset` | provide to buffer all output and flush when job is finished, useful when there are multi-line patterns in your `errorformat` |
| `-encoding=?` | `unset` | specify command encoding independently (overshadow `g:asyncrun_encs`) |
| `-pos=?` | "bottom" | When using internal terminal with `-mode=term`, `-pos` is used to specify where to split the terminal window, it can be one of `"tab"`, `"curwin"`, `"top"`, `"bottom"`, `"left"`, `"right"` and `"external"`. And you can [customize new runners](#customize-runner) and pass runner's name to `-pos` option. |
| `-rows=num` | 0 | When using a horizontal split terminal, this value represents the height of terminal window. |
| `-cols=num` | 0 | When using a vertical split terminal, this value represents the width of terminal window. |
| `-focus=?` | 1 | set to `0` to prevent focus changing when `-mode=term` |
| `-hidden=?` | 0 | set to `1` to init `bufhidden` to `hide` for internal terminal, set to `0` to init `bufhidden` to `wipe` |
| `-listed=?` | 1 | when using `-mode=term`, set to 0 to hide the terminal in the buffer list |
| `-close` | `unset` | when using `-mode=term`, close the terminal automatically when terminal process is finished |

For the full list of the options, please see the [Command Specification](https://github.com/skywind3000/asyncrun.vim/wiki/Command-Specification).

All options must start with a minus and position **before** `[cmd]`. Since no shell command string starting with a minus. So they can be distinguished from shell command easily without any ambiguity. 

Don't worry if you do have a shell command starting with '-', Just put a placeholder `@` before your command to tell asyncrun explicitly: "stop parsing options now, the following string is all my command".

### AsyncStop - Stop the running job

```VimL
:AsyncStop[!]
```

stop the running job, when "!" is included, job will be stopped by signal KILL.

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
- g:asyncrun_qfid - use quickfix id to prevent interleaving output of concurrent plugins appending to the quickfix list.

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

When the previous job is still running or vim job slot is full, AsyncRun may fail. In this circumstance, `AsyncRunPre` will be invoked but `AsyncRunStart` and `AsyncRunStop` will have no chance to trigger.

### Project Root

Vim is lack of project management, as files usually belong to projects, you can do nothing to the project if you don't have any information about where the project locates. Inspired by CtrlP, this feature (new in version 1.3.12) is very useful when you've something to do with the whole project. 

Macro `<root>` or `$(VIM_ROOT)` in the command line or in the `-cwd` option will be expanded as the **Project Root Directory** of the current file:

```VimL
:AsyncRun make
:AsyncRun -cwd=<root> make
```

The first `make` will run in the vim's current directory (which `:pwd` returns), while the second one will run in the project root directory of current file. This feature is very useful when you have something (make / grep) to do with the whole project.

The project root is the nearest ancestor directory of the current file which contains one of these directories or files: `.svn`, `.git`, `.hg`, `.root` or `.project`. If none of the parent directories contains these root markers, the directory of the current file is used as the project root. The root markers can also be configurated, see [Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root).

### Running Modes

The default behavior is to run async command and output to quickfix window. However there is a `-mode=?` option can allow you specify how to run your command:

| mode | description |
|--|--|
| async | default behavior, run async command and output to quickfix window |
| bang | same as `!` |
| term | open a reusable internal terminal window and run your command |

For more information, please see [here](https://github.com/skywind3000/asyncrun.vim/wiki/Specify-how-to-run-your-command).

### Internal Terminal

AsyncRun is capable to run commands in Vim/NeoVim's internal terminal with the `-mode=term` option. You can specify how to open the terminal window by `-pos=?`, available positions are:

- `-pos=tab`: open the terminal in a new tab.
- `-pos=TAB`: open the terminal in a new tab on the left side.
- `-pos=curwin`: open the terminal in the current window.
- `-pos=top`: open the terminal above the current window.
- `-pos=bottom`: open the terminal below the current window.
- `-pos=left`: open the terminal on the left side.
- `-pos=right`: open the terminal on the right side.
- `-pos=hide`: don't open a window, run in background.
- `-pos=external`: use an external terminal (Windows & Gnome only).

Examples:

```VimL
:AsyncRun -mode=term -pos=tab python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=TAB -close -cwd=<root> lazygit
:AsyncRun -mode=term -pos=bottom -rows=10 python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=right -cols=80 python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=curwin python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=curwin -hidden python "$(VIM_FILEPATH)"
```

Internal terminal related options:

| Option | Default | Description |
|:-:|:-:|-|
| `-pos=?` | "bottom" | When using internal terminal with `-mode=term`, `-pos` is used to specify where to split the terminal window, it can be one of `"tab"`, `"curwin"`, `"top"`, `"bottom"`, `"left"`, `"right"` and `"external"`. |
| `-rows=num` | 0 | When using a horizontal split terminal, this value represents the height of terminal window. |
| `-cols=num` | 0 | When using a vertical split terminal, this value represents the width of terminal window. |
| `-focus=?` | 1 | set to `0` to prevent focus changing when `-mode=term` |
| `-close` | `unset` | when using `-mode=term`, close the terminal automatically when terminal process is finished |
| `-hidden=?` | 0 | set to `1` to setup `bufhidden` to `hide` for internal terminal |
| `-listed=?` | 1 | when using `-mode=term`, set to 0 to hide the terminal in the buffer list |

The `-pos` field accepts an uppercase `TAB`, to create a tab on the left of the current tab. When using internal terminal in a split window, AsyncRun will firstly reuse a finished previous terminal window if it exists, if not, a new terminal window will be created in given position. Tab based terminal can also be reusable if `-reuse` is provided.


### Terminal Name

There can be many commands running in the internal terminal, you can specify a name for each of them and receive it in `g:asyncrun_name`:

```VimL
:AsyncRun -mode=term -pos=hide -name=123 -post=echo\ g:asyncrun_name  ls -la
```

When this process finished, script defined in `-post` will be executed and your command name will display by `echo`. Another variable `g:asyncrun_code` stores exit code.

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


## Advanced Topics

AsyncRun provides enough flexibility and possibility to customize various details of how to run a command.

### Extra Runners

Besides the default quickfix and internal terminal mechanism, the user-defined runners allow you to run commands in any way you want. eg. in a new gnome-terminal window/tab, a floaterm window, or a side-by-side tmux split.

By default, AsyncRun is shipped with some popular runners:

| Runner | Description | Requirement | Link |
|-|-|-|-|
| `gnome` | run in a new gnome terminal | GNOME | [gnome.vim](autoload/asyncrun/runner/gnome.vim) |
| `gnome_tab` | run in a new gnome terminal tab | GNOME | [gnome_tab.vim](autoload/asyncrun/runner/gnome_tab.vim) |
| `xterm` | run in a xterm window | xterm | [xterm.vim](autoload/asyncrun/runner/xterm.vim) |
| `tmux` | run in a separated tmux split | [Vimux](https://github.com/preservim/vimux) | [tmux.vim](autoload/asyncrun/runner/tmux.vim) |
| `floaterm` | run in a new floaterm window | [floaterm](https://github.com/voldikss/vim-floaterm) | [floaterm.vim](autoload/asyncrun/runner/floaterm.vim) |
| `floaterm_reuse` | run in a reusable floaterm window | [floaterm](https://github.com/voldikss/vim-floaterm) | [floaterm_reuse.vim](autoload/asyncrun/runner/floaterm.vim) |
| `quickui` | run in a quickui window | [vim-quickui](https://github.com/skywind3000/vim-quickui) | [quickui.vim](autoload/asyncrun/runner/quickui.vim) |
| `termhelp` | run in terminal help | [vim-terminal-help](https://github.com/skywind3000/vim-terminal-help) | [termhelp.vim](autoload/asyncrun/runner/termhelp.vim) |
| `toggleterm` | run in a toggleterm window | [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | [toggleterm.vim](autoload/asyncrun/runner/toggleterm.vim) |
| `xfce` | run in a new xfce terminal | xfce4-terminal | [xfce.vim](autoload/asyncrun/runner/xfce.vim) |
| `konsole` | run in a new konsole terminal | KDE | [konsole.vim](autoload/asyncrun/runner/konsole.vim) |
| `macos` | run in a macOS system terminal | macOS | [macos.vim](autoload/asyncrun/runner/macos.vim) |
| `iterm` | run in a new iTerm2 tab | macOS + iTerm2 | [iterm.vim](autoload/asyncrun/runner/iterm.vim) |

e.g.

```VimL
:AsyncRun -mode=term -pos=gnome      ls -la
:AsyncRun -mode=term -pos=floaterm   ls -la
:AsyncRun -mode=term -pos=tmux       ls -la
```

Screenshot for `gnome` runner:

<!-- 
![](https://github.com/skywind3000/images/raw/master/p/asyncrun_extra/p_gnome_gvim.gif) 
-->

![](https://raw.githubusercontent.com/skywind3000/images/master/p/asyncrun/runner-gnome2.png)

When using `gnome`, `konsole`, or `xfce` runner in GVim, you get exactly the same experience like starting a command-line program from IDEs. 

When you use toggleterm2 and use the packer.nvim management plugin, you can set shortcut keys to specify the open window, such as:
```lua
	use({
		"skywind3000/asyncrun.vim",
		as = "asyncrun",
		config = function()
			require("asyncrun_toggleterm").setup({
				mapping = "<leader>tt",
				start_in_insert = false,
			})
		end,
	})
```

All runners are customizable, you can modify or define your own runners, see the next section "customize runner".

### Customize Runner

User-defined runners allow you to specify how the command will run by creating a new runner. It can be useful when you want your commands run in a tmux split or a new gnome-terminal window:

```VimL
function! MyRunner(opts)
    echo "command to run is: " . a:opts.cmd
endfunction

let g:asyncrun_runner = get(g:, 'asyncrun_runner', {})
let g:asyncrun_runner.test = function('MyRunner')
```

Then try:

```VimL
:AsyncRun -mode=term -pos=test ls -la $(VIM_FILEDIR)
```

When `-mode` is `term` and `-pos` can used to represent runner name.

Runner function has only one argument: `opts`, it contains the options extracted from `:AsyncRun` command line, and `opts.cmd` stores current command.

**Another way** to create a runner is to simply create a `.vim` file in the `autoload/asyncrun/runner/` folder of your run-time-path (see the [examples](autoload/asyncrun/runner)).

For more information, please visit project wiki: [customize runner](https://github.com/skywind3000/asyncrun.vim/wiki/Customize-Runner).


### Command Modifier

Command modifiers can be used to change your command before running:

```VimL
let g:asyncrun_program = get(g:, 'asyncrun_program', {})
let g:asyncrun_program.nice = { opts -> 'nice -5' . opts.cmd }
```

When you are using:

```VimL
:AsyncRun -program=nice ls -la
```

The command `ls -la` will be changed into `nice -5 ls -la`.

The `-program=msys`, `-program=wsl` are both implemented as a new command modifier it changes command `ls` into:

```
c:\windows\sysnative\wsl.exe ls
```

And replace any thing like `$(WSL_FILENAME)` and `$(WSL_FILEPATH)` in your command.


### Requirements

Vim 7.4.1829 is minimal version to support async mode. If you are use older versions, `g:asyncrun_mode` will fall back from `0/async` to `1/sync`. NeoVim 0.1.4 or later is also supported. 

Recommend to use Vim 8.0 or later. 

### Cooperate with vim-fugitive:

asyncrun.vim can cooperate with `vim-fugitive`, see [here](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#fugitive).

![](https://github.com/skywind3000/images/raw/master/p/asyncrun/cooperate_with_fugitive.gif)


## Language Tips

- [Better way for C/C++ developing with AsyncRun](https://github.com/skywind3000/asyncrun.vim/wiki/Better-way-for-C-and-Cpp-development-in-Vim-8)

## More Topics

- [Command Specification](https://github.com/skywind3000/asyncrun.vim/wiki/Command-Specification)
- [The project root directory of the current file](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root)
- [Additional examples (background ctags updating, pdf conversion, ...)](https://github.com/skywind3000/asyncrun.vim/wiki/Additional-Examples)
- [Notify user job finished by playing a sound](https://github.com/skywind3000/asyncrun.vim/wiki/Playing-Sound)
- [View progress in status line or vim airline](https://github.com/skywind3000/asyncrun.vim/wiki/Display-Progress-in-Status-Line-or-Airline)
- [Best practice with quickfix window](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-Best-Practice)
- [Scroll the quickfix window only if the cursor is on the last line](https://github.com/skywind3000/asyncrun.vim/wiki/Scroll-the-quickfix-window-only-if-cursor-is-on-the-last-line)
- [Replace old ':make' command with asyncrun](https://github.com/skywind3000/asyncrun.vim/wiki/Replace-old-make-command-with-AsyncRun)
- [Quickfix encoding problem when using Chinese or Japanese](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-encoding-problem-when-using-Chinese-or-Japanese)
- [Example for updating and adding cscope files](https://github.com/skywind3000/asyncrun.vim/wiki/Example-for-updating-and-adding-cscope)
- [Specify how to run your command](https://github.com/skywind3000/asyncrun.vim/wiki/Specify-how-to-run-your-command)
- [Customize Runners](https://github.com/skywind3000/asyncrun.vim/wiki/Customize-Runner)

Don't forget to read the [Frequently Asked Questions](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ).

## Cooperate with other Plugins

| Name | Description |
|------|-------------|
| [asynctasks](https://github.com/skywind3000/asynctasks.vim) | Introduce vscode's task system to vim (powered by AsyncRun). |
| [vim-fugitive](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#fugitive)  | perfect cooperation, asyncrun gets Gfetch/Gpush running in background |
| [errormarker](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins) | perfect cooperation, errormarker will display the signs on the error or warning lines |
| [airline](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#vim-airline) | very well, airline will display status of background jobs |
| [sprint](https://github.com/pedsm/sprint) | nice plugin who uses asyncrun to provide an IDE's run button to runs your code |



See: [Cooperate with famous plugins](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins)

# History

- 2.9.1 (2021-12-15): extra runners to run command in a tmux, or floaterm window.
- 2.6.2 (2020-03-08): change runner's argument from string to dict.
- 2.6.0 (2020-03-07): `-post` can be used in terminal mode.
- 2.5.5 (2020-03-07): "-mode=term -pos=tab" obeys "-focus=0" now.
- 2.5.3 (2020-03-02): new `-silent` option to prevent open quickfix, add [command modifier](https://github.com/skywind3000/asyncrun.vim/wiki/Command-Modifier).
- 2.5.0 (2020-02-29): refactor, remove useless codes, new command modifier `g:asyncrun_program`.
- 2.4.8 (2020-02-21): run with `:execute` if command is starting with colon.
- 2.4.7 (2020-02-21): new customizable runners by `g:asyncrun_runner`, see [customize runner](https://github.com/skywind3000/asyncrun.vim/wiki/Customize-Runner).
- 2.4.0 (2020-02-10): fixed internal terminal issue in msys.
- 2.3.0 (2020-02-10): new mode aliases, minor issue fix.
- 2.2.9 (2020-02-10): new terminal mode options: `-safe=1`, `-listed=0` and `-reuse`.
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

# Credits

Trying best to provide the most simply and convenience experience in the asynchronous-jobs. 

Author: skywind3000
Please vote it if you like it: 
http://www.vim.org/scripts/script.php?script_id=5431

