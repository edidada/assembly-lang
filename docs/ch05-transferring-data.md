# 第5章 传送数据 (Moving Data)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 5 章，代码为本仓库实际敲过的样例。

## 本章要点

- MOV (传送指令) 不改变任何标志位 (flags)，只做比特拷贝；按源/目的位置分为：立即数(Immediate)、寄存器(Register)、内存(Memory) 三种操作数形态的组合。
- AT&T 语法 (AT&T syntax) 中源在前、目的在后；立即数带 `$`，内存绝对地址直接写标号，取标号本身的地址要写 `$标号`。
- 变址寻址 (indexed addressing) 的统一形式是 `disp(base, index, scale)`；省略 base 就是 `disp(, index, scale)`，MOV 的内存操作数与 CMP/JMP 等共用这一记法。
- PUSH/POP (压栈/出栈) 支持 `.b/.w/.l` 后缀，可以不对称地压入 2 字节再弹出 2 字节，但必须自己保证栈平衡；`popw` 只改写低 16 位，寄存器高 16 位保留旧值。
- `.bss` 段 (Block Started by Symbol) 中的 `.lcomm`/`.comm` 预留空间不占可执行文件磁盘体积；`.data` 中的 `.fill` 会实打实地增大文件——sizetest1~3 就是用 `size`/`ls` 对比这一点。
- MOV 只拷贝指定位宽：`movb`/`movw` 只改目的寄存器的低 8/16 位，高位残留旧数据（未初始化部分不可依赖）。

## MOV 的四种寻址用法

movtest1~4 恰好凑成一组"源→目的"矩阵：

| 样例 | 方向 | 指令形态 |
|---|---|---|
| movtest1 | 内存 → 寄存器 | `movl value, %ecx`（直接寻址 direct addressing） |
| movtest2 | 寄存器 → 内存 | `movl %eax, value` |
| movtest3 | 内存 → 寄存器（变址） | `movl values(, %edi, 4), %eax` |
| movtest4 | 立即数 → 内存（间接） | `movl $100, 4(%edi)` |

`movl value, %ecx` 里的 `value` 是链接期确定的绝对地址（32 位扁平寻址下），取的是该地址处的 4 字节内容；而 `movl $values, %edi`（movtest4.s:10）取的是地址本身。二者差别就是一个 `$`，这是 AT&T 语法最容易踩的坑。

`disp(base, index, scale)` 形式中 effective address（有效地址）= disp + base + index×scale，scale 只允许 1/2/4/8。movtest3 省略 base，等价于 `values + edi*4`。

## PUSH 与 POP

`pushl 操作数` 先把 ESP 减 4 再写入；`popl` 先读出再把 ESP 加 4。栈从高地址向低地址生长（full descending stack）。pushpop.s 演示了三件事：

1. 位宽后缀混用：`pushl %ecx`(4B)、`pushw %bx`(2B)、`pushl %eax`(4B) 连续入栈，出栈顺序严格 LIFO (Last In First Out)，且 `popw %ax` 要与 `pushw` 配对才能保持 ESP 对齐。
2. `pushl data` 与 `pushl $data` 的区别：前者压入内存里的 125，后者压入 data 的地址。
3. `movb $100, %eax` 只写 al=100，`pushl %eax` 会把 eax 高 24 位里原有的垃圾一并压栈。

## 数据段的存储与可执行文件体积

sizetest1~3 是同一套 `_start`（exit(0)）三种数据布局，专门用 `size a.out` 和 `ls -l` 观察：

