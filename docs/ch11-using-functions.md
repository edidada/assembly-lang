# 第11章 使用函数(Using Functions)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 11 章，代码为本仓库实际敲过的样例。

## 本章要点

- 函数（function）在 IA-32 上就是 `call` / `ret` 加一段约定好的栈帧（stack frame）：`call` 把返回地址压栈并跳转，`ret` 弹出返回地址。
- 用 `pushl %ebp` / `movl %esp, %ebp` 建立基址指针后，参数从 `8(%ebp)` 开始按入栈顺序编号（`4(%ebp)` 是返回地址）。
- cdecl 调用约定（calling convention）要点：参数右到左入栈、由调用者清栈（`addl $4, %esp`）、整型返回值放 `%eax`。
- 汇编里既可以"定义函数给别人用"（`area`、`greater`、`asmfunc`、`square`），也可以"调用别人定义的函数"（C 库的 `printf`、`sleep`、`exit`）。
- 函数内部若用到会被系统调用或 C 库破坏的寄存器（如 `%ebx`、`%ecx`），必须自己保存/恢复（push/pop）。
- 用 `.globl main` 进入 C 运行时（C runtime）时，Linux/glibc 启动约定是 `%eax` = argc、`%ecx` = argv；只有把 `main` 直接当入口（`_start` 风格）时 argc 才在栈顶 `(%esp)`。`paramtest1.s` 正是这个易混点。

## 一、函数调用的机器模型

`functest1.s` 的 main 连续三次以 C 风格调用同一段码：

```
	pushl $10
	call area
	addl $4, %esp
	movl %eax, result
```
（functest1.s:13-16，三个调用只差参数 10/2/120，见 functest1.s:13-26）

`call area` 压入返回地址后跳入函数；`addl $4, %esp` 是调用者清栈——这正是 cdecl 的特征（被调用者不动参数，调用者自己回收）。返回值约定放 `%eax`，这里存进 `.bss` 里的 `result`（`movl %eax, result`）。

## 二、函数序言、尾声与栈帧（prologue / epilogue）

`area` 的骨架：

```
area:
	pushl %ebp
	movl %esp, %ebp
	subl $4, %esp
```
（functest1.s:33-36）

- `pushl %ebp; movl %esp, %ebp`：保存调用者的帧基指针，建立本帧（prologue）。
- `subl $4, %esp`：留出 4 字节的局部临时量 `-4(%ebp)`（FPU 结果落地用）。
- 尾声（epilogue）`movl %ebp, %esp; popl %ebp; ret`（functest1.s:44-46）恢复栈与旧 ebp，再弹返回地址。

参数经帧基指针读取：`filds 8(%ebp)`（functest1.s:38）——8(%ebp) 处就是 `pushl $10` 放进去的半径。注意 `filds` 只取 16 位（word）：因为值小且是小端序，低两字节恰好是整数本身，书上是"侥幸能用"的写法。

函数体内还调了 `finit` 与 `fldcw precision`（functest1.s:10-11，`precision` 为 `.byte 0x7f, 0x00`，见 functest1.s:3-4）初始化 FPU 控制字。

## 三、把函数拆成独立文件：外部函数（external function）

`functest2.s` 与 `functest1.s` 的 main 逐字相同，但文件里没有 `area` 的定义——它靠链接器（linker）从别的目标文件解析符号。`area.s` 就是这个独立版本，且加了导出声明：

```
.type area, @function
.globl area
```
（area.s:3-4）

`.globl` 使符号对链接器可见，`@function` 是 GNU as 的符号类型注解。书上的做法是把此类函数归档成库，第 14 章详解（本仓库的 `areafunc.s`、`square.s` 等同理）。

## 四、C 调用汇编函数

### asmfunc.s + mainprog.c
`asmfunc.s` 是一个"被 C 当普通函数调"的汇编函数：

```
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	...
	popl %ebx
	movl %ebp, %esp
	popl %ebp
```
（asmfunc.s:11-24 摘要）

关键点：函数体用 `int $0x80`（写 fd=1 输出 testdata），而 32 位 Linux 系统调用要占用 `%ebx`；对 C 而言 `%ebx` 是调用者保存区之外的寄存器，所以必须先 `pushl %ebx` / `popl %ebx` 保住它，否则破坏 C 的寄存器约定。`mainprog.c` 只是：

