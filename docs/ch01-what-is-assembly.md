> 笔记对应《Professional Assembly Language》(Richard Blum) 第 1 章，代码为本仓库实际敲过的样例。

# 第1章 什么是汇编语言

## 本章要点
- 汇编语言（assembly language）是机器指令（machine instruction）与人类可读符号之间的一层薄封装，一条汇编语句大致对应一条 CPU 指令。
- CPU 只认二进制"指令码"（opcode/instruction code）；助记符（mnemonic）只是给人看的替身，由汇编器（assembler）翻译成机器码。
- 高级语言（high-level language）屏蔽了寄存器、内存地址、数据宽度等底层细节；汇编语言要求你亲手管理它们。
- IA-32 指令码有固定与可变两种格式，操作数宽度（byte/word/doubleword）在语法里显式区分，本仓库 `.s` 文件里的 `movb/movw/movl` 就是这套规则的体现。
- 汇编的价值在于对硬件的精确控制与可预测的性能，代价是可移植性差、开发效率低。

## 1.1 处理器指令（Processor Instructions）

### 1.1.1 指令码处理（Opcode Processing）
处理器内部按"取指—译码—执行"（fetch-decode-execute）循环工作。每条指令以二进制形式存放在代码段，控制单元取出后译码，判断需要哪些操作数、访问哪些寄存器或内存，再交由执行单元（ALU 等）完成运算，最后把结果和状态位（flags）写回。GNU as 用 AT&T 语法把源操作数写在目的操作数左边，例如 `movl %eax, %ebx` 表示把 eax 搬到 ebx；译码时方向、寄存器编号、立即数都被编码进指令码。

### 1.1.2 指令码格式（Instruction Code Format）
IA-32 指令是变长编码：先是操作码字节，随后是 ModR/M、SIB、位移（displacement）以及立即数（immediate）字段。数据宽度是这套格式的核心——一个 doubleword（4 字节）、word（2 字节）、byte（1 字节）对应不同指令变体。本仓库 `pushpop.s:9-11` 清楚展示了三种宽度各自的前缀字母：

```
	movl $24420, %ecx
	movw $350, %bx
	movb $100, %eax
```
（来源：`pushpop.s:9-11`）

`l` 操作 doubleword、`w` 操作 word、`b` 操作 byte，汇编器据此生成不同指令码，这正是"指令码格式"落到语法层的直接结果。

## 1.2 高级语言（High-Level Languages）

### 1.2.1 种类（Varieties）
编译型语言（C、C++ 等）先经编译器（compiler）翻译成机器码再执行；解释型语言（Python、早期 BASIC）由解释器（interpreter）逐句翻译执行；还有一些语言介于两者之间（如 Java 编译成字节码再虚拟执行）。汇编语言不属于这一谱系的高层，它几乎不做抽象。

### 1.2.2 特性（Features）
高级语言提供数据类型、控制结构（if/loop）、函数与自动内存管理等抽象。这些抽象在汇编里都要手工搭建：循环要用 `jmp`/条件跳转加比较指令拼出，函数要用 `call`/`ret` 配合栈（stack）传递参数。仓库里 `jumptest.s:6-12` 就是一个用 `jmp` 手工改写"跳过执行"的最小控制流例子：

```
	movl $1, %eax
	jmp overhere
	movl $10, %ebx
	int $0x80
overhere:
	movl $20, %ebx
	int $0x80
```
（来源：`jumptest.s:6-12`）

`jmp overhere` 直接跳到标号 `overhere`，中间那条 `movl $10, %ebx` 永远不会执行——这就是高级语言里 `if/goto` 背后的原始机制。

## 1.3 汇编语言（Assembly Language）

### 1.3.1 操作码助记符（Opcode Mnemonics）
每条指令以一个助记符开头，如 `mov`、`add`、`jmp`、`cpuid`。GNU as 的 AT&T 语法在助记符后附加宽度字母，寄存器前加 `%`、立即数前加 `$`、内存操作数用 `()`。`cpuid.s:8-9` 展示了不带操作数的助记符：

```
	movl $0, %eax
	cpuid
```
（来源：`cpuid.s:8-9`）

