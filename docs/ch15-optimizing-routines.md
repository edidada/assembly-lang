# 第15章 优化例程(Optimizing Your Code)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 15 章，代码为本仓库实际敲过的样例。

## 本章要点

- 本章的方法论是"同一份 C 源文件，gcc -O0 与 -O1/-O2 各生成一份 .s，逐行 diff 看优化器做了什么"：condtest/sums/calctest/vartest 各有这样一对产物（xxx.s vs xxx2.s）。
- 帧指针省略（frame pointer omission）：叶函数在 -O2 下不再 pushl %ebp/movl %esp,%ebp，参数直接按 4(%esp)、8(%esp) 读。
- 条件移动（conditional move, cmov）消灭分支：condtest2.s 的 cmovl 是全仓库唯一的 cmov 实例。
- 循环改写：for→while 形态（测试后置）、`jne` 单指令回边、`testl` 预判空循环、`.p2align` 对齐热循环入口。
- 强度削减（strength reduction）：`i * 5` 被编成 `sall $2` + `addl`（移位加，不用 imul）。
- 预计算/常量折叠（pre-calculation / constant folding）：-O2 能静态算出的值直接以立即数出现（250、55、30）；公共子表达式消除（CSE, common subexpression elimination）让 a*b 只算一次。
- C 宏（macro）是"优化"的反面教材：mactest1.c 展示无类型检查的宏陷阱。

## 一、if-then 的原始形态：ifthen.c → ifthen.s

```
	movl	-8(%rbp), %eax
	cmpl	-4(%rbp), %eax
	jle	.L2
```
（ifthen.s:19-21）

`if(a > b)`（ifthen.c:9-15）被翻成"比较 + 反向跳转"：编译器生成条件的跳转让常见分支直落。两个分支里的重复 printf 被保留为两份调用（ifthen.s:22-33），字符串 `.LC0` 只存一份。注意：ifthen.s 是 64 位产物——`pushq %rbp`、`movl $.LC0, %edi`（ifthen.s:11-15、24-25），说明生成它时忘了 `-m32`，属于"敲码记录"而非 32 位约定样本；结构仍可读（见踩坑 1）。

## 二、condtest 组：cmov 与帧消除

C 源码是一个三分支取大/取零函数（condtest.c:4-15）。

`-O0` 的 condtest.s：

```
	movl	8(%ebp), %eax
	cmpl	12(%ebp), %eax
	jle	.L2
	movl	8(%ebp), %eax
	movl	%eax, -4(%ebp)
	jmp	.L3
```
（condtest.s:14-19）

完整 ebp 帧、result 存内存槽 `-4(%ebp)`、每个比较各取一次参数——教科书级的"未优化"。

`-O2` 的 condtest2.s：

```
	movl	4(%esp), %eax
	movl	8(%esp), %edx
	cmpl	%edx, %eax
	jg	.L2
	movl	$0, %eax
	cmovl	%edx, %eax
.L2:
	rep ret
```
（condtest2.s:12-19）

三点差异：1) 无帧——参数改从 4(%esp)/8(%esp) 读，`leave` 消失；2) 分支→cmov——`cmovl %edx, %eax` 把 else-if 路径合并，只剩一个比较跳转（test1>test2 早退）；3) main 里 `conditiontest(data1, data2)` 被内联+常量折叠（10、30 静态可算），`pushl $30` 直接进 `__printf_chk`（condtest2.s:50-53），调用彻底消失，但函数体仍保留（非 static，可能被别处引用）。`rep ret`（condtest2.s:19）不是循环，是 AMD 乱序取指问题的规避写法，等价 `ret`。

## 三、for 循环的规范化：for.c → for.s

```
	movl	-8(%rbp), %edx
	movl	%edx, %eax
	sall	$2, %eax
	addl	%edx, %eax
	movl	%eax, -4(%rbp)
```
（for.s:21-25，同为 64 位产物）

- `j = i * 5` 没乘：`sall $2`（×4）再 `addl`（+i）——强度削减的标准形态（第 9 章"用移位代替乘法"在编译器里的回声）。
- 循环条件 `i < 10` 被反写为循环底 `cmpl $9, -8(%rbp); jle .L3`（for.s:33-34）：for 先测后跳被改写成 while 形态，省一次入口判断。`jmp .L2`（for.s:19）先跳到测试处。

## 四、sums 组：寄存器分配与常量折叠