```
	asmfunc();
```
（mainprog.c:6）——C 侧只需一个声明即可链接调用。

### greater.s + multtest.c
两个参数取较大值，演示多参数寻址：

```
	movl 8(%ebp), %eax
	movl 12(%ebp), %ecx
	cmpl %ecx, %eax
	jge end
	movl %ecx, %eax
```
（greater.s:7-11）

`multtest.c` 里 `greater(i, j)`（multtest.c:8）按 cdecl 先推 j 再推 i，于是 8(%ebp)=第一个参数 i、12(%ebp)=第二个参数 j，返回值直接留在 `%eax` 供 C 使用，无需局部变量存储。

## 五、汇编调用 C 库函数

`cfunctest.s` 用 `printf`、`sleep`、`exit`：

```
loop1:
	pushl %ecx
	pushl $output
	call printf
	addl $4, %esp
	pushl $5
	call sleep
	addl $4, %esp
	popl %ecx
	loop loop1
```
（cfunctest.s:9-18）

因为 `loop` 指令用 `%ecx` 作计数器，而 `printf` 内部必然破坏 `%ecx`，所以每次调用前 `pushl %ecx`、之后 `popl %ecx` 手工保存——这是"调用 C 库要防寄存器被踩"的典型手法。结尾 `pushl $0; call exit` 走 C 的正常退出（比 `int $0x80` 多做了 stdio 缓冲区冲刷，输出才可靠）。

`cfunctest.c` 是对照的纯 C 版：`circumf`/`area` 返回 `float`（cfunctest.c:3-10），提示你 C 的浮点返回走 st(0)，与第 14 章 `areafunc.s` 衔接。

## 六、main 里的命令行参数：paramtest1.s

```
	movl (%esp), %ecx
	pushl %ecx
	pushl $output1
	call printf
	addl $4, %esp
	popl %ecx
	movl %esp, %ebp
	addl $4, %ebp
```
（paramtest1.s:10-17）

意图：从栈上取 argc（参数个数）进 `%ecx` 作循环次数，再用 `%ebp` 沿栈逐个取 argv 字符串指针打印。同 nanotest.s 一样用 `pushl %ecx`/`popl %ecx` 保护循环计数。约定细节见第 12 章；本章先记住"直接入口(`_start`)时 argc 在 `(%esp)`、argv 在 `4(%esp)` 起；经 C 运行时的 `main` 入口则 argc 在 `%eax`、argv 在 `%ecx`"，两种链接方式混用是本样例最大的坑（见下文踩坑）。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| functest1.s | 自包含的 C 风格函数：main+area 同文件算圆面积 | `pushl $10` / `call area` / `addl $4, %esp`；`filds 8(%ebp)` |
| functest2.s | main 调用外部符号 area（定义拆到 area.s） | 与 functest1.s 相同的调用序列，本文件无 area 定义 |
| area.s | 独立可链接的 area 函数 | `.globl area`、帧建立、`fstps -4(%ebp)` 后经 `%eax` 返回 |
| asmfunc.s | 供 C 调用的汇编函数，内部用系统调用写 stdout | `pushl %ebx`/`popl %ebx` 保护 C 寄存器 |
| mainprog.c | C 直接调用 asmfunc() | `asmfunc();`（mainprog.c:6） |
| greater.s | 双参数函数取较大者 | `movl 8(%ebp), %eax`、`movl 12(%ebp), %ecx` |
| multtest.c | C 传两个 int 调用 greater 并打印结果 | `int k = greater(i, j);`（multtest.c:8） |
| cfunctest.s | 汇编调用 C 库 printf/sleep/exit | `pushl %ecx`…`popl %ecx` 保护 loop 计数器 |
| cfunctest.c | 对照的纯 C 函数版（返回 float） | `float area(int a)`（cfunctest.c:7-10） |
| paramtest1.s | main 入口读 argc/argv 并循环打印 | `movl (%esp), %ecx`、`pushl (%ebp)`、`loop loop1` |

## 逐文件详解