`cpuid` 是一条"裸"指令，它读取 eax 里的功能号并把结果写进 eax/ebx/ecx/edx，无需显式操作数——这说明助记符本身就隐含了对寄存器的约定。

### 1.3.2 定义数据（Defining Data）
汇编语言没有"变量类型"关键字，数据靠伪指令（directive）按字节布局手工定义。GNU as 提供 `.byte`、`.int`、`.asciz`、`.fill` 等，`sizetest3.s:3-4` 用 `.fill` 分配空间：

```
buffer:
	.fill 10000
```
（来源：`sizetest3.s:3-4`）

字符串用 ASCII 伪指令定义，`cpuid.s:3-4` 给出一段带占位符的文本，运行时代码再往占位符位置写入真实数据：

```
output:
	.ascii "The processor Vendor ID is 'xxxxxxxxxxxx'\n"
```
（来源：`cpuid.s:3-4`）

`movtest1.s:3-4` 演示单个整型数据的定义与读取：

```
	value:
		.int 1
```
（来源：`movtest1.s:3-4`）

### 1.3.3 命令（Commands）
除指令外，汇编源文件还有以 `.` 开头的命令/伪指令，指导汇编器工作：`.section` 划分段、`.globl` 声明外部可见符号、`.code32` 指定 16/32 位代码模式、`.lcomm`/`.comm` 预留缓冲区。`cpuid2.s:2-7` 一次集中了多条：

```
.code32
.section .data
output:
	.asciz "The processor Vendor ID is '%s'\n"
.section .bss
	.lcomm buffer, 12
```
（来源：`cpuid2.s:2-7`）

这些命令不产生 CPU 指令码，它们影响的是程序在内存中的布局与链接可见性。

## 1.4 小结
汇编是"面向机器的符号语言"：助记符对应指令码，宽度字母对应数据格式，伪指令对应内存布局，控制流靠跳转手工搭。理解这三层映射，是后续章节阅读本仓库代码的基础。

## 仓库对应代码
| 文件名 | 演示内容 | 关键指令/片段 |
| --- | --- | --- |
| `pushpop.s` | 数据宽度 b/w/l 三种前缀 | `movl` / `movw` / `movb`（`pushpop.s:9-11`） |
| `jumptest.s` | 用 `jmp`+标号手工实现控制流 | `jmp overhere`（`jumptest.s:7`） |
| `cpuid.s` | 裸助记符与 ASCII 数据定义 | `cpuid`、`.ascii`（`cpuid.s:4,9`） |
| `cpuid2.s` | 伪指令集中用法 | `.code32`、`.section`、`.lcomm`（`cpuid2.s:2-7`） |
| `sizetest3.s` | `.fill` 定义数据空间 | `.fill 10000`（`sizetest3.s:4`） |
| `movtest1.s` | `.int` 定义并读取整型 | `.int 1` + `movl value, %ecx`（`movtest1.s:4,8`） |

## 实践与踩坑
- AT&T 语法方向易错：源在左、目的在右，与 Intel 语法相反。刚上手时常把 `movl $1, %eax` 写成 `movl %eax, $1`，汇编器直接报错。
- 宽度字母必须与寄存器匹配：`movw $350, %bx` 用 16 位寄存器 `bx`，若写成 `movw $350, %ebx` 语义就不对。
- 立即数与地址易混：`pushpop.s:15-16` 里 `pushl data` 压的是 `data` 处的内容，`pushl $data` 压的是 `data` 的地址，`$` 前缀决定"取值"还是"取址"。

## 复习清单
- [ ] 说出一条汇编语句到 CPU 指令码的映射过程（助记符→操作码、宽度字母→数据格式）。
- [ ] 区分指令（产生机器码）与伪指令/命令（`.section`、`.globl` 等，不产生机器码）。
- [ ] 记住 AT&T 语法三个前缀：`%` 寄存器、`$` 立即数、`()` 内存间接。
- [ ] 解释 `movl value, %ecx`（取值）与 `movl $value, %ecx`（取址）的区别。
- [ ] 用 `jmp`+标号手工描述一段被跳过执行的代码。

> 本章为概念梳理，仓库代码主要在第 4 章起对应。
