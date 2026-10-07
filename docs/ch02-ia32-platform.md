> 笔记对应《Professional Assembly Language》(Richard Blum) 第 2 章，代码为本仓库实际敲过的样例。

# 第2章 IA-32平台

## 本章要点
- IA-32（Intel Architecture, 32-bit）即 80386 之后形成的 32 位 x86 架构，是现代 x86-64 的前身；本仓库所有 `.s` 都是 `-m32`/`.code32` 的 32 位目标。
- CPU 核心分控制单元（control unit）与执行单元（execution unit），对外靠一组通用寄存器（general-purpose registers）和标志位（flags/ EFLAGS）工作。
- 8 个 32 位通用寄存器：`eax/ebx/ecx/edx/esi/edi/esp/ebp`，各有约定用途；`esp` 指向栈顶，是压栈/出栈操作的关键。
- `cpuid` 指令是"查询 CPU 能力"的标准入口，返回厂商 ID 串与特性位；本仓库 `cpuid.txt` 实录 `GenuineIntel`。
- 高级特性（x87 FPU、MMX、SSE、超线程 Hyper-Threading）扩展了 IA-32 的数值与并行能力。

## 2.1 核心部分（The Core）

### 控制单元与执行单元（Control Unit / Execution Unit）
控制单元负责取指、译码并产生时序，把指令拆解成对寄存器和总线（bus）的微操作；执行单元（含 ALU、地址生成单元、寄存器堆）负责真正算数与访存。超标量（superscalar）设计让一个时钟周期内并行发射多条指令，这是 IA-32 相对早期 x86 的主要性能来源。

### 寄存器（Registers）
通用寄存器及其惯用角色：
- `eax` 累加器（accumulator），乘除和系统调用返回值常用；`cpuid.s:8` 就用 `movl $0, %eax` 设置 cpuid 功能号。
- `ebx` 基址（base），在 `cpuid` 结果里承载厂商 ID 前 4 字节。
- `ecx` 计数（counter），循环/串操作与 `cpuid` 结果的一部分。
- `edx` 数据（data），`cpuid` 结果的中间 4 字节。
- `esi`/`edi` 源/目的变址（source/di）索引，串操作和缓冲区指针常用。`cpuid.s:10` 用 `movl $output, %edi` 把输出缓冲地址放进 `edi`。
- `esp` 栈指针（stack pointer），`ebp` 基址指针（base/frame pointer），函数栈帧（stack frame）靠二者维护。

`cpuidfunc.s:8-9` 展示了经典栈帧建立：`pushl %ebp` 保存旧帧基址，`movl %esp, %ebp` 把当前栈顶设为新帧基址：

```
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
```
（来源：`cpuidfunc.s:8-10`）

这里额外 `pushl %ebx` 是因为 `cpuid` 会破坏 `ebx`，而按 IA-32 调用约定 `ebx` 属于被调用者保存（callee-saved）寄存器，必须保护。

### 标志（Flags）
`EFLAGS` 寄存器保存运算状态位：进位 CF、零 ZF、符号 SF、溢出 OF、方向 DF 等，条件跳转和 `adc`/`sbb` 都依赖它们。第 1 章的 `pushpop.s:9-11` 里宽度不同的 `mov` 通常不改标志，而算术指令会——这是后面章节 `addtest`/`cmptest` 系列的前提。

## 2.2 高级特性（Advanced Features）
- x87 FPU：80 位扩展精度的浮点单元，独立寄存器栈 `st(0)~st(7)`，处理 `floattest`、`fpuvals` 那类样例。
- MMX：64 位 SIMD（Single Instruction Multiple Data）整数 packed 运算，占用 FPU 寄存器别名。
- SSE/SSE2：128 位 XMM 寄存器的标量与 packed 浮点/整数指令，`ssetest`、`ssefloat` 系列对应。
- 超线程（Hyper-Threading）：单个物理核暴露为两个逻辑处理器，共享执行资源以提升吞吐。

## 2.3 IA-32 处理器系列（IA-32 Processor Family）

