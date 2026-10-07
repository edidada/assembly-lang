# 第6章 控制执行流程 (Controlling Program Execution)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 6 章，代码为本仓库实际敲过的样例。

## 本章要点

- 条件跳转 (conditional jump) 不比较数值本身，只读状态标志位 (status flags)：CF(进/借位)、ZF(零)、SF(符号)、OF(溢出)；比较类指令 CMP/DEC/SUB 负责置标志，JCC 负责读标志。
- AT&T 语法 `cmp src, dst` 计算的是 `dst - src` 并按结果置标志；`cmp %eax, %ebx` 是"ebx 减 eax"，操作数顺序搞反，jge/jle 的判断方向就整个颠倒——cmptest.s 正是这个坑的活教材。
- 有符号条件码 (jl/jle/jg/jge) 用 SF≠OF 与 ZF 组合判断；无符号 (jb/jbe/ja/jae) 只用 CF 与 ZF。CMOVcc 家族把"跳转"变成"按需传送"，如 cmovtest.s 的 `cmova`（CF=0 且 ZF=1 时传送，即无符号大于）。
- `loop` 指令隐含地先 `ECX-1` 再判 ECX≠0；ECX=0 进 loop 会转 2^32 圈，因此要像 betterloop.s 那样用 `jcxz` 先做哨兵检查。
- CALL 压入返回地址并 JMP，RET 弹出返回地址；调用方清栈用 `add $8, %esp`（cdecl）。calltest.s 展示了一个非标准的手工"序言/跋文"(prologue/epilogue)。
- 无条件跳转、循环与 xchg (交换指令，属第 5 章数据传送) 组合即可完成冒泡排序——bubble.s 是本章指令的综合演练。

## 无条件跳转、比较与条件跳转

`jmp 标号` 直接改写 EIP。jumptest.s 里 jmp 之后的两条指令永远不会执行（dead code）。cmptest.s 用 `cmp` + `jge`；signtest.s（第 7 章清单中，因其语义是 SF 与有符号数，主笔记见 `docs/ch07-working-with-numbers.md`）用 `dec` 顺带置 SF、`jns` 控制循环——同一套"算标志/读标志"机制的两种写法。CMOVcc（conditional move，Pentium Pro 起）在 cmovtest.s 中替代了"跳转+暂存"的写法，取最大值只用一条 `cmova`。

## 循环指令与哨兵

loop.s：ECX 作计数器，`addl %ecx,%eax` 累加后 `loop` 递减并判零，一段代码同时完成 1..100 求和。
betterloop.s：演示 `jcxz` (jump if ecx zero) 防止 ECX=0 时的 2^32 圈灾难，以及循环体一次都不执行的边界情形。

## CALL、RET 与手工栈帧

calltest.s 混合演示：调用 libc 的 printf/exit（调用方清栈），以及自定义过程 overhere 的 `pushl %esp / movl %esp,%ebp / ... / movl %ebp,%esp / popl %ebp / ret` 骨架。注意这套骨架保存/恢复的是 ESP 的副本而不是标准的 `pushl %ebp`，只在"没人依赖旧 EBP"时碰巧成立（详见逐文件分析）。

## 综合例子：冒泡排序

bubble.s 用 `cmp`+`jge` 做相邻比较，`xchg %eax, 4(%esi)` 与 `movl %eax,(%esi)` 两步完成交换。xchg 本身是第 5 章"数据传送"里的指令（register-memory 形式且带隐式总线锁定语义），这里作为排序原语复用；循环控制（jge/jnz/jz/jmp + 双计数器 ECX/EBX）是本章内容，故按任务分工把 bubble.s 主放在第 6 章。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| jumptest.s | 无条件 jmp 跳过死代码，exit(20) | `jmp overhere` |
| cmptest.s | cmp+jge，AT&T 操作数顺序决定判断方向 | `cmp %eax, %ebx` / `jge greater` |
| loop.s | loop 指令 ECX 递减计数求和 | `addl %ecx,%eax` / `loop loop_1` |
| betterloop.s | jcxz 哨兵 + 零次循环边界 | `jcxz done` / `loop loop_1` |
| calltest.s | call/ret、手工栈骨架、调用方清栈 | `call overhere` / `add $8,%esp` / `ret` |
| cmovtest.s | cmova 无符号条件传送求最大值 | `cmp %ebx,%eax` / `cmova %eax,%ebx` |
| bubble.s | 双重循环冒泡排序 + xchg 交换 | `jge skip` / `xchg %eax,4(%esi)` / `dec %ebx; jnz` |