- `.text` 段与 `.data` 段的内容会原样进入 ELF 文件，占磁盘空间；
- `.bss` 段只在程序头 (program header) 里记录"运行时请给我 N 字节零页"，文件里不存这 N 字节，所以 sizetest2 与 sizetest1 体积几乎一致；
- `.fill 10000` 的第一个操作数是对象个数，默认每个 1 字节、填 0——sizetest3 的 `.data` 实打实多了 10000 字节。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| movtest1.s | 内存→寄存器直接寻址 | `movl value, %ecx` |
| movtest2.s | 寄存器→内存 | `movl %eax, value` |
| movtest3.s | 变址寻址遍历数组并 printf | `movl values(, %edi, 4), %eax` |
| movtest4.s | 间接寻址改内存、退出码取自数组 | `movl $100, 4(%edi)`、`movl $values, %edi` |
| pushpop.s | push/pop 位宽配对、值与地址之争 | `pushw %bx`/`popw %ax`、`pushl data`/`pushl $data` |
| sizetest1.s | 基线：只有 .text 的程序体积 | 无数据段 |
| sizetest2.s | .bss/.lcomm 不占文件空间 | `.lcomm buffer, 10000` |
| sizetest3.s | .data/.fill 实占 10000 字节 | `buffer: .fill 10000` |

## 逐文件详解

### movtest1.s（memory→register）

`movtest1.s:8`：

```asm
		movl value, %ecx
```

`value:` 位于 `.data`，内容 `.int 1`。执行后 ECX=1。注意本文件没有 `.code32`/`main`，是裸 `_start`：`movl $1,%eax; movl $0,%ebx; int $0x80` 即 `exit(0)`。MOV 不影响任何标志位。

### movtest2.s（register→memory）

`movtest2.s:8-9`：

```asm
		movl $100, %eax
		movl %eax, value
```

value 的 4 字节由 1 变为 100（小端存储：`64 00 00 00`，可用 `x/4xb &value` 验证）。第 10 行又用 `movl $1,%eax` 覆盖 eax，所以想确认写入结果只能看内存，不能看寄存器。

### movtest3.s（变址寻址 + printf 循环）

`movtest3.s:12-21`：

```asm
	movl $0, %edi
loop:
	movl values(, %edi, 4), %eax
	pushl %eax
	pushl $output
	call printf
	addl $8, %esp
	inc %edi
	cmpl $11, %edi
	jne loop
```

values 有 11 个元素（10,15,…,60）。每轮把 `values[edi]` 入栈打印，`addl $8,%esp` 是 cdecl 调用约定 (calling convention) 下由调用方清栈。edi 从 0 走到 11，`cmpl $11,%edi; jne` 控制终止。最终输出 11 行 "the value is 10 … 60"，exit(0)。文件头第 2 行注释给出了构建命令 `gcc -m32 -o movtest3 movtest3.s`；用 `main` 而非 `_start` 是因为要链接 libc 的 printf。

### movtest4.s（间接寻址，退出码=100）

`movtest4.s:9-13`：

```asm
	movl values, %eax        # eax = values[0] = 10（取内容）
	movl $values, %edi       # edi = &values（取地址）
	movl $100, 4(%edi)       # values[1] = 100（改内存）
	movl $1, %edi
	movl values(, %edi, 4), %ebx   # ebx = values[1] = 100
```

随后 `exit(ebx)`：这个程序 `echo $?` 应显示 100——被写入内存的值经数组再读出，形成闭环验证。逐条寄存器终值：eax=10、edi=1、ebx=100。

### pushpop.s（压栈出栈全推演）

`pushpop.s:9-22`：

```asm
	movl $24420, %ecx
	movw $350, %bx
	movb $100, %eax
	pushl %ecx
	pushw %bx
	pushl %eax
	pushl data
	pushl $data

	popl %eax
	popl %eax
	popl %eax
	popw %ax
	popl %eax
```

入栈序（自底向上）：24420 | bx 低 16 位(350) | eax 全体(al=100，高 24 位为垃圾) | 内存 data 的值 125 | data 的地址。出栈严格按 LIFO，逐条追 `popl %eax`：

