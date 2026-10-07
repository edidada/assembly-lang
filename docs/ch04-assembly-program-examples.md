> 笔记对应《Professional Assembly Language》(Richard Blum) 第 4 章，代码为本仓库实际敲过的样例。

# 第4章 汇编语言程序范例

## 本章要点
- 一个最小 GNU as 程序由数据段/文本段、起始标号（`_start` 或 `main`）和退出逻辑三部分组成。
- 纯 `_start` 程序用 `int $0x80` 直接触发 Linux 系统调用完成 write/exit，不依赖 C 库；`cpuid.s` 即此路线。
- 想要 `printf` 这类便利输出，就以 `main` 为入口、链接 C 库（`gcc`），如 `cpuid2.s`；两条路线的构建与运行约束不同。
- `cpuid` 功能号 0 返回 12 字节厂商 ID，落在 `ebx/edx/ecx`（此序），可拷贝进缓冲区展示。
- `compiler.md` 记录了 `cpuid2` 链接成功却运行段错误的真实踩坑，是本章最好的调试教材。

## 4.1 程序的组成（Program Composition）

### 4.1.1 定义段（Defining Sections）
GNU as 用 `.section` 划段：`.data` 存已初始化数据、`.bss` 存未初始化预留空间、`.text` 存代码。`cpuid.s:2-6` 是最小骨架（`.section .data` + `output: .ascii` 缓冲 + `.section .text` + `.globl _start`）。`cpuid2.s:3-7` 同时用到三段，并用 `.lcomm` 在 `.bss` 预留 12 字节缓冲：

```
.section .data
output:
	.asciz "The processor Vendor ID is '%s'\n"
.section .bss
	.lcomm buffer, 12
```
（来源：`cpuid2.s:3-7`）

### 4.1.2 定义起始点（Defining a Start Point）
入口符号二选一：裸程序用 `_start`（`cpuid.s:6-7` 的 `.globl _start` / `_start:`），链接 C 库的程序用 `main`（`cpuid2.s:9-10`）。操作系统据此找到第一条指令；选错入口会导致链接器找不到符号或运行时初始化不当。

## 4.2 创建简单程序（Creating a Simple Program）

### 4.2.1 CPUID 指令
`cpuid` 读取 `eax` 作为功能号（leaf），执行后把结果写回 `eax/ebx/ecx/edx`。功能号 0 返回厂商 ID 串，12 字符按 `ebx`（前 4）→`edx`（中 4）→`ecx`（后 4）排列。`cpuid.s:8-13` 设 `movl $0, %eax` 后执行 `cpuid`，再用 `movl %ebx, 28(%edi)`、`movl %edx, 32(%edi)`、`movl %ecx, 36(%edi)` 把结果拷进输出缓冲。拷贝偏移从 28 起，因为 `"The processor Vendor ID is '"` 恰为 28 字节，三个 4 字节写入覆盖了 12 个占位 `x`。

### 4.2.2 范例程序与 4.2.3 构建
`cpuid.s` 用系统调用直接输出：`cpuid.s:14-21` 设 `eax=4`(sys_write)、`ebx=1`(stdout)、`ecx=output 地址`、`edx=42`(长度) 后 `int $0x80`，再用 `eax=1`(sys_exit)、`ebx=0` 退出：

```
	movl $4, %eax
	movl $1, %ebx
	movl $output, %ecx
	movl $42, %edx
	int $0x80
	movl $1, %eax
	movl $0, %ebx
	int $0x80
```
（来源：`cpuid.s:14-21`）

运行结果由 `cpuid.txt:1` 记录：

```
the processor vendor ID is 'GenuineIntel'
```
（来源：`cpuid.txt:1`）

`_start` 路线用 `ld -o cpuid cpuid.s`；`main`+C 库路线见 `compiler.md:4-5` 的 `as -o cpuid2.o cpuid2.s` 再 `gcc -o cpuid2 cpuid2.o`，`gcc` 带入 C 启动代码并把 `main` 作入口、解析 `printf`/`exit` 符号。

### 4.2.4 运行可执行程序
`./cpuid` 正常打印厂商 ID（对应 `cpuid.txt`）。`./cpuid2` 却崩溃，实录见 `compiler.md:6-7`：

```
./cpuid2 
Segmentation fault (core dumped)
```
（来源：`compiler.md:6-7`）

## 4.3 调试程序（Debugging a Program）
`gcc` 可一步从 `.s` 出可执行文件（内部先调 `as` 再链接），是 `cpuid2.s` 这类依赖 libc 程序更自然的构建路径。`compiler.md:10-11` 记下的调试方法是"一条一条指令跟"、用 `ni` 单步。针对 `cpuid2` 段错误，用 `gdb ./cpuid2`，在 `call printf`（`cpuid2.s:19`）附近反复 `ni`，观察 `esp` 是否 16 字节对齐、执行 `call` 时是否触发 `SIGSEGV`。纯 `_start` 程序（`cpuid.s`）没有 libc 干扰，更容易先跑通，可作对照基准。

