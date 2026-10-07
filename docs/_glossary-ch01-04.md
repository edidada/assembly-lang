> 名词对照覆盖《Professional Assembly Language》(Richard Blum) 第 1~4 章，词条均来自笔记正文与本仓库代码中可观察到的事实。

# 术语表（第1~4章 中英对照）

| 中文 | English | 释义 / 出现位置 |
| --- | --- | --- |
| 汇编语言 | assembly language | 机器指令的符号化表示，第 1 章主题 |
| 机器指令 | machine instruction | CPU 直接执行的一条指令 |
| 操作码 / 指令码 | opcode / instruction code | 指令中标识操作类型的二进制字段 |
| 助记符 | mnemonic | 操作码的人类可读替身，如 `mov`、`cpuid` |
| 汇编器 | assembler | 把 `.s` 源码翻译为机器码的工具（GNU as） |
| 连接器 / 链接器 | linker | 合并目标文件与库生成可执行文件（GNU ld / gcc 驱动） |
| 目标文件 | object file | 汇编产物 `.o`，尚未链接 |
| 反汇编器 | disassembler | 把机器码还原为可读汇编（objdump -d） |
| 调试器 | debugger | 逐指令观察运行状态（gdb / kdbg） |
| 简档器 | profiler | 统计函数耗时定位热点（gprof） |
| 编译器 | compiler | 高级语言到机器码的翻译器（gcc） |
| 取指—译码—执行 | fetch-decode-execute | CPU 处理指令的基本循环 |
| 控制单元 | control unit | 取指、译码、产生时序的 CPU 部件 |
| 执行单元 | execution unit | 实际运算的 CPU 部件（含 ALU） |
| ALU | Arithmetic Logic Unit | 算术逻辑单元 |
| 总线 | bus | CPU 与内存/外设交换数据的通道 |
| 超标量 | superscalar | 单周期并行发射多条指令的设计 |
| IA-32 | Intel Architecture, 32-bit | 80386 起的 32 位 x86 架构 |
| 通用寄存器 | general-purpose registers | `eax/ebx/ecx/edx/esi/edi/esp/ebp` |
| 累加器 | accumulator | `eax`，运算/返回值常用 |
| 基址指针 / 帧基址 | base / frame pointer | `ebp`，维护栈帧 |
| 栈指针 | stack pointer | `esp`，指向栈顶 |
| 变址寄存器 | index register | `esi`(源) / `edi`(目的) |
| 标志 / 状态位 | flags / EFLAGS | CF/ZF/SF/OF/DF 等条件码 |
| 栈帧 | stack frame | 函数调用在栈上建立的活动记录 |
| 被调用者保存 | callee-saved | 被调函数需保存/复原的寄存器（如 `ebx`） |
| 调用约定 | calling convention | 参数传递/清栈规则（ cdecl） |
| x87 浮点单元 | x87 FPU | 80 位扩展精度浮点部件，寄存器栈 `st(0)`~`st(7)` |
| MMX | MultiMedia eXtensions | 64 位 SIMD 整数 packed 运算 |
| SSE / SSE2 | Streaming SIMD Extensions | 128 位 XMM 寄存器 SIMD 指令 |
| SIMD | Single Instruction Multiple Data | 单指令多数据并行 |
| 超线程 | Hyper-Threading | 一物理核暴露为两逻辑处理器 |
| CPUID 指令 | cpuid | 查询 CPU 厂商/特性的指令，功能号在 `eax` |
| 厂商 ID | vendor ID | `cpuid` 功能号 0 返回的 12 字节串（如 `GenuineIntel`） |
| 数据段 | data section (`.data`) | 存放已初始化数据 |
| BSS 段 | `.bss` section | 存放未初始化/预留空间，运行时清零 |
| 文本段 / 代码段 | text section (`.text`) | 存放指令 |
| 伪指令 / 命令 | directive / command | `.` 开头、不产机器码的汇编器指令 |
| ELF 格式 | ELF (Executiable and Linkable Format) | Linux 目标/可执行文件格式，见 `elf32-i386` |
| AT&T 语法 | AT&T syntax | GNU as 默认语法：源在左、`%` 寄存器、`$` 立即数 |
| Intel 语法 | Intel syntax | 目的在左、无 `%`/`$` 前缀的另一种语法 |
| 立即数 | immediate | 直接编码进指令的常量，AT&T 用 `$` 前缀 |
| 内存间接 / 位移 | memory indirect / displacement | `28(%edi)` 这类基址加偏移寻址 |
| 短跳转 | short jump | 相对偏移用 1 字节的 `jmp`（编码 `eb rel8`） |
| 相对寻址 | relative addressing | 跳转目标按当前 PC 加有符号偏移计算 |
| 尺寸后缀 | size suffix | `b`(byte)/`w`(word)/`l`(doubleword)/`q`(quadword) |
| doubleword | doubleword | 4 字节（IA-32 的 `l` 尺寸） |
| word | word | 2 字节 |
| byte | byte | 1 字节 |
| 系统调用 | system call (`int $0x80`) | 用户程序请求内核服务的方式 |
| 中断指令 | software interrupt `int` | 触发异常/系统调用，如 `int $0x80` |
| 段错误 | segmentation fault / SIGSEGV | 非法内存访问导致崩溃（`cpuid2` 实录） |
| 单步执行 | single-step (`ni`/`si`) | gdb 逐条指令执行；`ni` 跨过 call，`si` 跟进 call |
| 栈对齐 | stack alignment | cdecl 要求 call 前 `esp` 16 字节对齐 |
