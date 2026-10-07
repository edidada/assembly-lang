# 第14章 调用汇编库(Using Assembly Language Libraries)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 14 章，代码为本仓库实际敲过的样例。

## 本章要点

- 把常用汇编函数集中成库（library）：单文件单函数、`.globl` 导出，链接时用 `gcc main.c lib.o` 或归档成 `.a` 静态库（archive，`ar rc libtest.a *.o` + `ranlib`）由 `-l` 引用。
- 返回值类型决定返回通道：整型/指针走 `%eax`（square、cpuidfunc）；C 的 float/double 返回必须留在 FPU 栈顶 st(0)（areafunc），不能装进 %eax。
- 汇编函数遵循 cdecl：参数 `8(%ebp)` 起、调用者清栈、被调用者保存 `%ebx`/`%ebp`/`%esp` 系寄存器。
- 返回字符串的函数返回的是指针——字符串本体必须放在生命周期覆盖调用方的地方（.bss 的 `.comm` 静态缓冲，cpuidfunc.s），不能放帧内局部量。
- FPU 函数要注意栈平衡：每调一次多压一个数（st(0) 返回的代价），长期循环调用需要意识到堆栈深度。
- 本章把第 11 章 functest2.s 的悬念（外部 area）正式落地成"库函数"概念。

## 一、整型返回的库函数：square.s + inttest.c

```
square:
	pushl %ebp
	movl %esp, %ebp
	movl 8(%ebp), %eax
	imull %eax, %eax
```
（square.s:4-8）

`int i = 2; int j = square(i);`（inttest.c:6-7）——C 侧声明（书中形式 `int square(int);`）后直接调用；汇编侧算完把结果留在 `%eax`，连局部临时量都不需要。`movl %ebp, %esp; popl %ebp; ret`（square.s:9-11）是标准尾声。这是"最小可入库函数"模板：`.type square, @function` + `.globl square`（square.s:2-3）。

## 二、浮点返回：areafunc.s + floattest.c

```
areafunc:
	pushl %ebp
	movl %esp, %ebp

	fldpi
	filds 8(%ebp)
	fmul %st(0), %st(0)
	fmul %st(1), %st(0)
```
（areafunc.s:5-12）

- C 侧 `float areafunc(int);`（floattest.c:4）声明返回 float；调用后 `result = areafunc(radius);`（floattest.c:11）编译器插入的是 `fstps` 从 st(0) 取走结果。
- 汇编侧算 π·r²：`fldpi` 压 π，`filds 8(%ebp)` 压 r（16 位整数形式），`fmul %st(0), %st(0)` 得 r²，`fmul %st(1), %st(0)` 得 r²·π——结束时栈顶是结果，次栈顶还留着 π。**这就是 st(0) 返回协议的代价**：ret 时不清 π，函数每调一次 FPU 栈深 +1。书中 floattest.c 只调两次无碍，循环里乱调用就会 `fp_stack_full`/精度事故。
- floattest.c 两次调用演示同一协议：一次结果存变量再打印、一次直接嵌进 printf 实参（floattest.c:12-13），生成的 C 代码都是"call 后立刻从 st(0) 取"。
- 对照 area.s：同样算 π·r²，但 area.s 用 `fstps -4(%ebp); movl -4(%ebp), %eax`（area.s:13-14）把浮点位模式当 32 位整数从 %eax 带走——它服务的是 functest1/functest2 那种汇编调用者（拿 %eax 直接存 result，第 11 章），不适合给 C 当 float 函数用。两者并置正是"返回通道"教科书对照。

## 三、字符串（指针）返回：cpuidfunc.s + stringtest.c

```
.section .bss
	.comm output, 13
```
（cpuidfunc.s:2-3）

```
	movl $0, %eax
	cpuid
	movl $output, %edi
	movl %ebx, (%edi)
	movl %edx, 4(%edi)
	movl %ecx, 8(%edi)
	movl $output, %eax
```
（cpuidfunc.s:11-17）

- cpuid leaf 0 的 12 字节厂商串按 ebx→edx→ecx 顺序写入 13 字节 `.comm` 缓冲（.bss 清零，第 13 字节天然是 NUL——正好给 C 当字符串）。
- 返回 `movl $output, %eax`：C 侧 `char *cpuidfunc(void);`、`sp = cpuidfunc();`（stringtest.c:4、10）拿到的就是指针。
- 函数里 `pushl %ebx`/`popl %ebx`（cpuidfunc.s:10、18）：cpuid 破坏 `%ebx`，而它在 C 约定里是 callee-saved——这是"入库函数必须替 C 保管寄存器"的标准展示。
- 若把 output 放栈帧局部量，ret 之后指针指向随时会被覆写的栈，stringtest.c 的 printf 就是悬空指针（踩坑见下）。

## 四、建库与链库流程（书中做法）

本仓库函数文件都是"一函数一文件 + .globl"的库候选。典型流程：

```
as area.s -o area.o
as square.s -o square.o
ar rc mylib.a area.o square.o
ranlib mylib.a
gcc inttest.c -L. -lmylib -o inttest
```

（等价偷懒法：`gcc inttest.c square.o -o inttest` 直接列目标文件，不归档也行；`floattest.c areafunc.o`、`stringtest.c cpuidfunc.o` 同理。）