1. 第一次弹出：eax = data 的地址；
2. 第二次：eax = 125；
3. 第三次：eax = 最初压入的那个"al=100、高位垃圾"的 eax 原值——内容不可预测；
4. `popw %ax`：弹出 pushw 压入的 350，只写 ax，eax 高 16 位仍是上一步的垃圾高位；
5. 第五次：eax = 24420。

终值：ecx=24420、ebx 的 bx=350（`movw $350,%bx` 不清高 16 位，此时 main 入口 EBX 原为 argc，高位残留，见"踩坑"）、eax=24420。第 23-24 行重置 `ebx=0; eax=1` 后 exit(0)。三次连续 `popl %eax` 中间值只能靠 gdb 观察。

### sizetest1.s / sizetest2.s / sizetest3.s（体积对比）

三者代码段完全相同：

```asm
	movl $1, %eax
	movl $0, %ebx
	int $0x80
```

差异只在数据：sizetest1 无数据段；sizetest2 用 `sizetest2.s:3` 的 `.lcomm buffer, 10000`（`.bss`）；sizetest3 用 `sizetest3.s:4` 的 `.fill 10000`（`.data`）。预期 `size` 输出中 AOS（文件尺寸）为 sizetest3 比另两者大约 10KB，而 data+bss 段三者分别是 0 / ≈10000(bss) / ≈10000(data)。`.lcomm` 语法 `.lcomm 名字, 字节数`，直接在 .bss 预留空间。

## 实践与踩坑

- 构建：本仓库统一 `gcc -m32 -xx.s -o xx` 或 `as/ildd` 两步。现代发行版默认 PIE，链接 `_start` 风格且使用绝对地址重定位（movtest1~4 都直接引用标号）时可能报重定位错误，可加 `-no-pie` 或 `-static` 重试（本仓库样例未记录此参数，需现场验证）。
- `movl value,%ecx` 与 `movl $value,%ecx`：取内容还是取地址只差一个 `$`，写错时汇编器不报错，结果完全不同。movtest4 两行放在一起正是刻意对照。
- `movb`/`movw` 不清高位：movtest1 若改用 `movb`，ECX 高 24 位是执行前的残值；pushpop.s 里 `movw $350,%bx` 也保留了 EBX 高 16 位（libc 入口传进 main 的 argc 相关残值）。想清零要先 `movl $0,%ebx` 或用 `movzwl`/`movzbl`（见第 5 章后半，本仓库未敲）。
- push/pop 位宽不配对会错位：`pushw` 只压 2 字节，若用 `popl` 弹就多读 2 字节并把 ESP 多加 4。本例 `pushw`/`popw` 是配对的；改一处就栈崩。
- `main` 里混用 `int $0x80` 退出：movtest3/4 等以 `main` 为入口却用 `eax=1,ebx=n` 的 exit 系统调用直接退出，绕过 libc 收尾；能跑（本仓库均如此），但 printf 的缓冲在旧 glibc 上可能来不及刷新就退出——观察到的现象应以实测为准，必要时换 `call exit`（见第 6 章 calltest.s）。
- 32 位 `int $0x80` 在 x86-64 Linux 上走 ia32 兼容层，通常可用；容器/内核裁剪了 32 位 ABI 时会 `SEGV` 或 `ENOSYS`。

## 复习清单

- [ ] 说出 `movl value,%ecx`、`movl $values,%edi`、`movl values(,%edi,4),%ebx`、`movl $100,4(%edi)` 四种形态各自"取内容"还是"取地址"。
- [ ] 写出 `disp(base,index,scale)` 的有效地址公式与 scale 的合法取值。
- [ ] 手工推演 pushpop.s 五个弹出后 eax 各是什么（含 popw 只写低 16 位这一点）。
- [ ] 解释为什么 `.lcomm buffer,10000` 不增大可执行文件而 `.fill 10000` 会。
- [ ] 用 `size` 命令复现 sizetest1~3 的对比并记录三者的 text/data/bss。
- [ ] 确认 movtest4.s 的退出码是 100 并能用 `echo $?` 验证。