`-O0` 的 sums.s：sum/j 全在内存（`addl %eax, -4(%ebp)`、`addl $1, -8(%ebp)`，sums.s:18-20），每轮比较重新 `movl -8(%ebp), %eax` 再 `cmpl 8(%ebp), %eax`（sums.s:22-23），且带完整帧。

`-O2` 的 sums2.s：

```
	movl	4(%esp), %ecx
	testl	%ecx, %ecx
	jle	.L4
	addl	$1, %ecx
	xorl	%eax, %eax
	movl	$1, %edx
.L3:
	addl	%edx, %eax
	addl	$1, %edx
	cmpl	%ecx, %edx
	jne	.L3
```
（sums2.s:12-24）

- 循环变量 j→%edx、上界→%ecx、sum→%eax，零内存槽；退出判断用 `jne`（比较即标志）替代 `jle`+jmp 双跳；清零用 `xorl %eax, %eax`（比 movl $0 短）。`testl %ecx, %ecx; jle .L4` 是为 `i <= 0` 设的空循环特判（trip-count guard），`.L4: xorl %eax, %eax` 直接返回 0（sums2.s:27-28）。
- main 中 `sums(10)` 被算成 55：`pushl $55`（sums2.s:59），但 sums 本体仍在——同样的"导出函数保留、调用点折叠"策略。

## 五、calctest 组：预计算（pre-calculation）

calctest.c 里 `a = a + 15; b = a + 200; c = a + b;`（calctest.c:9-11，a 初值 10）。

`-O0` 的 calctest.s 老实执行：`addl $15, -20(%ebp)`，再借 `%eax/%edx` 算 b、c 存回槽位（calctest.s:22-29）。

`-O2` 的 calctest2.s：全部消失，只剩

```
	pushl	$250
	pushl	$.LC0
	pushl	$1
	call	__printf_chk
```
（calctest2.s:25-28）

10+15=25、b=225、c=25+225=250，编译期全算完。"先算再存"与"运行时再算"的差就是这 4 行——这也是本章标题"优化例程"在写汇编时的启示：能在汇编期 `.equ`/常量算的，别留到运行时。

## 六、CSE：csetest.c

```
	int c = a * b;
	int d = (a * b) / 5;
	int e = 500 / (a * b);
```
（csetest.c:6-8）

人眼看 `a*b` 出现三次；优化器做 CSE 后只留一次 `imull`，结果供除法/取模复用（本仓库没留 csetest.s，书上的验证思路相同）。funct1 被调用两次（csetest.c:15-16），`500/(a*b)` 若实参使 a*b 为 0 就是除零陷阱——CSE 不改变这一点。本文件无配套 .s，属于"读 C 猜汇编"练习。

## 七、宏的坑：mactest1.c

```
#define SUM(a, b, result) ((result) = (a) + (b))
```
（mactest1.c:3）

- `SUM(fdata1, fdata2, fresult)` 与 `SUM(data1, fdata2, result)`（mactest1.c:14、16）：最后一个把 int 与 float 相加再赋给 int result——宏按文本展开，`5 + 10.0` 在 C 里由usual arithmetic conversion 升为 float 再截断回 int，语义与"整数加法"完全不同，输出与预期可能一致也可能诡异，宏不会拦你。
- 与第 13 章 mactest2.c 的 GREATER 对比：内联汇编宏至少有约束把操作数装进寄存器、类型由 C 校验到变量本身。
- 宏展开无函数调用开销（这正是当年"库函数 vs 宏"的优化点），但重复展开膨胀代码——现代编译器用内联（inline function）取代。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| ifthen.c | if-else 双 printf 样本 | `if(a > b)`（ifthen.c:9） |
| ifthen.s | if-then 的反向跳转翻译（64 位产物） | `cmpl`+`jle .L2`；两分支各一次 call printf |
| condtest.c | 三分支取大函数 | `if(test1 > test2)...else if...else`（5-14 行） |
| condtest.s | -O0：完整帧+双比较分支 | `movl %eax, -4(%ebp)` 型结果落栈 |
| condtest2.s | -O2：cmov+无帧+main 内联折叠 | `cmovl %edx, %eax`；`pushl $30` |
| for.c | for 循环乘 5 打印 | `j = i * 5;`（for.c:11） |
| for.s | 强度削减与 for→while 改写 | `sall $2, %eax` + `addl %edx, %eax`；`cmpl $9`/`jle` |
| sums.c | 累加循环 | `for(j=1; j<=i; j++) sum = sum + j;`（8-9 行） |
| sums.s | -O0：循环全走内存 | `addl %eax, -4(%ebp)` |
| sums2.s | -O2：寄存器循环+空转特判+折叠 55 | `testl %ecx, %ecx`；`jne .L3`；`pushl $55` |
| calctest.c | 可静态求值的三连赋值 | `c = a + b;`（calctest.c:11） |
| calctest.s | -O0：逐步存栈 | `addl $15, -20(%ebp)` |
| calctest2.s | -O2：预计算成 pushl $250 | `pushl $250`（calctest2.s:25） |
| csetest.c | CSE 样本（a*b 出现三次） | csetest.c:6-8 |
| mactest1.c | 宏的类型陷阱对照组 | `#define SUM(...)`（mactest1.c:3） |