## 五、inttest.s：入库前的数据类型自检

`inttest.s` 与上面的 inttest.c 不是配套（一个是独立 FPU/数据演示的姊妹篇，一个是库调用演示），归本章是因为它检查"有符号数与定宽移动"：

```
	movl $-345, %ecx
	movw $0xffb1, %dx
	movl data, %ebx
```
（inttest.s:9-11，`data: .int -45` 见 inttest.s:5）

`movl $-345, %ecx` 符号扩展入 32 位寄存器；`movw $0xffb1, %dx` 只取 16 位放进 `%dx`；`movl data, %ebx` 读负常数。写完立刻 `movl $1, %eax; int $0x80` 退出，数值看不到但可用调试器看寄存器。库函数用有符号数比较/移动前的这类自检，正是本章"先保证零件再组装"的思路。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| area.s | 圆面积库函数，%eax 装浮点位模式返回（给汇编调用者） | `fstps -4(%ebp)` + `movl -4(%ebp), %eax`；`.globl area` |
| areafunc.s | 圆面积库函数，st(0) 浮点返回（给 C 用） | `fmul %st(1), %st(0)`；不存不取，结果留在 FPU 栈 |
| floattest.c | C 调用 st(0) 返回型函数 | `float areafunc(int);`、`result = areafunc(radius);` |
| square.s | 最简整型返回库函数 | `imull %eax, %eax`，%eax 返回 |
| inttest.c | C 调用 square | `int j = square(i);`（inttest.c:7） |
| inttest.s | 有符号整数与 movw/movl 定宽移动自检 | `movl $-345, %ecx`、`movw $0xffb1, %dx` |
| stringtest.c | C 接收汇编返回的 char* | `sp = cpuidfunc();`（stringtest.c:10） |
| cpuidfunc.s | 返回指向 .bss 静态缓冲的指针 | `.comm output, 13`；`movl $output, %eax`；保 %ebx |

## 逐文件详解

- **square.s + inttest.c**：链接 `gcc inttest.c square.o`。C 编译器为 `square(i)` 生成 push 参数 + call + `addl $4, %esp`，与第 11 章手写的调用方序列完全一致——读一遍 `gcc -S inttest.c` 的产物即可印证。
- **areafunc.s + floattest.c**：两次调用（存变量 / 直嵌 printf）都依赖同一约定；若你误把 areafunc 改成 area.s 的 %eax 返回，C 侧打印会变成 0 或乱数，因为编译器取的是 st(0) 而不是 eax。
- **cpuidfunc.s + stringtest.c**：`.comm output, 13`（cpuidfunc.s:3）是"已声明未初始化公共对象"的库友好写法，同文件内多次调用共享同一缓冲（线程不安全，单进程 demo 无碍）。运行输出形如 `The CPUID is: 'GenuineIntel'`。
- **area.s + functest1/functest2**：area.s 的调用者是第 11 章的汇编 main；三个文件构成"内联函数→外部函数→库函数"的演进链。
- **inttest.s**：独立运行（`gcc inttest.s` 或 as+ld 均可），`.code32`（inttest.s:2）显式声明 32 位模式，避免汇编器按 64 位默认值解析 movw 之类指令——这个 `.code32` 在 mmxtest/ssetest 等第 17 章文件里也能见到。

## 实践与踩坑

1. **忘记 `.globl`**：链接报 `undefined reference to 'square'`——符号存在但非全局，最常见的入库失败原因。
2. **浮点返回写成 %eax**：area.s 那种写法给 C 用时，`printf("%f")` 打出 0.000000——C 只认 st(0)。本章最核心的一条。
3. **返回栈局部缓冲指针**：把 `.comm output, 13` 挪进 `subl $13, %esp` 的帧内，stringtest.c 立刻 UB；指针返回值的生命周期必须 ≥ 调用方使用期。
4. **不保存 %ebx**：cpuidfunc.s 若删掉 10/18 行，stringtest.c 链接 glibc 后 printf 可能直接段错误（%ebx 在 PIC 代码里常作 GOT 基址）。
5. **FPU 栈泄漏**：areafunc.s 每次调用多留一个 π 在栈上；在循环里调用千万次要用 `fstp` 清或改用 `fmulp` 弹出式写法（对照 area.s 的 `fmulp %st(0), %st(1)`，area.s:12）。
6. **`filds` 只读 16 位**：库函数入参半径 >32767 时结果错误（同第 11 章，第 14 章复用该指令时再提醒一次）。

## 复习清单

- [ ] 说清整型/指针返回（%eax）与浮点返回（st(0)）两条通道及对应 C 原型写法。
- [ ] 会用手写 ar/ranlib 建静态库并用 -l 链接，或直接用 .o 列表链接。
- [ ] 解释 cpuidfunc.s 为什么用 .bss 缓冲、为什么 push/pop %ebx。
- [ ] 对比 area.s 与 areafunc.s：同一公式、两种返回协议、两种调用者。
- [ ] 知道 areafunc 的 FPU 栈不平衡问题及 fmulp 修法。
- [ ] 记住 `.code32` 的作用与适用文件。
