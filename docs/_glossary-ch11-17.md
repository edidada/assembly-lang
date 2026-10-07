# 专业名词中英对照表（第11~17章）

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 11~17 章，代码为本仓库实际敲过的样例。

覆盖 ch11 函数、ch12 系统调用、ch13 内联汇编、ch14 汇编库、ch15 优化、ch16 文件、ch17 高级 IA-32 特性。

## 第11章 使用函数

| 英文 | 中文 | 释义（结合本仓库样例） |
|---|---|---|
| function | 函数 | 可复用子程序；call/ret 配对，如 area、square |
| calling convention | 调用约定 | 参数/返回/清栈/寄存器保全的双方协议 |
| cdecl | C 声明约定 | 参数右到左入栈、调用者清栈、整型经 %eax 返回 |
| stack frame | 栈帧 | 一次调用的参数+局部量+保存寄存器的栈区间 |
| base pointer (ebp) | 基址指针 | 帧锚点；参数在 8(%ebp) 起，局部量在负偏移 |
| prologue / epilogue | 序言 / 尾声 | pushl %ebp…建立帧 / movl %ebp,%esp; popl %ebp; ret |
| return address | 返回地址 | call 压栈、ret 弹出；位于 4(%ebp) |
| caller cleanup | 调用者清栈 | `addl $4, %esp`（functest1.s:15 等） |
| external function | 外部函数 | 本文件无定义、链接期解析（functest2.s 的 area） |
| callee-saved register | 被调用者保存寄存器 | %ebx/%ebp/%esi/%edi；asmfunc.s push/pop %ebx |

## 第12章 使用Linux系统调用

| 英文 | 中文 | 释义 |
|---|---|---|
| system call (syscall) | 系统调用 | 用户态请求内核服务；32 位经 int $0x80 |
| software interrupt | 软中断 | `int $0x80` 触发的陷入机制 |
| syscall number | 系统调用号 | 放 %eax：1=exit, 4=write, 20=getpid, 162=nanosleep |
| file descriptor (fd) | 文件描述符 | 小整数句柄；1=stdout，open 返回值 |
| return value | 返回值 | 回到 %eax；负值即错误码（无 errno 变量） |
| error code (errno) | 错误码 | 内核返回 -N；`test %eax,%eax; js` 判负 |
| timespec | 时间结构 | 秒+纳秒两 .int（nanotest.s:3-4） |
| entry point (_start) | 入口点 | 直链时 argc 在 (%esp)、argv 在 4(%esp) 起 |
| glibc startup convention | glibc 启动约定 | 进 main 时 argc 在 %eax、argv 在 %ecx |
| CPUID | CPU 标识指令 | 查厂商/特性；leaf 0 串在 ebx:edx:ecx |

## 第13章 使用内联汇编

| 英文 | 中文 | 释义 |
|---|---|---|
| inline assembly | 内联汇编 | asm("模板":输出:输入:破坏) 嵌在 C 里 |
| constraint | 约束 | "a"/"d"/"c"/"r" 指定寄存器或任意寄存器 |
| output operand | 输出操作数 | `=a`(result)：模板编号 %0 |
| input operand | 输入操作数 | `d`(data1)：模板编号顺延 |
| clobber list | 破坏描述表 | 声明 asm 踩了哪些寄存器；pusha/popa 是其粗暴替代 |
| register constraint | 寄存器约束 | 把操作数钉死在特定寄存器（regtest1.c） |
| statement expression | 语句表达式 | GNU `({ ... })`，使汇编宏可带副作用（mactest2.c） |
| numeric (local) label | 数字/局部标号 | 0:/1: 与 0f/1f 前向引用，宏多次展开不重名 |
| `#APP` / `#NO_APP` | 汇编块标记 | gcc -S 产物中内联汇编的起止标记（globaltest.s:35-44） |
| common symbol (.comm) | 公共符号 | 未初始化全局的 .s 表示法（globaltest.s:15） |
| literal pool / .LC | 常量池 | float 字面量的整数位模式存放（vartest.s:64-65） |

## 第14章 调用汇编库

| 英文 | 中文 | 释义 |
|---|---|---|
| library / static archive | 库 / 静态归档 | 一组 .o 打包：ar/ranlib，链接用 -l 或直接列 .o |
| symbol export (.globl) | 符号导出 | 让链接器可见；`.globl square` |
| `.type ..., @function` | 符号类型注解 | 标为函数，利于工具链处理 |
| floating-point return (st(0)) | 浮点返回 | C 的 float/double 函数把结果留在 FPU 栈顶（areafunc.s） |
| pointer return | 指针返回 | 字符串函数返回 char*，缓冲须在 .bss（cpuidfunc.s） |
| FPU stack imbalance | FPU 栈失衡 | st(0) 返回协议每调用一次多压一值；fmulp/emms 可清 |
| signed integer | 有符号整数 | 符号扩展移动（inttest.s:9-11） |
| `.code32` | 代码位宽声明 | 强制 32 位指令编码 |

