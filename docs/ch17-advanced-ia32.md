# 第17章 使用高级IA-32特性(Advanced IA-32 Features)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 17 章，代码为本仓库实际敲过的样例。

## 本章要点

- CPUID 指令：`%eax` 选叶（leaf），返回厂商/型号/特性位；leaf 0 的 12 字节厂商串按 `%ebx`→`%edx`→`%ecx` 顺序排列。
- MMX：64 位 `movq` 在整数寄存器与 `%mm0-%mm7` 间搬打包数据；GNU as 用 `.int/.byte` 直接喂数据。
- SSE/SSE2：128 位 `%xmm` 寄存器；非对齐移动 `movdqu`/`movups`/`movupd` 一个指令族对应整型包、单精度四联、双精度对联。
- `cmpxchg`/`cmpxchg8b` 比较交换（compare-and-exchange）：隐式用 `%eax`（或 `%edx:%eax`）比较、ZF 报告结果，是无锁同步（lock-free synchronization）的原子原语。
- 系统调用与 CPU 指令的组合示范：cpuid 取信息 + int $0x80 报信息。
- 这些样例全部带 `.code32`，在 64 位机器上以 32 位模式汇编，SSE 指令需要 CPU 支持（现代 x86 一律满足）。

## 一、CPUID：三条路径看同一数据

**cpuid.s**（裸 syscall 版，`_start` 入口）：

```
	movl $0, %eax
	cpuid
	movl $output, %edi
	movl %ebx, 28(%edi)
	movl %edx, 32(%edi)
	movl %ecx, 36(%edi)
```
（cpuid.s:8-13）

把厂商串原地打进带 `xxxxxxxxxxxx` 占位的消息（cpuid.s:3-4），再 write(fd=1)。`%edi` 相对寻址 28/32/36 要求手数前缀长度——改文案必须改偏移。

**cpuid2.s**（C 库版）：结果先收进 `.lcomm buffer, 12` 静态缓冲（`movl %ebx, (%edi)`、`movl %edx, 4(%edi)`、`movl %ecx, 8(%edi)`，cpuid2.s:13-16）再 `pushl $buffer; call printf`（cpuid2.s:17-19）。.bss 恒零初始化，但 12 个字符**不含结尾 NUL**：printf 会读到第 13 字节才碰巧撞上 0——侥幸正确，见踩坑 2（对照 cpuidfunc.s 的 `.comm output, 13`，第 14 章）。

**cpuid.txt**：cpuidfile.s 落盘产物，内容 `the processor vendor ID is 'GenuineIntel'`（cpuid.txt:1），三种出口殊途同归。

## 二、MMX：mmxtest.s

`movq values1, %mm0` / `movq values2, %mm1`（mmxtest.s:11-12）：
- `values1: .int 1, -1` 两个 32 位整数打包成一个 64 位块进 `%mm0`；`values2` 八个 `.byte`（0x10, 0x05, 0xff, 0x32, 0x47, 0xe4, 0x00, 0x01）按字节打包进 `%mm1`——演示 MMX（MultiMedia eXtensions）的同宽 SIMD 数据视角。
- 程序没有运算，直接 exit(1)（mmxtest.s:13-15）：数据"看得见"要靠调试器（`info reg mm0`）。
- MMX 状态与 x87 共用物理寄存器堆，用完应 `emms` 复位——本例没算所以没清。

## 三、SSE/SSE2：三个 mov 变体

| 文件 | 指令 | 搬运内容 |
|---|---|---|
| ssetest.s | `movdqu values1, %xmm0`（ssetest.s:11-12） | 四个 `.int`（含 -1、135246）打包 128 位；values2 两个 `.quad` |
| ssefloat.s | `movups value1, %xmm0`（ssefloat.s:13-16） | 四个 `.float`（12.34 等）；xmm0→xmm2、xmm0→data（`.lcomm data, 16`） |
| sse2float.s | `movupd value1, %xmm0`（sse2float.s:13-16） | 两个 `.double` 共 128 位；同样展示寄存器间与内存间双向移动 |

- `movdqu`（未对齐整型包）、`movups`（未对齐单精度四联 pack）、`movupd`（未对齐双精度对联）是 unaligned 系列：不要求 16 字节对齐，代价略慢；对齐版是 `movdqa/movaps/movapd`。
- 三个文件结构完全平铺：装填→exit，教学意图就是"数据类型伪指令 × 移动指令"的矩阵组合（`.int/.quad/.float/.double` 对上 `movq/movdqu/movups/movupd`）。
- 寄存器对寄存器也在其中：`movups %xmm0, %xmm2`（ssefloat.s:15、sse2float.s:15）演示 SIMD 寄存器可直接互搬。

## 四、cmpxchg 与 cmpxchg8b：比较交换

**cmpxchgtest.s**（32 位版）：`movl $10, %eax`、`movl $5, %ebx` 后执行 `cmpxchg %ebx, data`（cmpxchgtest.s:9-11，`data: .int 10` 见 cmpxchgtest.s:4-5）。

语义：把 `%eax` 与目的操作数 `data` 比较——相等则置 `ZF=1` 并把 `%ebx`（源）写入 data；不等则 `ZF=0` 并把 data 现值装入 %eax。本例 eax=10==data=10，所以 data 被原子替换为 5。AT&T 写法里目的写在后（`cmpxchg %ebx, data`），比较用的累加器是隐含的——GNU as 接受不加锁前缀的用法（锁语义需 `lock` 前缀，见踩坑 4）。

**cmpxchg8Btest.s**（64 位版，Pentium 起）：

```
	movl $0x44332211, %eax
	movl $0x88776655, %edx
	movl $0x11111111, %ebx
	movl $0x22222222, %ecx
	cmpxchg8b data
```
（cmpxchg8Btest.s:9-13，`data: .byte 0x11,...,0x88` 见 cmpxchg8Btest.s:4-5）