- **functest1.s vs functest2.s**：main 部分完全一致（functest1.s:9-30 与 functest2.s:9-30），唯一区别是 functest1.s 在 32-46 行自带 `area` 定义。functest2.s 单独汇编可以通过（汇编器不检查未定义符号），链接时必须再给 `area`（area.s 目标文件），否则 `undefined reference to 'area'`。
- **area.s**：函数体与 functest1.s 内联版逐行相同（对比 area.s:5-17 与 functest1.s:33-46），只多了 `.globl`/`.type` 导出。返回方式是把 `fstps -4(%ebp)` 的浮点位模式 `movl` 进 `%eax`（area.s:13-14）——严格说返回的是"装成整数用的 float 位模式"，`main` 只是把它存进 result，不做数值解释；真正给 C 用的浮点返回要留在 st(0)，见 areafunc.s（第 14 章）。
- **asmfunc.s + mainprog.c 成对**：C 写了 `asmfunc()`，没有原型（老式 C 默认返回 int）；汇编侧 `asmfunc` 不设置 `%eax` 返回值也无妨，main 的 `return 0` 才是进程退出码。链接 `gcc mainprog.c asmfunc.s` 即可，运行打印 "This is a test message from the asm function"。
- **greater.s + multtest.c 成对**：C 侧 `greater(i, j)` 生成两个 `pushl` 加 `call`；汇编侧证明"参数编号 = 8 + 4×(序号-1)"。返回 `%eax` 后 C 存进 k 再 printf，演示整型返回值约定。
- **cfunctest.s + cfunctest.c 成对**：汇编版直接 `call printf`/`call sleep`，字符串用手写的 `.asciz "This is a test\n"`（cfunctest.s:4）；C 版则定义了两个返回 float 的函数。对照点：C 编译后参数自动入栈、清栈由编译器插入，汇编版全靠自己写 `addl $4, %esp`，少写一次栈就不平衡。
- **paramtest1.s**：`.asciz "There are %d parameters:\n"` 与 `"%s\n"` 两个格式串（paramtest1.s:3-6），printf 后 `addl $8, %esp` 清两个参数（paramtest1.s:23），再次说明调用者清栈。

## 实践与踩坑

1. **忘了清栈**：`call area` 后不写 `addl $4, %esp`，`%esp` 越漏越低，`result` 虽不受影响（.bss 绝对地址），但帧一层层错位，第二次调用读到脏参数。
2. **`%ecx`/`%ebx` 被库函数踩掉**：cfunctest.s 若去掉 `pushl %ecx`/`popl %ecx`，第一次 `call printf` 回来 `%ecx` 就不是 10 了，`loop` 直接乱跳；asmfunc.s 若不保存 `%ebx`，C 主程序可能崩溃。
3. **paramtest1.s 的入口约定分歧**：本文件按"argc 在栈顶"写（paramtest1.s:10）。用 `gcc paramtest1.s` 链接时，实际进 main 的是 glibc 启动代码，argc 在 `%eax`、argv 在 `%ecx`，`(%esp)` 处是返回地址——要复现书中输出，得把入口当 `_start` 处理（`ld` 直链并把 main 设成入口，或读 `%eax`）。这是本章与第 12 章都要小心的一处。
4. **`.asciz` 与 `.string`**：GNU as 两者都自动补 NUL；`output` 串在 cfunctest.s:4、paramtest1.s:3-6 都用 `.asciz`，给 printf 系列用是必须的。
5. **filds 只读 16 位**：area 的 `filds 8(%ebp)` 对 10/2/120 没问题，半径超过 32767 就错。要读满 4 字节整数用 `fildl`。
6. **functest2.s 单独 ld 会报 undefined symbol**，这是特性不是 bug——它演示的正是"外部函数留给链接器解析"。

## 复习清单

- [ ] 能徒手画出 pushl/call/建立 ebp 帧后栈内布局（返回地址在 4(%ebp)，参数从 8(%ebp) 起）。
- [ ] 说清 cdecl 三条：参数右到左入栈、调用者清栈、整型返回值在 %eax。
- [ ] 知道 functest1/functest2/area.s 三者如何拆分、链接时符号怎么解析。
- [ ] 解释 asmfunc.s 为什么 push/pop %ebx，cfunctest.s 为什么 push/pop %ecx。
- [ ] 区分 _start 直接入口（argc 在 (%esp)）与 C 运行时 main 入口（argc 在 %eax、argv 在 %ecx），并知道 paramtest1.s 的坑。
- [ ] 会写 `.globl`/`.type ..., @function` 导出一个汇编函数给 C 用。