## 第15章 优化例程

| 英文 | 中文 | 释义 |
|---|---|---|
| frame pointer omission | 帧指针省略 | -O2 叶函数不建 ebp 帧，参数 4(%esp) 直读（condtest2.s:12-13） |
| conditional move (cmov) | 条件移动 | cmovl 用标志选值，消灭分支（condtest2.s:17） |
| branch / branch prediction | 分支/分支预测 | jle/jg 等控制流；cmov 服务于预测失败代价 |
| loop restructure | 循环改写 | for→while 测试后置、jne 单回边（sums2.s:20-24） |
| trip-count guard | 循环次数特判 | `testl %ecx,%ecx; jle` 先排空循环（sums2.s:13-14） |
| strength reduction | 强度削减 | `sall $2`+`addl` 代 i*5（for.s:21-25） |
| constant folding / pre-calculation | 常量折叠/预计算 | 编译期算出 250、55、30 的立即数（calctest2.s:25 等） |
| function inlining | 函数内联 | -O2 把调用点折叠/内联（condtest2.s main） |
| common subexpression elimination (CSE) | 公共子表达式消除 | a*b 三处只算一次（csetest.c:6-8） |
| register allocation | 寄存器分配 | 循环变量上寄存器、零访存（sums2.s:12-24） |
| code alignment (.p2align) | 代码对齐 | 热循环入口填充对齐（sums2.s:18-19） |
| hot section (.text.startup) | 热段划分 | main 进 .text.startup（vartest2.s:7-8） |
| __printf_chk | 带检查的 printf | -O2/_FORTIFY 下 printf 的替代（vartest2.s:33） |
| macro | 宏 | 文本替换、无类型检查（mactest1.c 的 SUM） |
| `rep ret` | （伪）重复返回 | AMD 取指规避写法，等价 ret（condtest2.s:19） |

## 第16章 使用文件

| 英文 | 中文 | 释义 |
|---|---|---|
| open (syscall 5) | 打开 | ebx=路径、ecx=flags、edx=mode；返回 fd |
| flags (O_WRONLY/O_CREAT/O_TRUNC) | 标志位 | 01101（八进制）=1|0100|01000（cpuidfile.s:21） |
| permission mode | 权限模式 | 0644 = rw-r--r--，受 umask 裁剪 |
| close (syscall 6) | 关闭 | 释放 fd；demo 里与正常出口共用（cpuidfile.s:37-44） |
| fall-through | 顺序落入 | badfile 既是错误出口也是收尾（cpuidfile.s:41-44） |
| output redirection to file | 文件输出 | 同数据三出口：fd1/printf/文件 |

## 第17章 使用高级IA-32特性

| 英文 | 中文 | 释义 |
|---|---|---|
| leaf (CPUID) | 叶（功能号） | %eax 选功能：0=厂商串 |
| MMX | 多媒体扩展 | 64 位 %mm 寄存器、打包整数；movq 装载（mmxtest.s） |
| SIMD | 单指令多数据 | MMX/SSE 的并行数据模型 |
| SSE / SSE2 | 流扩展指令集 | 128 位 %xmm；SSE2 增双精度 |
| packed data | 打包数据 | .int/.quad/.float/.double 与 movdqu/movups/movupd 对应 |
| unaligned move | 非对齐移动 | movdqu/movups/movupd；对齐版 movdqa/movaps/movapd |
| compare-and-exchange (cmpxchg) | 比较交换 | %eax 对目的数；等则源→目的、ZF=1，否则目的→%eax（cmpxchgtest.s:9-11） |
| cmpxchg8b | 64 位比较交换 | EDX:EAX 比较、ECX:EBX 新值（cmpxchg8Btest.s:9-13） |
| atomic operation | 原子操作 | 配 lock 前缀才是多处理器原子（demo 单线程省略） |
| zero flag (ZF) | 零标志 | 比较交换的成功/失败报告位 |
| RDTSC / timestamp counter | 读时间戳计数器 | 书中第 17 章计时指令——本仓库暂无实现，nanotest.s 用的是 nanosleep |
| emms | MMX 状态清空 | MMX 与 x87 共享物理栈后的复位指令 |
