# 第13章 使用内联汇编(Using Inline Assembly)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 13 章，代码为本仓库实际敲过的样例。

## 本章要点

- GCC 内联汇编（inline assembly）扩展 asm() 的四段结构：`asm("模板" : 输出操作数 : 输入操作数 : 破坏描述表)`，模板里 `%0-%9` 按"先输出后输入"编号。
- 约束符（constraint）：`"a"`=%eax、`"d"`=%edx、`"c"`=%ecx、`"r"`=任意通用寄存器；前缀 `=` 表示只写输出。
- 模板里访问 x86 寄存器名要写 `%%eax`（文档规定的转义写法）；不跟数字时裸 `%eax` 实际也能通过 gcc，本仓库两种写法都出现了（globaltest.c 用裸 `%eax`，regtest1.c 用 `%%eax`）。
- 直接引用 C 全局变量名时汇编器可见的就是链接符号本身，但要自己动手 `pusha`/`popa` 保护寄存器，因为没告诉编译器你用了哪些（globaltest.c）。
- 内联汇编可以包进 GNU 语句表达式（statement expression）`({...})` 做成宏，配合数字标号 `0:`/`1:` + `0f`/`1f` 前向跳转，避免多次展开时标号重名（mactest2.c）。
- `gcc -S` 输出的 .s 能看到 asm() 原样落在 `#APP` 与 `#NO_APP` 之间——读反汇编是验证内联代码的手段（globaltest.s:35-44）。

## 一、约束与操作数：regtest1.c

```
	asm("imull %%edx, %%ecx\n\t"
		"movl %%ecx, %%eax"
		:"=a"(result)
		:"d"(data1), "c"(data2));
```
（regtest1.c:9-12）

- 输入 `"d"(data1)` 让编译器把 data1 装进 `%edx`，`"c"(data2)` 装进 `%ecx`；输出 `"=a"(result)` 告诉编译器"结束后 %eax 里就是 result"。
- 这个例子里模板没用 `%0/%1/%2` 而是硬写寄存器名——因为约束已经把操作数钉死在指定寄存器（register constraint）上，等价于用编号写法。书里用它讲"约束即寄存器分配"。
- 严格说模板还破坏了 `%ecx`（imull 的目的操作数）却没在输出里声明 `"=c"`，属于"我知道我踩了它"的演示性写法；规范做法见后文踩坑。

## 二、裸 asm() 访问 C 全局变量 + pusha/popa：globaltest.c

```
	asm("pusha\n\t"
		"movl a, %eax\n\t"
		"movl b, %ebx\n\t"
		"imull %ebx, %eax\n\t"
		"movl %eax, result\n\t"
		"popa");
```
（globaltest.c:9-14）

- a、b、result 是 C 全局（globaltest.c:3-5），在汇编模板里直接当链接符号用。
- 没写任何约束/破坏表，所以作者用 `pusha`/`popa` 把全部通用寄存器入栈出栈，简单粗暴但保证不打扰编译器。
- `gcc -S` 验证：globaltest.s 里

```
#APP
# 9 "globaltest.c" 1
	pusha
	movl a, %eax
```
（globaltest.s:35-38；块尾在 globaltest.s:43-44 的 `# 0 "" 2` 与 `#NO_APP`）

`#APP/#NO_APP` 就是"这里是用户内联汇编"的标记；`# 9 "globaltest.c" 1` 是 cpp 行号标记。另外可见 a、b 在 `.data` 带 `.globl`（globaltest.s:2-14），result 用 `.comm result,4,4`（globaltest.s:15）——未初始化全局走 common 符号。

## 三、语句表达式宏：mactest2.c

```
#define GREATER(a, b, result) ({\
				asm("cmp %1, %2\n\t"\
					"jge 0f\n\t"\
					"movl %1, %0\n\t"\
					"jmp 1f\n\t"\
					"0:\n\t"\
					"movl %2, %0\n\t"\
					"1:\n\t"\
					:"=r"(result)\
					:"r"(a), "r"(b));})
```
（mactest2.c:3-12）

- `({...})` 是 GNU 语句表达式：把带声明/语句的块变成一个值（这里是无值副作用），才能做成"语句宏"。
- 输出 `"=r"(result)` 是 `%0`，输入 `"r"(a)`=`%1`、`"r"(b)`=`%2`；比较方向注意 AT&T 语法 `cmp %1, %2` 算的是 b 对 a 的标志。
- 数字标号 `0:`、`1:` 加 `0f`/`1f`（forward 到最近的 0/1 标号）使宏两次展开不冲突——mactest2.c 里 GREATER 恰好调用了两次（mactest2.c:18、21），用普通字母标号就会重复定义。
- 与第 15 章 mactest1.c 的纯 C 宏对比：mactest1 的 `SUM` 无类型检查（float 塞进 int 变量出垃圾），mactest2 把操作数交给约束/寄存器分配，类型仍由 C 管，但指令序列是你写的。

## 四、对照：C 全局/局部变量落到汇编里长什么样（vartest 组）

vartest.c 定义 `int global1 = 10; float global2 = 20.25;` 与 main 内的局部 int/float（vartest.c:4-13）。

