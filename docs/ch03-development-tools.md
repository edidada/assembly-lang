> 笔记对应《Professional Assembly Language》(Richard Blum) 第 3 章，代码为本仓库实际敲过的样例。

# 第3章 相关的工具

## 本章要点
- 一个完整汇编开发链包含：汇编器（assembler）→ 连接器（linker）→ 可执行文件 → 调试器（debugger）；周边还有编译器（compiler）、反汇编器（disassembler）、简档器（profiler）。
- GNU as 默认把 `.s` 汇编成 ELF 目标文件（object file）`.o`；GNU ld（经 `gcc` 驱动）把 `.o` 链接成可执行文件。
- AT&T 语法是 GNU as 默认语法：源操作数在左、寄存器加 `%`、立即数加 `$`、尺寸用后缀 `b/w/l/q`。
- `gdb` 用于单步（`ni`/`si`）、断点、查看寄存器/内存；`objdump` 反汇编可执行文件核对机器码；`gprof` 做性能简档。
- 本仓库 `compiler.md` 记录了真实的 `as`/`gcc`/运行/`gdb` 流程与一次段错误，`jumptest.txt` 是 `objdump` 的反汇编实录。

## 3.1 开发工具（The Development Tools）
- 汇编器：源码→目标码。GNU as 即本仓库所用。
- 连接器：合并多个 `.o` 与库，解析符号，产出可执行映像；GNU 的是 ld。
- 调试器：逐指令观察运行状态；GNU 的是 gdb。
- 编译器：高级语言→目标码，`gcc` 前端也能驱动汇编流程（见 3.4）。
- 反汇编器：目标码→可读汇编，`objdump -d` 即可（见 3.7）。
- 简档器：统计耗时定位热点，`gprof`（见 3.8）。

## 3.2 GNU 汇编器（The GNU Assembler）

### 安装与使用
Linux 下 as 随 binutils 安装。基本用法：`as -o 输出.o 输入.s`。`compiler.md` 里的真实命令：

```
as -o cpuid2.o cpuid2.s
```
（来源：`compiler.md:4`）

产物 `cpuid2.o` 是未链接的目标文件，尚不能直接运行。

### 操作码语法
GNU as 用 AT&T 语法。`cpuid.s` 全篇即标准示范：立即数 `$0`、寄存器 `%eax`、内存间接 `28(%edi)`（`cpuid.s:8-13`），伪指令 `.section .data` / `.globl _start`（`cpuid.s:2,6`）。尺寸后缀在 `pushpop.s:9-11` 集中体现：`movl`/`movw`/`movb`。

## 3.3 GNU 连接器（The GNU Linker）
`ld` 通常由 `gcc` 间接调用，负责段布局、符号解析、把 C 运行库（crt）链接进来。`compiler.md:5` 的命令：

```
gcc -o cpuid2 cpuid2.o
```
（来源：`compiler.md:5`）

注意 `cpuid2.s` 以 `main` 为入口并调用 `printf`/`exit`，必须经 `gcc` 链接 libc 与启动代码；纯 `_start` 程序（如 `cpuid.s`）则用 `ld` 直接链接、靠 `int $0x80` 系统调用即可。

## 3.4 GNU 编译器（The GNU Compiler Collection）
`gcc` 不只是编译器，也是构建驱动器。用它链接 `.o` 会自动带入正确的启动文件和库路径。这也是 `cpuid2.s` 这类"用 C 库"的汇编程序的推荐构建方式；书中还提到可用 `gcc` 直接把 `.s` 一步编成可执行文件（先内部调用 as 再链接）。

## 3.5 GNU 调试器 gdb（The GNU Debugger）
`compiler.md` 记下的核心操作是"一条一条指令跟"，并点明：

```
gdb一条一条指令跟
ni是单步指令的命令
```
（来源：`compiler.md:10-11`）

`ni`（next instruction）按机器指令单步且不进入被调函数内部，`si` 则会步进进 call 目标。配合 `info registers`、`x/...` 查看寄存器与内存，是定位段错误（见 3.9）的主要手段。

## 3.6 KDE 调试器 kdbg（The KDE Debugger）
`kdbg` 是 gdb 的图形前端，用窗口替代命令行显示寄存器、反汇编与断点，底层仍是 gdb。习惯终端后多数开发者直接用 gdb，`kdbg` 作为可选项了解即可。

## 3.7 GNU objdump（The GNU Object Disassembler）
`objdump -d` 反汇编可执行文件的各段。`jumptest.txt` 就是 `jumptest` 程序的完整反汇编实录，开头标明目标格式：

