> 笔记对应《Professional Assembly Language》(Richard Blum) 第 9 章，代码为本仓库实际敲过的样例。

# 第 9 章 高级数学功能：x87 浮点指令集

## 本章要点

- x87 FPU（Floating-Point Unit，80387 起内置）不用通用寄存器，而用 8 层寄存器栈（Register Stack）st(0)~st(7)：st(0) 恒为栈顶，压栈/出栈改变编号映射，不改变物理槽位。
- 三个 16 位管理字：状态字（Status Word，含 C0~C3 比较标志与异常位）、控制字（Control Word，精度/舍入）、标签字（Tag Word，每个栈槽的数据类型）。`finit` 把三者复位到初始状态。
- 数据搬运：`flds`（单精度 .float）、`fldl`（双精度 .double）、`filds`（整型装入）、`fsts`/`fstps`（存储，p 后缀 = pop 出栈）、`fstl`。FPU 内部一律按 80 位扩展双精度（Extended Precision）计算。
- 预置常量指令一条顶十行：fld1、fldl2t(log2 10)、fldl2e(log2 e)、fldpi、fldlg2(log10 2)、fldln2、fldz。
- 乘除的两种形态要分清：`fmul %st(1), %st(0)` 只改 st(0) 不出栈；`fmulp`/`fdivrp` 把结果写回低位寄存器并弹栈（栈深 -1）。
- 浮点函数返回值 ABI：GCC 约定 float/double 留在 st(0) 返回（areafunc.s、tempconv.s）；若非要放进整数寄存器，需经内存中转（area.s）。

## x87 架构与栈模型

- 每次运算弹出操作数会改变 st 编号：压 A、压 B 后 st(0)=B、st(1)=A。
- 栈满/栈空分别触发 Stack Fault（C1 标志指示上溢/下溢方向）；用 `finit` 或 `fstinit` 可复位。
- 与整数世界的桥梁是 `fild`（装整数）与 `fist/fstp`（存整数，四舍五入受控制字影响）。

## 装入 / 存储 / 常量指令

`fpuvals.s:6-12` 摘录：

```
	fld1
	fldl2t
	fldl2e
	fldpi
	fldlg2
	fldln2
	fldz
```

压入值依次为 1.0、3.32192809488736235（log2 10）、1.44269504088896341（log2 e）、3.14159265358979324、0.30102999566398120（log10 2）、0.69314718055994531（ln 2）、0.0。

## 算术指令与 FPREM1

- 基本运算族：fadd/fsub/fsubr/fmul/fdiv/fdivr，后缀 p 表示"写回更低位并弹栈"，r 表示交换操作数方向（AT&T 与 Intel 的顺序互为镜像，`fsubr %st,%st(1)` 这类写法要特别小心谁减谁）。
- `fprem1`（IEEE Partial Remainder，Pentium 引入的精确部分余数）：求 st(0) MOD st(1)，商按最近整数取。一次调用不保证减到 |余数|<|除数|/2，若状态字 C2（位 10）=1 表示"未完全约简"，须循环重跑——这就是 premtest.s 的循环结构。
- 读状态字惯用法：`fstsw %ax` 后，%ah 的 bit2（掩码 $4）即 C2，`testb $4, %ah` + `jnz` 续算。

## 浮点返回值与 ABI（对照 gcc -S）

- cdecl 下 `float`/`double` 返回值放在 st(0)，调用方负责收走（`fstps`/`fstpl`）；整数返回值走 %eax（square.s）。
- varargs 函数（printf）的可变浮点参数在 32 位 Linux 上必须以 **double** 压栈：gcc 生成的代码用 `flds` + `fstpl` 现场把 float 提升（widen）为 double。
- tempconv2.s 展示优化版 gcc 直接内联运算，用 `fsubs .LC0`（float 32.0）+ `fdivl .LC1`（double 1.8）一条指令直读内存操作数。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| fpuvals.s | 预置常量压栈 | `fld1`~`fldz` 七连压 |
| premtest.s | FPREM1 取余 + C2 循环检测 | `fprem1`/`fstsw %ax`/`testb $4, %ah` |
| area.s | 浮点结果经内存中转回 %eax | `fstps -4(%ebp)` + `movl -4(%ebp), %eax` |
| areafunc.s | 标准 x87 栈返回值 | `fmulp %st(0), %st(1)` 后留在 st(0) |
| square.s | 整数函数返回（对照组） | `imull %eax, %eax` |
| floattest.s | .float/.double 声明与 flds/fldl/fstl | `fldl value2`/`fstl data`（第 8 章数据类型小节亦有交叉） |
| tempconv.c | C 源：摄氏/华氏转换 | `result = (deg - 32.) / 1.8` |
| tempconv.s | gcc -S（未优化）：float 返回值与 varargs 提升 | `fildl 8(%ebp)`/`fstps`/`fstpl (%esp)` |
| tempconv2.s | gcc -S（优化）：内联 + 内存操作数直算 | `fsubs .LC0`/`fdivl .LC1` |