## 4.4 在汇编语言中使用 C 库函数（Using C Library Functions in Assembly）

### 4.4.1 使用 printf
`cpuid2.s` 是本章"用 C 库"的范例。它把厂商 ID 先存进 `.bss` 的 `buffer`（`cpuid2.s:13-16`），再以 `%s` 格式串调用 `printf`，参数按 cdecl 逆序压栈、调用后由调用方清栈：

```
	pushl $buffer
	pushl $output
	call printf
	addl $8, %esp
	pushl $0
	call exit
```
（来源：`cpuid2.s:17-22`）

`addl $8, %esp` 清理两个入栈参数，`pushl $0`+`call exit` 以 0 状态退出——这与 4.2.2 里裸程序用 `int $0x80` 退出是两套等价机制。

### 4.4.2 连接 C 库函数
使用 C 库意味着必须用 `gcc`（或 `ld` 手加 `crt`/`-lc`）链接，运行时依赖动态加载器与 libc。`cpuidfunc.s` 演示"汇编例程返回字符串指针给外部调用者"：它建立标准栈帧、保护 `ebx`，把结果地址放进 `eax` 返回：

```
	movl $output, %eax
	popl %ebx
	movl %ebp, %esp
	popl %ebp
	ret
```
（来源：`cpuidfunc.s:17-21`）

`cpuidfunc.s:8-10` 的 `pushl %ebp`/`movl %esp, %ebp`/`pushl %ebx` 体现被调用者保存约定——`cpuid` 破坏 `ebx`，函数必须复原。

## 4.5 小结
本章给出两条完整可运行路线：`_start`+`int $0x80`（`cpuid.s`，稳、无依赖）与 `main`+C 库（`cpuid2.s`，方便但依赖运行时）。理解段、入口、系统调用与 C 调用约定，是从"能编"走向"能跑对"的关键。

## 仓库对应代码
| 文件名 | 演示内容 | 关键指令/片段 |
| --- | --- | --- |
| `cpuid.s` | `_start`+`int $0x80` 输出 cpuid 厂商 ID | `cpuid`、`int $0x80`（`cpuid.s:9,18`） |
| `cpuid2.s` | `main`+`printf` 版，运行段错误 | `call printf`、`addl $8,%esp`（`cpuid2.s:19-20`） |
| `cpuidfunc.s` | 汇编函数返回字符串指针，栈帧与 ebx 保护 | `pushl %ebp`、`movl $output,%eax`、`ret`（`cpuidfunc.s:8,17,21`） |
| `cpuid.txt` | cpuid 运行结果实录 | `GenuineIntel`（`cpuid.txt:1`） |
| `compiler.md` | as/gcc/运行/gdb 与段错误实录 | `Segmentation fault (core dumped)`（`compiler.md:7`） |

## 实践与踩坑
- `cpuid2` 段错误线索（`compiler.md:7`）：`cpuid.s` 用 `int $0x80` 能正常输出，结构相似的 `cpuid2.s` 走 `call printf` 却崩。可排查方向：
  1. **栈未 16 字节对齐**：`cpuid2.s:17-19` 只压两个参数就 `call printf`，若进入时 `esp` 未对齐，glibc 的 `printf` 用 `movaps` 访问对齐栈帧会 `SIGSEGV`——手写汇编最常见崩溃原因。
  2. **`buffer` 无结束符**：`cpuid2.s:7` 的 `buffer` 只有 12 字节且被 12 字符厂商串刚好写满（`cpuid2.s:14-16`），`printf` 以 `%s` 读它会越过 12 字节继续找 `\0`，可能读到非法页。
  3. 缺正确 CFI 或 64 位机未装 32 位 libc 也会运行即崩。
  结论：`call printf` 前保证 `esp` 16 字节对齐且 `buffer` 留结束符（如 `.lcomm buffer, 13`），用 gdb `ni` 逐条验证即可锁定。
- 拷贝偏移要精确：`cpuid.s:11-13` 从 28 起写，格式串长度改了就要同步，否则串位。
- 系统调用 vs C 库：`cpuid.s:14-21` 用 `int $0x80` 无依赖最稳；`printf` 路线要承担 libc 与运行时依赖。

## 复习清单
- [ ] 画出 `cpuid.s` 从设 `eax=0` 到 `int $0x80` 退出的完整执行流。
- [ ] 说明 `_start` 与 `main` 两种入口对构建命令（`ld` vs `gcc`）的要求差异。
- [ ] 解释 `cpuid2.s:17-20` 里 cdecl 参数压栈顺序与 `addl $8,%esp` 清栈。
- [ ] 复述 `cpuid2` 段错误的两条最可能线索（栈对齐、buffer 无结束符）。
- [ ] 用 `cpuidfunc.s:8-10,17-21` 说明被调用者如何保存 `ebx` 并返回字符串指针。