### Intel 与非 Intel
Intel 一方从 80386、486、Pentium、Pentium Pro/II/III/4 到 Core 系列都属 IA-32；非 Intel 一方有 AMD 的 Am386、K5/K6/K7/Athlon、Opteron，以及 Cyrix/TSMC 等的兼容产品。它们指令集兼容，但 `cpuid` 返回的厂商串不同——这正是识别处理器的可靠手段。

`cpuid` 的执行与结果落地是本章最直接的代码证据。`cpuid.s:8-13`：

```
	movl $0, %eax
	cpuid
	movl $output, %edi
	movl %ebx, 28(%edi)
	movl %edx, 32(%edi)
	movl %ecx, 36(%edi)
```
（来源：`cpuid.s:8-13`）

`cpuid` 执行后，功能号 0 让 CPU 把 12 字节厂商 ID 拆成 `ebx`(4) + `edx`(4) + `ecx`(4) 三段返回（注意顺序是 ebx→edx→ecx），代码再把它们拷进输出缓冲。仓库里的运行记录 `cpuid.txt:1` 证实结果：

```
the processor vendor ID is 'GenuineIntel'
```
（来源：`cpuid.txt:1`）

`GenuineIntel` 恰为 12 字符，与三段 4 字节的布局吻合。`cpuid2.s:11-16` 用同样逻辑但把结果先写入 `.bss` 的 `buffer`，再交给 C 库 `printf` 打印：

```
	movl $0, %eax
	cpuid
	movl $buffer, %edi
	movl %ebx, (%edi)
	movl %edx, 4(%edi)
	movl %ecx, 8(%edi)
```
（来源：`cpuid2.s:11-16`）

## 2.4 小结
IA-32 的编程模型可归纳为"寄存器 + 标志 + 内存"：控制/执行单元按超标量流水处理指令，通用寄存器各有约定角色，`cpuid` 提供查询 CPU 身份的入口，高级特性在其上叠加 SIMD/浮点/并行能力。

## 仓库对应代码
| 文件名 | 演示内容 | 关键指令/片段 |
| --- | --- | --- |
| `cpuid.s` | `cpuid` 功能号 0 与结果寄存器拆分 | `cpuid`、`movl %ebx, 28(%edi)`（`cpuid.s:9,11`） |
| `cpuid2.s` | 结果落入 `.bss` 缓冲后用 printf | `.lcomm buffer, 12`、`cpuid`（`cpuid2.s:7,12`） |
| `cpuidfunc.s` | 栈帧建立与被调用者保存 `ebx` | `pushl %ebp`、`pushl %ebx`（`cpuidfunc.s:8-10`） |
| `cpuid.txt` | cpuid 运行结果实录 | `GenuineIntel`（`cpuid.txt:1`） |

## 实践与踩坑
- `cpuid` 返回的 12 字节厂商串顺序是 ebx→edx→ecx，不是字典序直觉的 eax→ebx→ecx；`cpuid.s:11-13` 与 `cpuid2.s:14-16` 都严格照此顺序拷贝，写反会得到乱码。
- `cpuid` 会破坏 `ebx`，在函数里必须像 `cpuidfunc.s:10` 那样先 `pushl %ebx` 再恢复，否则调用方寄存器被污染。
- 32 位目标在 64 位机器上需要内核支持（`linux-gate.so`、`vdso` 等），若系统缺 32 位运行库，`cpuid2` 这类链接 libc 的程序会直接失败——这与第 4 章记录的段错误同源。

## 复习清单
- [ ] 列出 8 个 32 位通用寄存器及各自约定用途。
- [ ] 说明 `cpuid` 功能号 0 后 12 字节厂商串落在哪三个寄存器、顺序如何。
- [ ] 解释 `cpuidfunc.s` 里为何要额外保存 `ebx`。
- [ ] 区分 x87（寄存器栈）与 MMX/SSE（SIMD）的工作方式。
- [ ] 用 `cpuid.txt` 说明如何用汇编区分 Intel 与 AMD 处理器。

> 本章为概念梳理，仓库代码主要在第 4 章起对应。