## 逐文件详解

### fpuvals.s — 常量栈

七条无操作数指令连续压栈（`fpuvals.s:6-12`），执行后 st(0)=0.0(fldz)、st(1)=ln2、st(2)=log10 2、st(3)=pi、st(4)=log2 e、st(5)=log2 10、st(6)=1.0。演示"越新的值编号越小"。程序直接 exit(0)，未存回内存——只能 gdb `info float` 查看 ST 寄存器组。

### premtest.s — FPREM1 循环

`premtest.s:13-22`：

```
	finit
	flds value2
	flds value1
loop:
	fprem1
	fstsw %ax
	testb $4, %ah
	jnz loop
	fsts result
```

先压 3.97 再压 20.65 → st(0)=20.65、st(1)=3.97。FPREM1 语义：st(0) ← 20.65 − round(20.65/3.97)×3.97 = 20.65 − 5×3.97 = **0.80**（float 下约 0.8000007，尾数误差需 gdb 验证）。若单次实现约简不足则 C2=1，`jnz loop` 重跑直到 |余数| < 除数/2 = 1.985。结果 `fsts result`（存而不出栈，与 `fstps` 区别）。注意 `fprem1` 不弹栈：结束时 st(0)=余数、st(1)、st(2) 原值仍在。

### area.s — 用整数寄存器"违规"返回 float

`area.s:9-14`：

```
	fldpi
	filds 8(%ebp)
	fmul %st(0), %st(0)
	fmulp %st(0), %st(1)
	fstps -4(%ebp)
	movl -4(%ebp), %eax
```

`subl $4, %esp` 开了一个局部槽。栈 [pi, r]；`fmul %st(0), %st(0)` → st(0)=r×r=r²；`fmulp %st(0), %st(1)` → st(1)=pi×r² 并弹栈 → st(0)=pi r²。`fstps -4(%ebp)` 把单精度位型写进局部变量，再 `movl` 进 %eax——返回的是 float 的**位模式**（bit pattern），不是数值，调用方须按 float 解释。这是书中"避开标准约定"的演示。

### areafunc.s — 正统 x87 栈返回

`areafunc.s:9-12`：同样 [pi, r] 起手，`fmul %st(0), %st(0)` → [pi, r²]；`fmul %st(1), %st(0)` → st(0)=r²×pi（不出栈）。`ret` 时结果躺在 st(0)，调用方 `fstps`/`fstpl` 接收——与 GCC 对 float 函数返回值的约定一致。

### square.s — 整数返回对照组

`square.s:5-11`：`movl 8(%ebp), %eax` 取参数，`imull %eax, %eax` 求平方，%eax 返回。参数 n=10 → 100；n=-35 → 1225（0x4C9）。说明整数走 %eax、浮点走 st(0) 的分野。

### floattest.s — 浮点数据声明与搬运

`floattest.s:13-15`：`flds value1`（12.34 单精度）压 st(0)，`fldl value2`（2353.631 双精度）压 st(0)（原 12.34 变 st(1)），`fstl data` 把 st(0) 的 8 字节双精度存入 .bss 的 8 字节槽（`.lcomm data, 8`）。本例只有装/存无运算，属第 8 章"浮点数存储"与第 9 章"数据传送"的衔接样例，交叉引用 docs/ch08-integer-instructions.md。

### tempconv.c / tempconv.s — gcc -S 未优化对照

`tempconv.c:4-9` 的 `convert(int)` 编译为 `tempconv.s:14-20`：

```
	fildl	8(%ebp)
	fldl	.LC0
	fsubrp	%st, %st(1)
	fldl	.LC1
	fdivrp	%st, %st(1)
	fstps	-4(%ebp)
	flds	-4(%ebp)
```

