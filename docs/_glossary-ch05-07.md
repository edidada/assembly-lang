# 术语表：第 5~7 章专业名词中英对照

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 5~7 章，代码为本仓库实际敲过的样例。

覆盖 `docs/ch05-transferring-data.md`、`docs/ch06-controlling-execution.md`、`docs/ch07-working-with-numbers.md` 三篇笔记中出现的术语；括注该术语主要落在哪一章的哪个样例。

## 指令与寻址（第 5 章）

| 英文 | 中文 | 说明 / 仓库样例 |
|---|---|---|
| MOV (move instruction) | 传送指令 | 比特拷贝，不改标志位（movtest1~4.s） |
| AT&T syntax | AT&T 语法 | 源在前目的在后，`$` 立即数、`%` 寄存器（全部样例） |
| immediate / register / memory operand | 立即数 / 寄存器 / 内存操作数 | `movl $100,4(%edi)` 同时含立即数与内存（movtest4.s:11） |
| direct (absolute) addressing | 直接（绝对）寻址 | `movl value,%ecx`（movtest1.s:8） |
| indirect addressing | 间接寻址 | `movl $values,%edi` + `4(%edi)`（movtest4.s） |
| indexed addressing, `disp(base,index,scale)` | 变址寻址 | `values(,%edi,4)`（movtest3.s:14、movtest4.s:13） |
| effective address | 有效地址 | disp + base + index×scale |
| PUSH / POP | 压栈 / 出栈 | ESP 先减后写 / 先读后加（pushpop.s） |
| LIFO (last in first out) | 后进先出 | pushw 必须 popw 配对（pushpop.s:13/21） |
| full descending stack | 全递减栈 | 栈顶在低地址 |
| `.data` / `.text` / `.bss` section | 数据段 / 代码段 / 未初始化数据段 | sizetest1~3.s |
| `.lcomm` / `.comm` | 局部/全局通用声明伪指令 | bss 预留，不占文件体积（sizetest2.s:3） |
| `.fill` / `.int` / `.byte` / `.quad` / `.asciz` | 存储伪指令 | sizetest3.s:4、movtest3.s:6 |
| `movz*` / movsx (zero/sign extend) | 零扩展 / 符号扩展传送 | 笔记提及，仓库暂无对应文件 |

## 执行流程与标志位（第 6 章）

| 英文 | 中文 | 说明 / 仓库样例 |
|---|---|---|
| status flags (CF, ZF, SF, OF, PF, AF) | 状态标志位：进位、零、符号、溢出、奇偶、半进位 | cmp/dec 置位，jcc 读取（cmptest.s、signtest.s） |
| CMP (compare) | 比较指令 | `cmp src,dst` 算 dst−src（cmptest.s:8） |
| unconditional jump (`JMP`) | 无条件跳转 | jumptest.s:7 |
| conditional jump (JCC, e.g. jge/jns/jne/jnz) | 条件跳转 | jge=SF==OF（cmptest.s:9）；jns=SF=0（signtest.s:17） |
| signed / unsigned condition codes | 有符号 / 无符号条件码 | jl/jge 类看 SF、OF；jb/ja 类看 CF（cmovtest.s 用无符号 a） |
| LOOP | 循环指令 | 隐含 dec ECX + jne（loop.s:12） |
| JCXZ | ECX 为零则跳转 | 空循环哨兵（betterloop.s:10） |
| CALL / RET | 过程调用 / 返回 | 压/弹返回地址（calltest.s） |
| calling convention (cdecl) | 调用约定 | 参数右起入栈、调用方 `add $8,%esp` 清栈（loop.s:16、calltest.s:12） |
| prologue / epilogue | 序言 / 跋文 | calltest.s:21-29 的非标准骨架（pushl %esp 而非 pushl %ebp） |
| stack frame | 栈帧 | overhere 中 ebp 指向保存的 esp 副本 |
| CMOVcc (conditional move) | 条件传送 | `cmova`：CF=0 且 ZF=0 时传送（cmovtest.s:16） |
| XCHG (exchange) | 交换指令 | register-memory 原子交换（bubble.s:16；指令本身属第 5 章） |
| bubble sort | 冒泡排序 | bubble.s，双计数器 ECX/EBX |
| dead code | 死代码 | jumptest.s:8-9 |

## 数的表示与 SIMD（第 7 章）

| 英文 | 中文 | 说明 / 仓库样例 |
|---|---|---|
| signed integer / two's complement | 有符号整数 / 二进制补码 | `.int -45`（inttest.s:5） |
| sign extension | 符号扩展 | `.quad -1` 高 4 字节全 FF（quadtest.s:7） |
| long / quadword integer | 双字(32 位) / 四字(64 位)整数 | `.int` vs `.quad`（quadtest.s） |
| BCD (binary-coded decimal) | 二-十进制编码 | `.byte 0x34,0x12` = 十进制 1234（bcdtest.s:5） |
| packed BCD (10-byte) | 打包 BCD（10 字节） | fbld/fbstp 的对象（bcdtest.s:11,13） |
| FBLD / FBSTP | BCD 装入 / 存出并弹栈 | x87 十进制通道（bcdtest.s） |
| FLD / FST (flds/fldl/fstl) | 浮点装入 / 存出 | s=single 32 位，l=long form 64 位（floattest.s:13-15） |
| FIMUL | 内存整数乘 ST(0) | bcdtest.s:12 |
| x87 FPU stack, ST(0) | x87 协处理器寄存器栈 | 后入栈者为 ST(0)（floattest.s） |
| IEEE 754 single / double / extended precision | 单精度 / 双精度 / 扩展精度 | `.float`/`.double`，内部 80 位（floattest.s、ssefloat.s、sse2float.s） |
| sign flag as loop guard | 以符号标志作循环条件 | `dec %edi; jns loop`（signtest.s:16-17） |
| MMX (MultiMedia Extensions) | 多媒体扩展 | 64 位 mm 寄存器，movq（mmxtest.s） |
| MOVQ (MMX form) | 64 位传送 | `movq values1,%mm0`（mmxtest.s:11） |
| SSE / SSE2 (Streaming SIMD Extensions) | 流式单指令多数据扩展 | xmm 128 位；SSE 管 float、SSE2 管 double 与整数 128 位（ssetest.s、ssefloat.s、sse2float.s） |
| SIMD (single instruction multiple data) | 单指令多数据 | 一条 movups 搬 4 个 float |
| packed single / packed double | 打包单精度 / 打包双精度 | 4×float、2×double（ssefloat.s、sse2float.s） |
| MOVUPS / MOVUPD / MOVDQU | 非对齐 128 位搬运 | u=unaligned（ssefloat.s:13、sse2float.s:13、ssetest.s:11） |
| MOVAPS / MOVAPD / MOVDQA | 对齐 128 位搬运 | 需 16 字节对齐，否则 GP 异常（笔记对照，仓库未用） |
| alignment | 对齐 | .data 标号默认仅 4 字节对齐，故样例全用非对齐版本 |
| EMMS | MMX 状态清空 | MMX 与 x87 共用物理寄存器（mmxtest.s 未混用故未出现） |

## 通用 / 环境

| 英文 | 中文 | 说明 |
|---|---|---|
| ELF (Executable and Linkable Format) | 可执行与可链接格式 | 本仓库产物格式，`size` 看段体积 |
| system call via `int $0x80` | 软中断系统调用 | eax=1 为 exit，ebx 为退出码（全部样例） |
| exit status | 退出码 | shell `echo $?` 观测，仅低 8 位（inttest.s 的 −45 → 211） |
| flat memory model | 平坦内存模型 | 32 位保护模式下无段基址偏移 |