`-O0` 的 vartest.s：
- 初始化全局 → `.data` + `.globl` + `.long 10`；`global2` 的 20.25 变成 `.long 1101135872`（vartest.s:13），即 IEEE 754 单精度位模式。
- 局部变量全是 ebp 负偏移：`movl $100, -24(%ebp)`（vartest.s:34）；float 字面量 200.25 存 `.rodata` 的 `.LC0: .long 1128808448`（vartest.s:64-65），用 `flds .LC0; fstps -20(%ebp)` 拷进栈槽（vartest.s:35-36）。
- 浮点加法走 FPU：`flds global2; fadds -20(%ebp); fstps -12(%ebp)`（vartest.s:41-43）。
- printf 的 `%f` 变参：float 先升 double——`flds -12(%ebp)` 后 `leal -8(%esp), %esp; fstpl (%esp)`（vartest.s:44-46）压 8 字节。

`-O2` 的 vartest2.s（同一份 vartest.c，行号全部对 vartest2.s）：
- 局部槽位消失：`addl $100, %eax` 直接对 global1+100，`flds .LC0; fadds global2`（vartest2.s:25-28）常量传播后不再往栈上搬 100/200.25。
- main 被放进 `.text.startup` 热段（vartest2.s:7-8），printf 被换成 `__printf_chk`（vartest2.s:33）。
- 这组文件严格说属于"编译器如何翻译变量声明"，放在第 13 章是因为写内联汇编前必须知道 C 变量在汇编层的真名与真位置——第 15 章的优化对照（sums/condtest/calctest）用的是同一批产物。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| regtest1.c | 寄存器约束做乘法返回 | `"=a"(result)`、`"d"(data1)`、`"c"(data2)`；`imull %%edx, %%ecx` |
| globaltest.c | 无约束裸 asm 访问 C 全局变量 | `pusha`/`popa`；`movl a, %eax` |
| globaltest.s | 上述代码的 gcc -S 产物 | `#APP`…`#NO_APP`（35-44）；`.comm result,4,4` |
| mactest2.c | 语句表达式+数字标号的内联汇编宏 | `({...})`；`0f`/`1f`；`"=r"`/`"r"` 约束 |
| vartest.c | 全局/局部 int、float 样本 | `float global2 = 20.25;`（4-5 行） |
| vartest.s | -O0 下 C 变量的汇编映射 | `movl $100, -24(%ebp)`；`flds/fadds/fstps` |
| vartest2.s | -O2 下同样本的优化形态 | 无栈槽、`.text.startup`、`__printf_chk` |

## 逐文件详解

- **regtest1.c**：main 里两个局部 int 加 result，唯一的计算就压在一条 asm 里。约束让编译器负责把 data1/data2 装进 edx/ecx、把 eax 回收赋给 result——你只写指令，不管分配。
- **globaltest.c + globaltest.s 成对**：C 的乘法 a*b 被写成 `movl a,%eax; imull %ebx,%eax` 之类四条 mov/imul；.s 文件证明编译器在 `#APP` 块前后自己插入了栈调整（globaltest.s:45-49：`movl result, %eax` 再 push 给 printf），完全没有"看见"你用了 eax/ebx——这就是不加约束不加 clobber 的风险展示，作者用 pusha/popa 兜底。
- **mactest2.c**：两次 GREATER(data1,data2,result) 展开成两段独立指令串，数字标号互不干扰；结果分别打印 20 与 30。对照 .out 输出可见约束让两次展开的 `%0/%1/%2` 落在不同寄存器上。
- **vartest.c + vartest.s/vartest2.s**：-O0 版每个变量都有内存住址（可 gdb 观察），-O2 版变量"住寄存器"，行尾的 `.ident "GCC: (Ubuntu 5.4.0-6ubuntu1~16.04.4)"`（vartest.s:66）说明两份是同一台机器不同 -O 级别产出。

## 实践与踩坑

1. **`%` 转义**：官方文档要求寄存器写 `%%eax`；globaltest.c 里裸 `%eax` 恰好因为 `%e` 不是替换序列才没出事——模板里如果出现 `%0`-`%9`、`%g`、`%=` 之类的组合，裸写就会出事，统一 `%%` 才是安全习惯。
2. **裸 asm + 不声明 clobber**：不 pusha 的话，编译器以为所有 caller-saved 寄存器完好，优化级别一高就静默出错。要么用约束，要么老实写 clobber 列表。
3. **多行模板的行分隔**：`\n\t` 不能省，漏了会把两条指令连成一行导致语法错误；本仓库三个 .c 全部规整地写了 `\n\t`。
4. **输出约束缺 `&`**：mactest2.c 的 `"=r"(result)` 理论上可能与输入早写重叠（matching constraint 问题），教科书例子未暴露；写严格代码时考虑 `"=&r"`。
5. **数字标号只在内联汇编里可用**：普通 .s 文件里写 `0:` 合法但容易和别的块冲突；`0f`/`1f` 的前向语义正是为宏展开设计的，别在长文件里到处用。
6. **vartest 的 20.25**：在 .s 里看到巨大的 `.long 1101135872` 不要慌，那是 float 位模式（IEEE 754），与第 8 章浮点数存储一致。

## 复习清单

- [ ] 默写 asm() 四段结构并解释 `%0` 编号规则（先输出后输入）。
- [ ] 说出 "a"/"d"/"c"/"r" 约束对应哪些寄存器，`=` 前缀含义。
- [ ] 解释 pusha/popa 版（globaltest.c）与全约束版（regtest1.c）的利弊。
- [ ] 会用 `({...})` + `0f`/`1f` 写一个可多次展开的汇编宏。
- [ ] 在 gcc -S 产物里认出 #APP/#NO_APP、.comm、.LC 常量池、ebp 栈槽。
- [ ] 知道 float 传给 printf("%f") 时编译器会自动升成 double（fstpl 八字节入栈）。