## 逐文件详解

### jumptest.s

`jumptest.s:6-12`：

```asm
	movl $1, %eax
	jmp overhere
	movl $10, %ebx
	int $0x80
overhere:
	movl $20, %ebx
	int $0x80
```

eax=1 (exit 系统调用号) 在 jmp 前就已备好；第 8-9 行的 `exit(10)` 永远不执行。实际出口 ebx=20，`echo $?` = 20。

### cmptest.s（操作数顺序陷阱）

`cmptest.s:6-15`：

```asm
	movl $15, %eax
	movl $10, %ebx
	cmp %eax, %ebx
	jge greater
	movl $1, %eax
	int $0x80
greater:
	movl $20, %ebx
	movl $1, %eax
	int $0x80
```

AT&T 语义：`cmp %eax,%ebx` 算 ebx−eax = 10−15 = −5。标志：ZF=0，SF=1，OF=0（−5 不溢出），CF=1（无符号视角 10<15 需借位）。`jge` 条件为 SF==OF，这里 1≠0 → 不跳。于是执行第 10-11 行，exit(ebx=10)，`echo $?` = 10——尽管程序名和标号 "greater" 都暗示作者想让 eax(15) > ebx(10) 时跳到 greater 输出 20。若想按直觉"eax 与 ebx 比较，eax 大则跳"，应写 `cmp %ebx, %eax`（算 eax−ebx=5，SF=OF=0，jge 成立，退出码变 20）。结论：本文件按当前写法走的是 fall-through 路径，退出码 10。

### loop.s

`loop.s:8-12`：

```asm
	movl $100, %ecx
	movl $0, %eax
loop_1:
	addl %ecx, %eax
	loop loop_1
```

`loop` 一条指令 = `dec %ecx` + `jne loop_1`（先减后判）。执行序列：eax 依次加 100, 99, …, 1；当 ecx 从 1 减到 0 时 ZF=1，loop 不再跳。和 = 100×101/2 = 5050。随后 `pushl %eax; pushl $output; call printf; add $8,%esp` 打印 "The value is: 5050"，exit(0)。注意 ecx 终值 0，且 loop 指令在现代 CPU 上很慢（微码拆分），工程上多用 dec+jne 代替。

### betterloop.s

`betterloop.s:8-13`：

```asm
	movl $0, %ecx
	movl $0, %eax
	jcxz done
loop_1:
	addl %ecx, %eax
	loop loop_1
```

ECX=0 时 `jcxz done` 成立，直接跳到 done，一次循环都不进——保护了"空循环"边界（否则 `loop` 会先把 0 减成 0xFFFFFFFF 再跑 40 多亿圈）。打印 eax=0。踩坑记录：done 之后第 15-17 行 `pushl/pushl/call printf` 后**没有** `add $8,%esp` 清栈（对比 loop.s:16 有），因为紧接着就 int 0x80 退出、栈马上作废，所以没有实际危害；但如果 exit 换成后续更多逻辑，这 8 字节泄漏就是 bug。

### calltest.s

`calltest.s:9-29`（节选骨架）：

```asm
	pushl $1
	pushl $output
	call printf
	add $8, %esp
	call overhere
	pushl $3
	pushl $output
	call printf
	add $8, %esp
	pushl $0
	call exit
overhere:
	pushl %esp
	movl %esp, %ebp
	pushl $2
	pushl $output
	call printf
	add $8, %esp
	movl %ebp, %esp
	popl %ebp
	ret
```

运行输出顺序："this is section 1 / 2 / 3"。逐段看 overhere：入口时 [ESP]=返回地址。`pushl %esp` 把"指向返回地址的旧 ESP"压栈；`movl %esp,%ebp` 令 EBP 指向该保存值；打印 2 并 `add $8,%esp` 后 ESP 回到这里；`movl %ebp,%esp; popl %ebp` 从栈中弹回那个旧 ESP 值赋给 EBP（EBP 并未恢复调用前的值，而是拿到了一个栈地址），ESP 恰好落在返回地址上；`ret` 弹出返回地址回到 main。整个骨架能跑，是因为 main 部分不使用 EBP；标准写法应是 `pushl %ebp; movl %esp,%ebp … popl %ebp`。最后 `pushl $0; call exit` 走 libc exit，退出码 0（对比其他文件用 int $0x80）。

### cmovtest.s

`cmovtest.s:11-19`：