比较值 `EDX:EAX` = 0x88776655_44332211；小端存放的 `.byte 0x11,0x22,...,0x88` 拼出的 64 位量恰是同一值 → 匹配，ZF=1，新值 `ECX:EBX` = 0x22222222_11111111 写入 data。四个寄存器各司其职（隐式约定，连汇编器都不帮你查），是"用对寄存器比写对指令更难"的典型。

## 五、关于计时：nanotest.s 的归属说明

任务清单把 nanotest.s 也列入本章（书中第 17 章以 RDTSC 讲解 CPU 计时，read timestamp counter）。**本仓库的 nanotest.s 没有 RDTSC**：它用 `nanosleep`（`movl $162, %eax`，nanotest.s:23-26）做 5 秒挂起，是第 12 章的系统调用样例。全仓库 grep 无 `rdtsc` 出现。因此本章按实际代码收录：nanotest.s 演示的是"进程级暂停计时"而非"指令级时间戳"；RDTSC 样例在本仓库属于未敲部分，不在此伪造。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| cpuid.s | CPUID leaf 0 + 占位串改写 + write 输出（_start 版） | `movl %ebx, 28(%edi)` 三连 |
| cpuid2.s | CPUID 结果进 .bss 缓冲后 printf | `.lcomm buffer, 12`；缺 NUL 的隐患 |
| cpuid.txt | 文件出口的实物证据 | GenuineIntel 输出行 |
| mmxtest.s | MMX 64 位打包数据装载 | `movq values1, %mm0` |
| ssetest.s | SSE 128 位整型包 | `movdqu values1, %xmm0` |
| ssefloat.s | SSE 单精度四联移动 | `movups value1, %xmm0`；`movups %xmm0, data` |
| sse2float.s | SSE2 双精度对联移动 | `movupd value2, %xmm1` |
| cmpxchgtest.s | 32 位比较交换（成功路径） | `cmpxchg %ebx, data` |
| cmpxchg8Btest.s | 64 位比较交换（EDX:EAX 对 ECX:EBX） | `cmpxchg8b data` |
| nanotest.s | （第 12 章归属）nanosleep 暂停计时 | `movl $162, %eax`；仓库无 RDTSC |

## 逐文件详解

- **cpuid.s vs cpuid2.s vs cpuidfunc.s（第 14 章）**：同一段 cpuid 数据，三种包装——占位串直 write、静态缓冲+printf、函数返回指针。对照三者能体会"数据摆放自由度"：cpuid.s 把结果嵌进消息体（偏移 28 起），cpuid2.s/cpuidfunc.s 让结果独立成串。
- **mmxtest.s**：`values2` 的 8 字节选择（0xff、0x01 等）就是为了让调试器里能逐字节认出边界；`.code32`（mmxtest.s:2）强制 32 位。
- **ssefloat.s / sse2float.s**：两文件互为镜像（float 四联 vs double 对联），data 都是 `.lcomm data, 16` 正好一个 XMM 宽度，验证"寄存器→内存"路径。
- **cmpxchgtest.s**：若想验证"不等"分支，把 `movl $10, %eax` 改成别的值，data 不变、%eax 变 10，ZF=0——文件里没有这个分支的检查指令（如 sete），留作练习。
- **cmpxchg8Btest.s**：退出时 `movl $0, %ebx; movl $1, %eax`（cmpxchg8Btest.s:14-15）把 ebx 归零——它刚被当作新值低 32 位用过。

## 实践与踩坑

1. **CPUID 的 EBX 冲突**：`-fPIC` 的 C 环境里 cpuid 砸 %ebx 需要保护；本仓库两个手写版都直接在裸 main/_start 里用，没有这个问题，但 cpuidfunc.s（第 14 章）特意 push/pop 了。
2. **12 字节缓冲不是字符串**：cpuid2.s 的 `buffer` 无 NUL，printf 输出在多数系统"看起来正常"纯属 .bss 后续字节为零；严谨做法是 `.lcomm buffer, 13` 或手动置零（对照 cpuidfunc.s:3 的 13）。
3. **movups 装 xmm 的偏移对齐**：本例数据自然对齐或未对齐均可，`movups` 不报错；换成 `movaps` 且数据非 16 对齐会触发 general protection fault（#GP），调试时非常不直观。
4. **cmpxchg 不加 lock 不原子**：demo 是单线程所以无所谓；真正做多处理器锁自由计数要写 `lock cmpxchg`。GNU as 里 `lock cmpxchg %ebx, data` 即可。
5. **cmpxchg8b 在 32 位下操作数是 m64**：`data` 需 8 字节可写内存；写成寄存器目的会报错。文件名大小写（cmpxchg8Btest.s 的 B）只是命名习惯，指令本身小写 `cmpxchg8b`。
6. **MMX/SSE 共存**：MMX 寄存器别名于 x87，SSE 独立；混用 MMX 后不调 `emms` 再用 x87 会看到 FPU 栈脏数据（第 8 章 finit 可复位）。

## 复习清单

- [ ] 说出 cpuid leaf 0 返回值的寄存器排布与厂商串拼接顺序。
- [ ] 区分 movq(MMX) / movdqu / movups / movupd 各自的宽度、对齐要求与数据类型族。
- [ ] 默写 cmpxchg 的两分支语义（相等：源→目的、ZF=1；不等：目的→eax、ZF=0），并解释 cmpxchg8b 中 EDX:EAX、ECX:EBX 的角色。
- [ ] 说明 .lcomm buffer,12 打印 %s 的风险与两种修正。
- [ ] 明确 nanotest.s 属第 12 章 nanosleep 演示，仓库没有 RDTSC 代码。