.LC0=double 32.0（.long 0 / 1077936128，即 0x40400000_00000000），.LC1=double 1.8（0x3FCC_CCCCCCCCCD）。整数参数经 `fildl` 升格；压栈顺序是先 deg 后 32.0，故 st(0)=32.0、st(1)=deg，AT&T 的 `fsubrp %st, %st(1)` 完成弹出式相减得 deg−32.0（p 形式在 AT&T 下"操作数反转 + r 后缀"两次翻转相互抵消，净效果 st(1)←st(1)−st(0)；方向极易搞混，建议 gdb 单步核对）；随后 `fldl .LC1`+`fdivrp` 同理除以 1.8。结果 `fstps -4(%ebp)` 存局部再 `flds` 弹回 st(0) 返回——gcc 未优化时的"往返中转"。main 中调用后 `fstps -28(%ebp)` 收返回值（`tempconv.s:65-67`），打印前 `flds -12(%ebp)` + `leal -8(%esp), %esp` + `fstpl (%esp)`（`tempconv.s:70-72`）把 float 提升为 double 压栈，满足 `%5.2f` 的 varargs 要求。deg=100 → 100−32=68，68/1.8=**37.777…**，显示 37.78；deg=32 → 0.00。

### tempconv2.s — 优化版对照

`tempconv2.s:14-18`：

```
	fildl	16(%esp)
	fsubs	.LC0
	fdivl	.LC1
	fstps	4(%esp)
	flds	4(%esp)
```

.LC0 变为单精度 32.0（0x42000000，`tempconv2.s:104-105`），算术直接以内存操作数为源（fsubs/fdivl 单条指令，无 fld 装填）；main 里 convert 被整体内联（`tempconv2.s:69-73`），并改用 `__printf_chk`。返回值仍以 `flds` 收尾留在 st(0)、调用侧 `fstpl` 提升为 double（`tempconv2.s:73-74`），ABI 不变。

## 实践与踩坑

- **finit 别忘**：premtest.s 开头 `finit` 清栈清标志；连续运行/异常后的残留栈内容会让 `fprem1` 或后续 fld 报栈溢出（本书时代还需配合 WAIT，现代 CPU 不必）。
- **C2 检测的位运算**：`fstsw %ax` 后 C2 在状态字第 10 位，落到 %ah 的第 2 位，掩码必须写 `$4`（写 `$0x04` 于 %ah），mask 成 $1/$2 会检错位（C0/C1），循环要么死循环要么提前退出。
- **fmulp 与 fmul 栈深不同**：areafunc.s 用 `fmul %st(1), %st(0)` 栈深不变（2 层），area.s 用 `fmulp` 弹成 1 层；写调用方收值代码时若数错层，`fstps` 存的是别的数。
- **area.s 的"位型返回"是陷阱**：%eax 里是 pi r² 的 IEEE754 单精度编码，直接 `%d` 打印是天文数字；只应在明确知道接收端按 float 解释时用。
- **printf 可变参数必须 double**：手写汇编调用 printf 传 `%f` 时，照抄 tempconv.s 的 `flds`+`fstpl` 序列把 float 扩成 double 再压栈，直接压 4 字节 float 会输出错值。
- **浮点比较不体现在 EFLAGS**：fucom/fcom 只设 FPU 状态字 C0/C2/C3，需 `fstsw` + sahf 才能用 je/jb，或用 `fcomip`（P6 后）直接写 EFLAGS——本仓库样例未涉及，调试时勿拿 `cmp` 的思维看标志。
- **32 位环境**：tempconv 系列是 Ubuntu 5.4 gcc -S 产物（带 .cfi 指令），64 位机上须 `-m32` 汇编链接；x87 在 SysV AMD64 下 float 返回值改走 %xmm0，结论不可直接迁移。

## 复习清单

- [ ] 能画出 premtest.s 执行各步后 ST 栈的内容（谁在 st(0)/st(1)）
- [ ] 能说出七个 fpuvals 常量指令的十进制近似值
- [ ] 能解释 fprem1 为何要配 C2 循环、`testb $4, %ah` 每个部件的含义
- [ ] 能区分 fmul / fmulp / fmul r 三种形态对栈深和结果的影响
- [ ] 能说明 areafunc.s 与 area.s 两种返回方式的兼容性差异
- [ ] 能从 tempconv.s 读出 .LC0/.LC1 的 IEEE754 编码（32.0 与 1.8 的 double 位型）
- [ ] 能解释 gcc 为 printf 传参做 float→double 提升的三条指令序列
- [ ] 知道 floattest.s 属于第 8 章数据类型与本章装存指令的交叉样例
