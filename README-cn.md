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

具体运行效果，可以看下面的 GIF 截屏。

# 新闻

- 2021/12/15 新的 runner 机制，扩展 AsyncRun 的能力，在 tmux/floaterm 中运行命令。
- 2020/02/18 [asynctasks](https://github.com/skywind3000/asynctasks.vim) 使用 AsyncRun 为 Vim 提供了一套类似 vscode 的任务机制，更好的构建、测试和运行项目。
- 2020/01/21 使用 `-mode=term` 在内置终端里运行你的命令，见 [内置终端](#内置终端)。
- 2018/04/17 支持 range 了，可以 Vim 中选中一段文本，然后 `:%AsyncRun cat`。

# 安装

拷贝 `asyncrun.vim` 到你的 `~/.vim/plugin` 目录，或者用 vim-plug/Vundle 之类的包管理工具从 `skywind3000/asyncrun.vim` 位置安装。

# 例子

![](https://github.com/skywind3000/images/raw/master/p/asyncrun/screenshot.gif)

异步运行 gcc/grep 的演示，别忘记在运行前使用 `:copen` 命令打开 vim 的 quickfix 窗口，否则你看不到具体输出，还可以设置 `g:asyncrun_open=6` 来自动打开。

# 内容目录

<!-- TOC -->

- [特性说明](#特性说明)
- [新闻](#新闻)
- [安装](#安装)
- [例子](#例子)
- [内容目录](#内容目录)
  - [快速入门](#快速入门)
  - [使用手册](#使用手册)
    - [AsyncRun - 运行 shell 命令](#asyncrun---运行-shell-命令)
    - [AsyncStop - 停止正在运行的任务](#asyncstop---停止正在运行的任务)
    - [函数接口](#函数接口)
    - [全局设置](#全局设置)
    - [全局变量](#全局变量)
    - [Autocmd](#autocmd)
    - [项目根目录](#项目根目录)
    - [运行模式](#运行模式)
    - [内置终端](#内置终端)
    - [Quickfix window](#quickfix-window)
    - [Range 支持](#range-支持)
  - [高级话题](#高级话题)
    - [额外的 Runner](#额外的-runner)
    - [自定义 Runner](#自定义-runner)
    - [命令修改器](#命令修改器)
    - [运行需求](#运行需求)
    - [同 fugitive 协作](#同-fugitive-协作)
  - [语言参考](#语言参考)
  - [更多话题](#更多话题)
- [插件协作](#插件协作)
- [Credits](#credits)

<!-- /TOC -->

## 快速入门

**异步运行 gcc 编译当前的文件**

	:AsyncRun gcc "$(VIM_FILEPATH)" -o "$(VIM_FILEDIR)/$(VIM_FILENOEXT)"
	:AsyncRun g++ -O3 "$(VIM_FILEPATH)" -o "$(VIM_FILEDIR)/$(VIM_FILENOEXT)" -lpthread 

上面的命令会在后台运行 gcc 命令，并把编译输出实时显示到 quickfix 窗口中，标记 '`$(VIM_FILEPATH)`' 代表当前正在编辑的文件名，而 '`$(VIM_FILENOEXT)`' 代表去掉扩展名的文件名。

**异步运行 make**

    :AsyncRun make
	:AsyncRun make -f makefile

记得在执行 `AsyncRun` 命令前，提前使用 `copen` 命令打开 quickfix 窗口，不然你看不到任何内容。

**Grep 关键字**

    :AsyncRun! grep -n -R word . 
    :AsyncRun! grep -n -R <cword> . 
    
当 `AsyncRun` 命令后面追加一个叹号时，quickfix 将不会自动滚动，保持在第一行。`<cword>` 代表光标下面的单词。

**编译 go 项目**

    :AsyncRun go build "$(VIM_FILEDIR)"

标记 '`$(VIM_FILEDIR)`' 表示当前文件的所在目录。 

**查看 man page**

    :AsyncRun! man -S 3:2:1 <cword>

**异步 git push**

    :AsyncRun git push origin master
    
**项目目录 git push**

    :AsyncRun -cwd=<root> git push origin master

使用 `-cwd=?` 来指定运行目录，变量 `<root>` 或者 `$(VIM_ROOT)` 代表当前项目的 [Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root).

**初始化 `<F7>` 来编译文件**

    :noremap <F7> :AsyncRun gcc "$(VIM_FILEPATH)" -o "$(VIM_FILEDIR)/$(VIM_FILENAME)" <cr> 

文件可能会包含空格，所以用引号引起来更安全，就像命令行输入文件名一样。

**运行 Python 脚本**

    :AsyncRun -cwd=$(VIM_FILEDIR) python "$(VIM_FILEPATH)"

使用 `-raw` 参数可以在 quickfix 中显示原始输出（不进行 errorformat 匹配），记得用 `let $PYTHONNUNBUFFERED=1` 来禁止 python 的行缓存，这样可以实时查看结果。很多程序在后台运行时都会将输出全部缓存住直到调用 flush 或者程序结束，python 可以设置该变量来禁用缓存，让你实时看到输出，而无需每次手工调用 `sys.stdout.flush()`。

关于缓存的更多说明见 [这里](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ#cant-see-the-realtime-output-when-running-a-python-script).

**在新终端里运行 Python**

    :AsyncRun -cwd=$(VIM_FILEDIR) -mode=term -pos=TAB  python "$(VIM_FILEPATH)"

可以在一个新的 tab 里用内置终端运行 Python (vim 8.2 or nvim-0.4.0)。

**使用 AsyncRun 的助手**

[asynctasks.vim](https://github.com/skywind3000/asynctasks.vim) 是一个使用 asyncrun 提供任务管理的插件，帮助你管理一系列 building, testing 和 deploying 的任务，并且方便的调度他们。

## 使用手册

本插件有且只提供了两条命令：`:AsyncRun` 以及 `:AsyncStop` 来控制你的任务。

### AsyncRun - 运行 shell 命令

```VimL
:AsyncRun[!] [options] {cmd} ...
```

在后台运行 shell 命令，并把结果实时输出到 quickfix 窗口，当命令后跟随一个 `!` 时，quickfix 将不会自动滚动。参数用空格分隔，如果某项参数包含空格，那么需要双引号引起来（unix 下面还可以使用反斜杠加空格）。

下面这些宏变量在运行时会展开成具体值：

    $(VIM_FILEPATH)  - 当前 buffer 的文件名全路径
    $(VIM_FILENAME)  - 当前 buffer 的文件名（没有前面的路径）
    $(VIM_FILEDIR)   - 当前 buffer 的文件所在路径
    $(VIM_FILEEXT)   - 当前 buffer 的扩展名
    $(VIM_FILENOEXT) - 当前 buffer 的主文件名（没有前面路径和后面扩展名）
    $(VIM_PATHNOEXT) - 带路径的主文件名（$VIM_FILEPATH 去掉扩展名）
    $(VIM_CWD)       - 当前 Vim 目录
    $(VIM_RELDIR)    - 相对于当前路径的文件名
    $(VIM_RELNAME)   - 相对于当前路径的文件路径
    $(VIM_ROOT)      - 当前 buffer 的项目根目录
    $(VIM_CWORD)     - 光标下的单词
    $(VIM_CFILE)     - 光标下的文件名
    $(VIM_GUI)       - 是否在 GUI 下面运行？
    $(VIM_VERSION)   - Vim 版本号
    $(VIM_COLUMNS)   - 当前屏幕宽度
    $(VIM_LINES)     - 当前屏幕高度
    $(VIM_SVRNAME)   - v:servername 的值
    $(VIM_PRONAME)   - 项目名称（Project Root 目录的名称）
    $(VIM_DIRNAME)   - 当前目录的名称

同名环境变量也会被初始化，比如 `$VIM_FILENAME` 这样的，可以被命令进程读取。

参数还可以接受以 '`<`' 开头的别名：

    <cwd>   - 当前路径
    <cword> - 光标下的单词
    <cfile> - 光标下的文件名
    <root>  - 当前 buffer 的项目根目录

宏 `$(VIM_ROOT)` 或者 `<root>` 指代当前文件的[项目根目录](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root)。

调用 `AsyncRun` 时，在具体的命令前面可以有一些 `-` 开头的参数：

| 参数 | 默认值 | 含义 |
|-|-|-|
| `-mode=?` | "async" | 用 `-mode=?` 的形式指定运行模式可选模式有： `"async"` (默认模式，后台运行输出到 quickfix), `"bang"` (使用 `!` 命令运行) 以及 `"terminal"` (在内建终端运行)， 具体查看 [运行模式](#运行模式)。 |
| `-cwd=?` | `未设置` | 命令初始目录（没有设置就用 vim 当前目录），比如  `-cwd=<root>` 就能在 [项目根目录](#项目根目录) 运行命令，或者 `-cwd=$(VIM_FILEDIR)` 就能在当前文件所在目录运行命令。 |
| `-save=?` | 0 | 运行命令前是否保存文件，`-save=1` 保存当前文件，`-save=2` 保存所有修改过的文件 |
| `-program=?` | `未设置` | 设置成 `make` 可以用 `&makeprg`，设置成 `grep` 可以使用 `&grepprt`，而设置成 `wsl` 则可以在 WSL 中运行命令 （需要 Windows 10）|
| `-post=?` | `未设置` | 命令结束后自动运行的 vimscript，如果包含空格则要用反斜杠加空格代替。 |
| `-auto=?` | `未设置` | 出发 autocmd `QuickFixCmdPre`/`QuickFixCmdPost` 后面的名称。 |
| `-raw` | `未设置` | 如果提供了，就输出原始内容，忽略 `&errorformat` 过滤。 |
| `-strip` | `未设置` | 过滤收尾消息 (头部命令名称以及尾部 "[Finished in ...]" 信息)。|
| `-pos=?` | "bottom" | 当用 `-mode=term` 在内置终端运行命令时， `-pos` 用于指定内置终端窗口位置， 可以设置成 `"tab"`，`"curwin"`，`"top"`，`"bottom"`，`"left"` ，`"right"` 和 `"external"`。|
| `-rows=num` | 0 | 内置终端窗口的高度。|
| `-cols=num` | 0 | 内置终端窗口的宽度。|
| `-errorformat=?` | `未设置` | 用于 quickfix 中匹配错误输出的格式字符串，如果未提供，则使用当前 `&errorformat` 的值。注意 `%` 需要转写成 `\%`。 |
| `-focus=?` | 1 | 设置成 `0` 可以防止使用内置终端时窗口焦点切换。 |
| `-hidden=?` | 0 | 设置成 `1` 可以将内置终端的 `bufhidden` 初始化为 `hide` |
| `-silent` | `未设置` | 设置该参数可以避免打开 quickfix 窗口 (临时覆盖 `g:asyncrun_open`) |
| `-close` | `未设置` | 使用 `-mode=term` 时，如果 term 进程结束就自动关闭窗口 |
| `-scroll=?` | `未设置` | 设置为 `0` 可以禁止 quickfix 自动滚动 |
| `-once=?` | `未设置` | 设置为 `1` 会缓存所有后台输出，直到进程结束一次性显示（类似 Dispatch 的行为），当 `errorformat` 中设置了多行模式后比较有用。 |
| `-encoding=?` | `未设置` | 独立设置命令编码，如果提供的话会覆盖 `g:asyncrun_encs` 的全局配置 |

所有的这些配置参数都必须放在具体 shell 命令 **前面**，因为没有任何 shell 命令使用 `-` 开头，因此很容易区分哪里是命令的开始。如果你确实有一条 shell 命令是减号开头的，那么为了明显区别参数和命令，可以在命令前面放一个 `@` 符号，那么 AsyncRun 在解析参数时碰到 `@` 就知道参数结束了，后面都是命令。


### AsyncStop - 停止正在运行的任务

```VimL
:AsyncStop[!]
```

没有叹号时，使用 `TERM` 信号尝试终止后台任务，有叹号时会使用 `KILL` 信号来终止。

### 函数接口

本插件提供了函数形式的接口，方便你在 vimscript 中调用：

```VimL
:call asyncrun#run(bang, opts, command)
```

参数说明:

- `bang`：空字符串或者内容是一个叹号的字符串 `"!"` 和 `AsyncRun!` 的叹号作用一样。
- `opts`：参数字典，包含：`mode`, `cwd`, `raw` 以及 `errorformat` 等。
- `command`：具体要运行的命令。

### 全局设置

- g:asyncrun_exit - 命令结束时自动运行的 vimscript。
- g:asyncrun_bell - 命令结束后是否响铃？
- g:asyncrun_mode - 全局的默认[运行模式](#运行模式).
- g:asyncrun_encs - 如果系统编码和 Vim 内部编码 `&encoding`，不一致，那么在这里设置一下，具体见 [编码设置](https://github.com/skywind3000/asyncrun.vim/wiki/Quickfix-encoding-problem-when-using-Chinese-or-Japanese)。
- g:asyncrun_trim - 设置成非零的话剔除空白行。
- g:asyncrun_auto - 用于触发 QuickFixCmdPre/QuickFixCmdPost 的 autocmd 名称，见 [FAQ](https://github.com/skywind3000/asyncrun.vim/wiki/FAQ#can-asyncrunvim-trigger-an-autocommand-quickfixcmdpost-to-get-some-plugin-like-errormaker-processing-the-content-in-quickfix-)。
- g:asyncrun_open - 大于零的话会在运行时自动打开高度为具体值的 quickfix 窗口。
- g:asyncrun_save - 全局设置，运行前是否保存文件，1是保存当前文件，2是保存所有修改过的文件。
- g:asyncrun_timer - 每 100ms 处理多少条消息，默认为 25。
- g:asyncrun_wrapper - 命令前缀，默认为空，比如可以设置成 `nice`。
- g:asyncrun_stdin - 设置成非零的话，允许 stdin，比如 cmake 在 windows 下要求 stdin 为打开状态。
- g:asyncrun_qfid - 使用 quickfix id 来防止附加到 quickfix 列表的并发插件的交错输出。

更多配置内容，见 **[这里](https://github.com/skywind3000/asyncrun.vim/wiki/Options)**.


### 全局变量

- g:asyncrun_code - 命令返回码。
- g:asyncrun_status - 命令状态：'running', 'success' or 'failure' 可以用于设置到 statusline。

### Autocmd

```VimL
autocmd User AsyncRunPre   - 运行前触发
autocmd User AsyncRunStart - 命令成功开始了触发
autocmd User AsyncRunStop  - 命令结束时触发
```

注意，`AsyncRunPre` 一般都会被触发，但是 `AsyncRunStart` 和 `AsyncRunStop` 只会在任务成功开始的情况下才会被触发。

比如当前任务未结束，AsyncRun 会失败。在这种情况下，`AsyncRunPre` 会被触发，但是 `AsyncRunStart` 和 `AsyncRunStop` 无法触发。

### 项目根目录

Vim 缺乏项目管理，然而日常编辑的一个个文件，大部分都会从属于某个项目。如果你缺乏项目相关的信息，你就很难针对项目做点什么事情。参考 CtrlP 插件的设计，AsyncRun 使用 `root markers` 的机制来识别项目的根路径，当前文件所在的项目目录是该文件的最近一级包含 `root marker` 的父目录（默认为`.git`, `.svn`, `.root` 以及 `.project`），如果递归到根目录还没找到标识文件，那么会用当前文件所在目录代替。

在命令或者 `-cwd=?` 参数中使用 `<root>` 或者 `$(VIM_ROOT)` 来表示当前文件的 **项目根目录**，比如：

```VimL
:AsyncRun make
:AsyncRun -cwd=<root> make
```

第一个 `make` 命令会在 vim 的当前路径（可以用 `:pwd` 命令查看）下面执行，而第二个 `make` 命令会在当前的项目根目录下面执行。当你要对整个项目做点什么的时候（比如 make/grep），这个特性会非常有用。

更多信息参考：[Project Root](https://github.com/skywind3000/asyncrun.vim/wiki/Project-Root).

### 运行模式

AsyncRun 可以用 `-mode=?` 参数指定运行模式，不指定的话，将会用默认模式，在后台运行，并将输出实时显示到 quickfix 窗口，然而你还可以用 `-mode=?` 设置成下面几种运行模式：

| 模式 | 说明 |
|--|--|
| async | 默认模式，在后台运行命令，并将输出实时显示到 quickfix 窗口。 |
| bang | 用 Vim 传统的 `:!` 命令执行。 |
| term | 使用一个可复用的内部终端执行命令。 |

更多信息，见 [这里](https://github.com/skywind3000/asyncrun.vim/wiki/Specify-how-to-run-your-command).

### 内置终端

最新版 AsyncRun 除了在 quickfix 窗口里运行程序外，还增加了对内置终端的支持，有几个目的：

- 让你调试程序更方便，特别是你的程序需要交互时（读取用户输入），原来的 quickfix 窗口就不够用了。
- 直接用原有的 `:term xxx` 很难裸用，Vim/NeoVim 体验不一致，参数不一致，窗口无法复用，不能指定初始位置。
- 不需要每次都到另外一个 tmux 窗口下去跑你的程序。

如果 `AsyncRun` 命令后加了一个 `-mode=term` 参数，那么将会在 Vim 内置终端中运行命令，在该模式下，还可以提供一个 `-pos=?` 来指定终端窗口的位置：

- `-pos=tab`: 在新的 tab 中打开终端。
- `-pos=curwin`: 在当前窗口打开终端。
- `-pos=top`: 在上方打开终端。
- `-pos=bottom`: 在下方打开终端。
- `-pos=left`: 在左边打开终端。
- `-pos=right`: 在右边打开终端。
- `-pos=hide`: 不打开终端窗口，隐藏在后台运行。
- `-pos=external`: 使用外部终端（仅支持 Windows）。

建议 Windows 下面直接用 `-pos=external`。

例子:

```VimL
:AsyncRun -mode=term -pos=tab python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=bottom -rows=10 python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=right -cols=80 python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=curwin python "$(VIM_FILEPATH)"
:AsyncRun -mode=term -pos=curwin -hidden python "$(VIM_FILEPATH)"
```

当你用内置终端时，AsyncRun 会先检查是否有之前已经运行结束的终端窗口，有的话会复用，没有的话，才会新建一个 split。可以使用 `-pos=TAB`，大写的 tab 表示在当前 tab 的左边打开内置终端 tab。

除了 quickfix 和内置终端外，AsyncRun 还可以在另一个 tmux 窗口或者一个新的 gnome-terminal 窗口/tab 中运行程序，感兴趣可以参考 [自定义运行模式](https://github.com/skywind3000/asyncrun.vim/wiki/Customize-Runner) 中的例子。

### Quickfix window

默认运行模式下，AsyncRun 会在 quickfix 窗口中显示任务的输出，所以如果你事先没有用 `:copen {height}` 打开 quickfix 窗口，你将会看不到任何内容。方便起见，引入了一个 `g:asyncrun_open` 的全局配置，如果设置成非零：

    :let g:asyncrun_open = 8

那么在运行命令前，会自动按照 8 行的高度打开 quickfix 窗口。

### Range 支持

AsyncRun 可以指定一个当前 buffer 的文本范围，用作命令的 stdin 输入，比如：

```VimL
:%AsyncRun cat
```

那么当前文件的整个内容将会作为命令 `cat` 的标准输入传递过去，这个命令运行后，quickfix 窗口内将会显示当前文件的所有内容。


```VimL
:10,20AsyncRun python
```

使用当前 buffer 的第 10 行到 20 行的内容作为命令 python 的标准输入，可以用来执行一小段 python 代码，并在 quickfix 展现结果。

```VimL
:'<,'>AsyncRun -raw perl
```

选中区域的文本 (行模式) 作为标准输入。

## 高级话题

AsyncRun 提供足够的可能性和灵活性让你指定运行命令的各处细节。

### 额外的 Runner

除去默认的 Quickfix 和 internal-terminal 外，AsyncRun 还允许你自定义各种 runner 来为命令提供新的运行方式，本项目已经自带一批 runner：

| Runner | 描 述 | 依 赖 | 链 接 |
|-|-|-|-|
| `gnome` | 在新的 Gnome 终端里运行 | GNOME | [gnome.vim](autoload/asyncrun/runner/gnome.vim) |
| `gnome_tab` | 在另一个 Gnome 终端的 Tab 里运行 | GNOME | [gnome_tab.vim](autoload/asyncrun/runner/gnome_tab.vim) |
| `xterm` | 在新的 xterm 窗口内运行 | xterm | [xterm.vim](autoload/asyncrun/runner/xterm.vim) |
| `tmux` | 在一个新的 tmux 的 pane 里运行 | [Vimux](https://github.com/preservim/vimux) | [tmux.vim](autoload/asyncrun/runner/tmux.vim) |
| `floaterm` | 在 floaterm 的新窗口里运行 | [floaterm](https://github.com/voldikss/vim-floaterm) | [floaterm.vim](autoload/asyncrun/runner/floaterm.vim) |
| `floaterm_reuse` | 再一个可复用的 floaterm 窗口内运行 | [floaterm](https://github.com/voldikss/vim-floaterm) | [floaterm_reuse.vim](autoload/asyncrun/runner/floaterm.vim) |
| `quickui` | 在 quickui 的浮窗里运行 | [vim-quickui](https://github.com/skywind3000/vim-quickui) | [quickui.vim](autoload/asyncrun/runner/quickui.vim) |
| `toggleterm` | 使用 toggleterm 窗口运行 | [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | [toggleterm.vim](autoload/asyncrun/runner/toggleterm.vim) |
| `toggleterm2` | 使用自定义 toggleterm 窗口运行 | [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | [toggleterm.vim](autoload/asyncrun/runner/toggleterm2.vim) |
| `xfce` | 在 xfce 终端中运行 | xfce4-terminal | [xfce.vim](autoload/asyncrun/runner/xfce.vim) |
| `konsole` | 在 KDE 的自带终端里运行 | KDE | [konsole.vim](autoload/asyncrun/runner/konsole.vim) |
| `macos` | 在 macOS 的系统终端内运行 | macOS | [macos.vim](autoload/asyncrun/runner/macos.vim) |
| `iterm` | 在 iTerm2 的 tab 中运行 | macOS + iTerm2 | [iterm.vim](autoload/asyncrun/runner/iterm.vim) |

比如：

```VimL
:AsyncRun -mode=term -pos=gnome      ls -la
:AsyncRun -mode=term -pos=floaterm   ls -la
:AsyncRun -mode=term -pos=tmux       ls -la
```

下面是 `gnome` 这个 runner 的效果：

![](https://raw.githubusercontent.com/skywind3000/images/master/p/asyncrun/runner-gnome2.png)

当你在 GVim 中使用 `gnome`, `konsole` 或者 `xfce` 之类的 runner 来运行程序，你会觉得就跟 IDE 里面启动命令行程序是一样的感觉。

当你使用toggleterm2这个runner，并且使用packer.nvim管理插件的时候，可以设置快捷键指定打开的窗口，比如:
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
所有 runner 皆可定制，你可以很方便的开发新 runner，详细见下一节 “自定义 Runner”。

### 自定义 Runner

你可能还希望更多的执行方式，比如在新的 tmux 或者 gnore-terminal 的窗口里运行，AsyncRun 允许你自定义 runner：

```VimL
function! MyRunner(opts)
    echo "command to run is: " . a:opts.cmd
endfunction

let g:asyncrun_runner = get(g:, 'asyncrun_runner', {})
let g:asyncrun_runner.test = function('MyRunner')
```

然后试试：

```VimL
:AsyncRun -mode=term -pos=test ls -la $(VIM_FILEDIR)
```

当 `-mode` 的值是 `term` 时，可以用 `-pos` 来表示自定义 runner 的名字（除了保留的几个外）。

Runner 函数只有一个参数：`opts`，是一个字典，里面保存着 `:AsyncRun` 命令行里传过来的值，同时 `opts.cmd` 记录着需要运行的命令。

Runner 还有另外一种写法，就是在 `autoload/asyncrun/runner` 路径下面简历一个独立文件，提供一个 `run` 方法，这些脚本将会被按需加载。

关于更多 runner 文档和例子，参考 [自定义运行模式](https://github.com/skywind3000/asyncrun.vim/wiki/Customize-Runner) 。


### 命令修改器

命令修改器可以在你运行前修改你的命令内容：

```VimL
let g:asyncrun_program = get(g:, 'asyncrun_program', {})
let g:asyncrun_program.nice = { opts -> 'nice -5' . opts.cmd }
```

上面的代码定义了一个叫做 `nice` 的修改器，在调用时指明 `-program=nice` 时：

```VimL
:AsyncRun -program=nice ls -la
```

原先命令 `ls -la` 就会被替换成： `nice -5 ls -la`。

这个功能其实非常有用，前面的 `-program=msys` 或者 `-program=wsl` 都是用命令修改器实现的，比如它会把 `ls` 命令变成：

```
c:\windows\sysnative\wsl.exe ls
```

并替换类似 `$(WSL_FILENAME)` 以及 `$(WSL_FILEPATH)` 的宏，你的命令就能在 wsl 下运行了。

### 运行需求

Vim 7.4.1829 是最低的运行版本，如果低于此版本，运行模式将会从 `async` 衰退回 `sync`。NeoVim 0.1.4 是最低的 nvim 版本。

推荐使用 vim 8.0 及以后的版本。

### 同 fugitive 协作

asyncrun.vim 可以同 `vim-fugitive` 协作，为 fugitive 提供异步支持，具体见 [here](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#fugitive).

![](https://github.com/skywind3000/images/raw/master/p/asyncrun/cooperate_with_fugitive.gif)


## 语言参考

- [Better way for C/C++ developing with AsyncRun](https://github.com/skywind3000/asyncrun.vim/wiki/Better-way-for-C-and-Cpp-development-in-Vim-8)

## 更多话题

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

# 插件协作

| Name | Description |
|------|-------------|
| [asynctasks](https://github.com/skywind3000/asynctasks.vim) | Introduce vscode's task system to vim (powered by AsyncRun). |
| [vim-fugitive](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#fugitive)  | perfect cooperation, asyncrun gets Gfetch/Gpush running in background |
| [errormarker](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins) | perfect cooperation, errormarker will display the signs on the error or warning lines |
| [airline](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins#vim-airline) | very well, airline will display status of background jobs |
| [sprint](https://github.com/pedsm/sprint) | nice plugin who uses asyncrun to provide an IDE's run button to runs your code |


See: [Cooperate with famous plugins](https://github.com/skywind3000/asyncrun.vim/wiki/Cooperate-with-famous-plugins)

# Credits

- 作者：skywind3000
- 地址：http://www.vim.org/scripts/script.php?script_id=5431

喜欢的话欢迎帮在上面地址中投一票。