```
jumptest:     file format elf32-i386
```
（来源：`jumptest.txt:2`）

对应源码 `jumptest.s:6-12` 的 `jmp overhere`，反汇编里 `<main>` 段可核对机器码：

```
080483db <main>:
 80483db:	b8 01 00 00 00       	mov    $0x1,%eax
 80483e0:	eb 07                	jmp    80483e9 <overhere>
 80483e2:	bb 0a 00 00 00       	mov    $0xa,%ebx
 80483e7:	cd 80                	int    $0x80
```
（来源：`jumptest.txt:323-327`）

关键观察：`jmp` 的机器码是 `eb 07`——`eb` 是短跳转（short jump）操作码，`07` 是相对下一指令地址（0x80483e2）向后 7 字节的有符号偏移，落到 `0x80483e9 <overhere>`，验证了第 1 章"标号跳转即相对寻址"的说法。同时可见 `int $0x80` 编码为两字节 `cd 80`。

## 3.8 GNU 简档器 gprof（The GNU Profiler）
用 `-pg` 编译链接后运行程序生成 `gmon.out`，再 `gprof 可执行文件` 得到函数级耗时/调用次数报告，用于定位性能热点。本章代码样例未涉及简档构建，留作后续性能章节实践。

## 3.9 完整的汇编开发系统（The Complete Assembly Development System）
把工具串起来：`as` 出 `.o` → `gcc`/`ld` 链接 → 运行 → 出错用 `gdb` 单步 → 用 `objdump` 核对机器码。`compiler.md` 记录了一次真实失败：三步命令后运行崩溃：

```
as -o cpuid2.o cpuid2.s
gcc -o cpuid2 cpuid2.o
./cpuid2 
Segmentation fault (core dumped)
```
（来源：`compiler.md:4-7`）

这正是"完整系统"要解决的问题：链接成功不等于运行正确。用 `gdb ./cpuid2` 配合 `ni` 单步即可定位到崩溃指令（详见第 4 章对 `cpuid2.s` 的分析）。

## 3.10 小结
GNU binutils（as/ld/objdump/gdb/gprof）加上 gcc 驱动，构成一套自足的汇编开发闭环。掌握 `as`→`gcc`→`gdb ni`→`objdump -d` 四步，就能编、跑、查、核。

## 仓库对应代码
| 文件名 | 演示内容 | 关键指令/片段 |
| --- | --- | --- |
| `compiler.md` | as/gcc/运行/gdb 全流程实录与段错误 | `as -o`、`gcc -o`、`ni`（`compiler.md:4-11`） |
| `jumptest.txt` | objdump 反汇编输出实录 | `elf32-i386`、`jmp`/`eb 07`（`jumptest.txt:2,325`） |
| `jumptest.s` | 被反汇编的源码，标号跳转 | `jmp overhere`（`jumptest.s:7`） |
| `cpuid.s` | AT&T 语法与伪指令示范 | `$0`、`28(%edi)`、`.globl`（`cpuid.s:8,11,6`） |
| `pushpop.s` | 尺寸后缀 b/w/l 语法 | `movl`/`movw`/`movb`（`pushpop.s:9-11`） |

## 实践与踩坑
- 入口符号决定链接方式：`_start` 程序（`cpuid.s`）可用 `ld` 直连并用 `int $0x80` 退出；`main`+C 库程序（`cpuid2.s`）必须 `gcc` 链接，否则找不到 `printf` 与启动代码。
- 链接成功 ≠ 运行成功：`compiler.md` 中 `gcc -o cpuid2 cpuid2.o` 无报错，运行却段错误。这类问题只能靠 `gdb` 单步定位，不能指望编译器提示。
- `objdump` 会把 `.interp`、`.note.ABI-tag` 等非代码段也"反汇编"成看似无意义的指令（`jumptest.txt:5-33`），那是把数据当指令解码的假象；真正要看的是 `Disassembly of section .text` 之后带 `<main>` 标号的部分（`jumptest.txt:214,323`）。
- gdb 里 `ni` 与 `si` 的区别：`ni` 跨过 call，`si` 跟进 call，追 libc 崩溃时用 `si` 才看得进内部。

## 复习清单
- [ ] 说出 as→gcc→运行→gdb→objdump 五步各自产物与作用。
- [ ] 解释为什么 `_start` 和 `main` 入口需要不同链接方式。
- [ ] 从 `jumptest.txt` 读出 `jmp` 的短跳转编码 `eb 07` 含义。
- [ ] 复述 `compiler.md` 记录的段错误现象与用 gdb `ni` 排查的思路。
- [ ] 说明 `ni` 与 `si` 单步行为差异。
