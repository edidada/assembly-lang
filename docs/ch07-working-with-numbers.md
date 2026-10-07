# 第7章 使用数字 (Working with Numbers)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 7 章，代码为本仓库实际敲过的样例。

## 本章要点

- 整数伪指令 (pseudo-ops) 按位宽分级：`.byte`(8) < `.short`(16) < `.int`(32, long) < `.quad`(64)。`.quad` 在 32 位模式下完全可用作数据存储，汇编器会做符号扩展——`quadtest.s` 里 `.quad -333252322` 的高 32 位被填成 0xFFFFFFFF。
- 有符号数以二进制补码 (two's complement) 存储：同一串比特按有/无符号解释值不同（`inttest.s` 中 `0xffb1` 作为 16 位有符号是 −79，无符号是 65457）；退出码只截低 8 位，负数退出值会在 `echo $?` 里回绕。
- BCD (Binary-Coded Decimal, 二-十进制编码) 分打包/不打包两种；x87 协处理器提供 `fbld`/`fbstp` 直接在 10 字节打包 BCD 与浮点栈之间搬运，`bcdtest.s` 用 `fbld+fimul+fbstp` 完成了 1234×2=2468 的十进制运算。
- x87 浮点指令后缀有坑：`flds`/`fstps` 的 s 是 single(32 位)，`fldl`/`fstl` 的 l 是 long form(64 位 double)，不是整数的"32 位"；数据入栈后都转成内部 80 位扩展精度 (extended precision)。
- SIMD 三代数据：MMX 用 8 个 64 位 `mm` 寄存器（`movq`，mmxtest.s）；SSE 用 8/16 个 128 位 `xmm` 寄存器打包 4×float（movups/movaps，ssefloat.s）；SSE2 打包 2×double 并能搬任意 128 位整数（movupd/movdqu，sse2float.s、ssetest.s）。
- 对齐 (alignment)：要求 16 字节对齐的 `movaps/movapd` 遇到未对齐数据会 #GP 异常；本仓库统一用非对齐版本 `movups/movupd/movdqu`，规避 `.data` 里标号只有 4 字节对齐的现实。
- 符号标志 SF 就是"最近一次运算结果的最高位"，signtest.s 用它（配合第 6 章的 jns）作为循环开关，兼作第 6/7 章的交叉示例。

## 整数的存储与有符号表示（inttest.s / quadtest.s）

`.int -45` 汇编成 D3 FF FF FF（小端 + 补码）。`movw $0xffb1,%dx` 直接把比特模式装入 DX，CPU 不记忆"你当初是有符号还是无符号"——标志位与后续指令的选择（imul vs mul、jl vs jb）决定解释方式。quadtest.s 对比了同一组数值用 `.int`（20 字节）与 `.quad`（40 字节）存储的差异，是 64 位整数在 32 位环境下的数据布局示范（运算则要用第 8 章的 adc/sbb 链接双字，或用 fild/fist 经 x87）。

## BCD 与 x87 的十进制通道（bcdtest.s）

10 字节打包 BCD 的布局：低 9 字节各存两位十进制（低位在低地址），第 10 字节高位存符号。`fbld`（floating binary to packed BCD load 的逆操作：load packed BCD）把十进制串转成浮点数压入 ST(0)，之后可用普通 `fimul` 乘整数，`fbstp`（store and pop）再存回十进制。这条链路绕开了二进制小数无法精确表示某些十进制的问题。

## x87 标量浮点（floattest.s）

`flds/fldl` 把内存单/双精度装入寄存器栈，`fstl` 把 ST(0) 以 64 位存回内存（不清栈；带 p 的 `fstp` 才弹栈）。注意 12.34、2353.631 都不能被二进制精确表示，内存中是 IEEE 754 (电气电子工程师学会标准) 舍入值；`floattest.c` 可作 C 侧对照。

## SIMD：MMX / SSE / SSE2（mmxtest.s / ssetest.s / ssefloat.s / sse2float.s）

| 样例 | 指令 | 数据打包方式 |
|---|---|---|
| mmxtest.s | `movq mem,%mm` | 64 位：可视为 2×32 位整数或 8×字节 |
| ssetest.s | `movdqu mem,%xmm` | 128 位整数搬运（SSE2 指令） |
| ssefloat.s | `movups mem,%xmm` | 4×float 打包单精度（SSE） |
| sse2float.s | `movupd mem,%xmm` | 2×double 打包双精度（SSE2） |

本仓库这些例子只演示"装/卸"数据搬运，未做打包运算（padd/pmul 等在书中更后位置；仓库中亦无对应文件）。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| inttest.s | 有符号整数的装入与负退出码 | `movl $-345,%ecx` / `movw $0xffb1,%dx` |
| quadtest.s | `.int` 与 `.quad` 存储 64 位值 | `.quad 1, -1, 463345, -333252322, 0` |
| bcdtest.s | 打包 BCD 十进制乘 2 | `fbld data1` / `fimul data2` / `fbstp data1` |
| signtest.s | SF 作循环条件（倒序打印数组） | `dec %edi` / `jns loop` |
| mmxtest.s | 64 位 MMX 寄存器装载 | `movq values1, %mm0` |
| ssetest.s | 128 位 XMM 装载整数数据 | `movdqu values1, %xmm0` |
| ssefloat.s | 打包单精度 float 搬运 | `movups value1,%xmm0` / `movups %xmm0,data` |
| sse2float.s | 打包 double 搬运 | `movupd value1,%xmm0` / `movupd %xmm0,data` |
| floattest.s | x87 单/双精度装入与存出 | `flds value1` / `fldl value2` / `fstl data` |

## 逐文件详解

### inttest.s

`inttest.s:5-11`：

```asm
data:
	.int -45
...
	movl $-345, %ecx
	movw $0xffb1, %dx
	movl data, %ebx
```

终值：ECX = −345 = 0xFFFFFEA7（内存/寄存器里只有补码比特）；DX 装入比特模式 0xFFB1，按有符号 16 位解释是 −79，按无符号是 65457，指令本身不做裁决；EBX = −45。随后 `exit(ebx)`：Linux 退出码只取 ebx 低 8 位，−45 & 0xFF = 0xD3 = 211，所以 `echo $?` 显示 211 而不是 −45——用 shell 观测有符号整数是本章最直观的一课。

### quadtest.s

`quadtest.s:5-7`：

```asm
data1:
	.int 1, -1, 463345, -333252322, 0
data2:
	.quad 1, -1, 463345, -333252322, 0
```

data1 共 20 字节，data2 共 40 字节，两组数值本身都在 32 位范围内。`.quad` 对每个值按 8 字节小端输出：`1` → `01 00 00 00 00 00 00 00`，`-1` → 8 个 FF，`-333252322` 的高 4 字节是符号扩展的 `FF FF FF FF`。程序无运算、exit(0)。用 `objdump -s -j .data` 可直接看到两个标签相隔 20 字节。要点：32 位 ELF 存 64 位数据没有任何障碍，只是 `mov` 一次搬不动，需 `movl 数据,%eax / movl 数据+4,%edx` 成对处理（仓库内未见示例，可自行加）。

### bcdtest.s

`bcdtest.s:11-13`：

```asm
	fbld data1
	fimul data2
	fbstp data1
```

data1 初始 `.byte 0x34, 0x12, 0×8`，按打包 BCD（低位在低地址）读作十进制 1234；data2 = 整数 2。`fbld` 把 10 字节 BCD 转成 80 位浮点 1234.0 压入 ST(0)；`fimul data2` 内存整数直接参与乘法，ST(0)=2468.0；`fbstp` 转换回打包 BCD 弹出存回 data1。执行后 data1 应变为 `68 24 00 … 00`（低字节 0x68 存个位 8、十位 6，次字节 0x24 存百位 4、千位 2，符号位为正），可用 gdb `x/10xb &data1` 验证；第 10 字节的具体编码（符号在高半字节）建议实测确认，不要凭记忆下结论。程序 exit(0)。

### signtest.s（第 6 章控制流 × 第 7 章符号语义的交叉样例）

`signtest.s:10-17`：

```asm
	movl $9, %edi
loop:
	pushl value(, %edi, 4)
	pushl $output
	call printf
	add $8, %esp
	dec %edi
	jns loop
```

`value(,%edi,4)` 是第 5 章的变址寻址；`pushl 内存操作数` 直接把数组元素压栈作 printf 参数。循环终止不用 cmp，而是吃 `dec %edi` 的副作用：DEC 置 SF=结果最高位。EDI 从 9 递减：9→…→1 后 `dec` 得 0，0 的最高位是 0，SF=0，`jns` 继续跳——所以下标 0 的元素也会被打印；再一轮后 EDI=−1，补码最高位 1，SF=1，`jns` 不成立退出。打印顺序为 2, 10, 80, 32, 50, 6, 11, 34, 15, 21（逆序 10 个数），exit(0)。这个写法精巧但危险：把"负数=越界"当循环条件依赖的是有符号语义，若数组长度是 2^31 之类就会提前/失效，工程代码应当显式 `cmp $0,%edi; jl` 或用无符号 `jne`+哨兵。

### mmxtest.s

`mmxtest.s:11-12`：

```asm
	movq values1, %mm0
	movq values2, %mm1
```

`movq`（MMX 形态，move quadword=64 位）把内存 8 字节装入 MMX (MultiMedia Extensions, 多媒体扩展) 寄存器。values1 = `.int 1,-1` 恰好 8 字节，小端拼成 mm0 = 0xFFFFFFFF00000001，之后可当两个 32 位整数用。values2 是 8 个 `.byte`，mm1 = 0x0100E44732FF0510（b7..b0 = 01 00 E4 47 32 FF 05 10），演示"同一段指令、不同切片解释"。程序不打印，验证需 gdb `info registers mm0 mm1` 或 objdump 确认指令编码。要点：MMX 寄存器与 x87 栈物理复用（EMMS 用于切换回 x87 状态），本例没有混用所以没写 emms。

### ssetest.s

`ssetest.s:11-12`：

```asm
	movdqu values1, %xmm0
	movdqu values2, %xmm1
```

xmm0 装载 16 字节 = 4×`.int`：dword0=1、dword1=0xFFFFFFFF(−1)、dword2=0、dword3=0x2104E(135246)。xmm1 装载 `.quad 1,-1`：低 8 字节 qword=1、高 8 字节 qword=−1。`movdqu`（move double quadword unaligned，128 位非对齐搬运）属于 SSE2 指令集，可搬任意类型数据——书中对齐版本 `movdqa` 要求数据 16 字节对齐，本例 values1 只有 4 字节对齐，选 movdqu 是稳妥的。退出码 0。

### ssefloat.s

`ssefloat.s:13-16`：

```asm
	movups value1, %xmm0
	movups value2, %xmm1
	movups %xmm0, %xmm2
	movups %xmm0, data
```

`.float` 汇编成 4 字节 IEEE 754 单精度：value1 起 16 字节正好是 4 个打包 float (packed single-precision)，`movups`（SSE, unaligned packed single）一次搬 128 位；value2 紧随其后（第 5-7 行两块 16 字节连续）。第 15-16 行演示寄存器间和寄存器→`.bss` 的两种目的地；`.lcomm data,16` 预留 16 字节（bss 对齐不保证 16，movups 不挑剔，依然安全）。data 里最终是 12.34, 2345.543, −3493.2, 0.44901 四个单精度的比特形态。退出码 0。

### sse2float.s

`sse2float.s:13-16`：

```asm
	movupd value1, %xmm0
	movupd value2, %xmm1
	movupd %xmm0, %xmm2
	movupd %xmm0, data
```

与 ssefloat.s 同构，只是数据换成 `.double`、每容器 2 个打包双精度 (packed double-precision)，指令换成 SSE2 的 `movupd`。value1 = {12.34, 2345.543}，value2 = {−5439.234, 32121.4}，各 16 字节；data 收到 xmm0 的 16 字节。要点：SSE 管 float、SSE2 管 double（对 XMM 而言），但整数 128 位搬运反而归 SSE2（movdqu）——三条指令 unaligned 后缀 u 各不相同的归属值得背下来。

### floattest.s

`floattest.s:13-15`：

```asm
	flds value1
	fldl value2
	fstl data
```

`flds` 读 value1 的 4 字节单精度 12.34 转成 80 位扩展精度压栈；`fldl` 读 value2 的 8 字节双精度 2353.631 再压栈——此后 ST(0)=2353.631、ST(1)=12.34（后入栈者在栈顶，与直觉相反）。`fstl` 把 ST(0) 舍入成 64 位双精度存入 data（8 字节），且不弹栈。内存终值：data = 2353.631 的 IEEE 754 双精度编码，小端字节序 `8D 97 6E 12 43 63 A2 40`（可用 `x/8xb &data` 验证）。注意后缀 l 在这里是 "long form = 64 位浮点"，与整数指令里 l=32 位完全不同，这是 x87 助记符最坑的一条。对照 `floattest.c` 可确认 C 的 float/double 与这里一致。

## 实践与踩坑

- 退出码观测有符号数：inttest.s 的 −45 显示为 211。想打印负数请用 printf（`pushl %ebx; pushl $fmt; call printf`），int $0x80 的 exit 只给 8 位无符号回绕值。
- x87 后缀歧义：`fldl`/`fstl` 操作 8 字节不是 4 字节；写成 `fldl value1`（对 4 字节 .float 标签）会把相邻标签的后 4 字节当数读走，汇编不报错。仓库里 floattest.s 用 `.lcomm data,8` 配 `fstl`，是对的；改指令位宽前先核对数据声明。
- `fbld` 固定吃 10 字节：data1 必须有 10 个 `.byte` 的空间，短了会越界读入相邻数据（bcdtest.s 恰好给了 10 个）。
- 对齐异常：把 movups/movupd/movdqu 换成 movaps/movapd/movdqa 前，必须确认操作数 16 字节对齐（`.align 16`），否则运行时 `SIGGP/SIGSEGV`。本仓库样本没写 `.align`，请沿用 u 系列。
- MMX/SSE 指令的汇编与运行分离：老 CPU 或某些汇编器配置会对 `movq %mm`、`movdqu` 报"not supported in this architecture"，可在文件头加 `.arch` 相关伪指令或升级 binutils；本仓库文件未加，汇编失败时先查 `as --version`。
- printf 与 SIMD 栈：这些文件每个只碰一种引擎（x87 或 MMX 或 SSE），未混用；x87 栈与 MMX 物理复用，混用不 EMMS 会出错，模仿时保持隔离。
- signtest.s 依赖 DEC 的 SF 副作用，读代码时容易误以为少写了 cmp；改循环次数（比如起始 10）会直接破坏终止条件（0 与 −1 的行为差一轮），这是"标志位复用"型代码的典型脆弱性。

## 复习清单

- [ ] 写出 −345 的 32 位补码与 −45 的退出码回绕值，并解释 `movw $0xffb1,%dx` 两种解释下的数值。
- [ ] 计算 `.quad -333252322` 在小端内存里的 8 个字节，说明高 4 字节为何全 FF。
- [ ] 推演 bcdtest.s 三步之后 data1 的前两个字节并 gdb 验证。
- [ ] 说明 flds/fldl/fstl 各自搬运几条指令字节，以及两次 fld 后 ST(0)/ST(1) 分别是谁。
- [ ] 区分 movq(MMX)/movdqu(SSE2)/movups(SSE)/movupd(SSE2) 的位宽、对齐要求与所属扩展。
- [ ] 解释 signtest.s 为何会打印下标 0 的元素、又为何在 EDI=−1 时退出（SF 与补码最高位的关系）。