## 逐文件详解

- **condtest.s vs condtest2.s**：函数尺寸对比 .LFB0→.LFE0（condtest.s:6-35，约 30 行指令）vs（condtest2.s:9-20，7 行）。参数寻址 8(%ebp)→4(%esp) 即帧省略的直接证据；main 里 condtest.s 老老实实 `pushl -12(%ebp); pushl -16(%ebp); call conditiontest; addl $8, %esp`（condtest.s:59-62，调用者清栈），condtest2.s 里这段整体消失。
- **sums.s vs sums2.s**：-O0 的 `jmp .L2` 入口跳（sums.s:16）在 -O2 变成"先 test 特判再进循环"；循环体内 -O0 每轮 2 次访存比较，-O2 零访存。`sums2.s:18-19` 的两行 `.p2align` 是循环入口对齐填充，-O0 不会出现。
- **calctest.s vs calctest2.s**：同 main 的函数体从 calctest.s:8-45 缩到 calctest2.s:12-40；`.rodata` 合并进 `.rodata.str1.1`（calctest2.s:2）也是 -O2 的字符串池化痕迹。
- **ifthen.s / for.s**：两者与 vartest 组不同，是默认 64 位的产物；拿来读控制流可以，拿来学 32 位约定会跑偏——这正是本章要留心的敲码事故。csetest.c / mactest1.c 无 .s 对照，读法是自己敲 `gcc -S -O1` 验证 CSE/宏展开（见实践 5）。

## 实践与踩坑

1. **忘了 -m32**：ifthen.s、for.s 是 x86-64 代码（pushq %rbp、%edi/%esi 传参、System V ABI），在本仓库"32 位 int 0x80"主题里属于生成姿势错误；重敲：`gcc -m32 -S -O0/-O2 ...`。
2. **被 cmov 迷惑**：cmov 只省分支不省计算——condtest2.s 仍把 0 装进 %eax 再条件覆盖，理解成"if-then-else 融合"即可；分支预测差的平台才优先出 cmov。
3. **"函数没了"≠"代码没了"**：折叠只发生在已知常量的调用点，导出函数体照旧生成；static 化后才会整个删掉。
4. **`rep ret` 不是笔误**：别"顺手修正"成 ret，它是刻意的。
5. **csetest/mactest1 没留 .s**：想复习 CSE 就 `gcc -S -O1 csetest.c`，你会看到 funct1 里只有一次 `imull`；mactest1.c 则建议 `-E` 看纯宏展开文本，四行 SUM 各自展开成长表达式。
6. **别学 -O0 写汇编**：-O0 产物充满 ebp 寻址与冗余 load/store，只用于观察翻译结构；手敲优化版参考 sums2.s/condtest2.s 的寄存器分配思路。

## 复习清单

- [ ] 解释帧省略后参数为什么出现在 4(%esp)、8(%esp)。
- [ ] 能从 condtest.c 徒手写出 cmov 版 32 位汇编（cmp + movl $0 + cmovl）。
- [ ] 说出 for→while 改写与 `jne` 回边各优化了什么；解释 sall+addl 代替 imul、xorl 清零的动机。
- [ ] 记住三组折叠结果：calctest→250、sums(10)→55、condtest(10,30)→30，并能手算复核。
- [ ] 说出 CSE 与"预计算"分别消除的是什么（重复子表达式 / 运行期可静态求值的计算）；知道 csetest 用 `-S -O1`、mactest1 用 `-E` 可自行验证。