```asm
	movl values, %ebx
	movl $1, %edi
loop:
	movl values(, %edi, 4), %eax
	cmp %ebx, %eax
	cmova %eax, %ebx
	inc %edi
	cmp $10, %edi
	jne loop
```

`cmp %ebx,%eax` 算 eax−ebx（dst−src），`cmova`（= if above：CF=0 且 ZF=1）即无符号 eax>ebx 时把 eax 送进 ebx。全程 ebx 保持"已扫过的最大值"。数据 105,235,61,315,134,221,53,145,117,5 → 打印 "the largest value is 315"，退出码 0（`call exit`）。两点提醒：其一，全部值均为正数，用无符号 cmova 和有符号 cmovg 结果相同；若数组含负数（如 -1=0xFFFFFFFF），cmova 会把它当 4294967295 选为最大——有符号场景必须换 `cmovg`。其二，cmp $10,%edi 与 jne 组合等价于循环 9 次扫描 values[1..9]，含 values[0] 的初值共 10 个。

### bubble.s

`bubble.s:9-26`：

```asm
	movl $values, %esi
	movl $9, %ecx
	movl $9, %ebx
loop:
	movl (%esi), %eax
	cmp %eax, 4(%esi)
	jge skip
	xchg  %eax, 4(%esi)
	movl %eax, (%esi)
skip:
	add $4, %esi
	dec %ebx
	jnz loop
	dec %ecx
	jz end
	movl $values, %esi
	movl %ecx, %ebx
	jmp loop
```

`cmp %eax,4(%esi)` 计算 values[i+1]−values[i]（内存−寄存器）；`jge skip`（SF==OF）表示已有序则不交换。乱序时 `xchg %eax,4(%esi)` 是原子交换：执行后 eax=旧 values[i+1]、内存 values[i+1]=旧 values[i]，再 `movl %eax,(%esi)` 写入 values[i]，完成一次相邻交换——注意若漏写这条 mov，旧 values[i] 就丢了。内层由 EBX 计数（9 次比较），外层由 ECX 计数（9 趟），`dec %ebx; jnz` 与 `dec %ecx; jz` 都用 DEC 顺带置的 ZF/SF 控制流。对 10 个元素跑满 9 趟，最终 `.data` 中 values 变为升序 `5,10,53,61,105,117,134,221,235,315`（可用 gdb `x/10dw &values` 验证，程序本身不打印）。退出码 0。

## 实践与踩坑

- `echo $?` 是这类不打印、只设退出码的程序（jumptest/cmptest）唯一的观测手段；退出码只取低 8 位，负数会回绕（见第 7 章 inttest.s）。
- cmp 的操作数顺序：AT&T 是 `cmp src,dst` 算 dst−src，与 Intel 手册的 `CMP dest,src` 直觉相反。写完 jge/jle 类代码务必代一组具体数手推标志位，或者 `info register eflags` 单步确认。
- 有符号/无符号条件码混用不报错但逻辑错：cmova 对负数、jge 对大无符号数都会给反直觉结果；本仓库三个比较例子（cmptest/cmovtest/bubble）数据全部为正，恰好掩盖了这一点。
- loop/jcxz 的尺寸：32 位地址下 jcxz/loop 看的是完整 ECX；不要把 ECX 计数器清零后忘了哨兵（betterloop 的用意）。
- calltest.s 的 `pushl %esp` 骨架依赖"调用者不用 EBP"这一脆弱前提，模仿时请改回 `pushl %ebp; movl %esp,%ebp; …; popl %ebp; ret`。
- printf 前若后续用 `int $0x80` 退出（loop.s/betterloop.s 风格），stdout 是行缓冲还是全缓冲取决于是否 tty；重定向到文件时可能看不到输出，可换 `call exit`（cmovtest/bubble 之外的 calltest 风格）或先 `fflush`。本仓库未处理，实测为准。

## 复习清单

- [ ] 口述 CF/ZF/SF/OF 在 `cmp %eax,%ebx`（ebx−eax）后如何随 10 vs 15 取值，jge 为何不跳。
- [ ] 解释 `loop` 的一条指令做了哪两件事，ECX=0 会发生什么，jcxz 如何补救。
- [ ] 手推 bubble.s 一轮交换中 xchg 前后 eax、(%esi)、4(%esi) 三个位置的值。
- [ ] 说明 cmova 的成立条件（CF、ZF），以及数组含负数时应换成什么指令。
- [ ] 画出 calltest.s 从 `call overhere` 到 `ret` 期间 ESP/EBP 各自指向什么。
