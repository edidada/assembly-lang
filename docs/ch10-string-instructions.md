> 笔记对应《Professional Assembly Language》(Richard Blum) 第 10 章，代码为本仓库实际敲过的样例。

# 第 10 章 处理字符串：MOVS / CMPS / STOS / LODS / REP

## 本章要点

- 字符串指令使用三个隐式寄存器：%esi=源变址（Source Index）、%edi=目的变址（Destination Index）、%ecx=计数器（Counter）；指令本身不写它们，只靠后缀 b/w/l 定宽度（MOVS**B**、CMPS**L** 等）。
- 方向标志 DF（Direction Flag）决定 %esi/%edi 自动增减方向：`cld`（Clear Direction Flag）后 +1/+2/+4，`std`（Set Direction Flag）后 -1/-2/-4。Linux 进程入口 DF=0，多数程序可依赖默认正向。
- MOVS（Move String）：内存到内存搬运后两侧指针同步移动；CMPS（Compare String）：相减置标志但**不保存结果**，只动指针；STOS（Store String）把 %al/%ax/%eax 写入 (%edi) 并移动 %edi；LODS（Load String）把 (%esi) 装入 %al 等并移动 %esi。
- REP 前缀把指令重复 %ecx 次（每次先检 ecx≠0、递减）；REPE/REPZ 与 REPNE/REPNZ 再加 ZF 条件，专为 CMPS/SCAS 的"匹配即继续/直到匹配"设计。
- 这些指令**没有任何边界检查**：ecx×操作尺寸超过缓冲区就是静默越界读写——reptest2.s 正是书中给出的反面教材。

## MOVS 族：三种宽度连用与 DF

`movstest1.s:10-14`：

```
	leal value, %esi
	leal output, %edi
	movsb
	movsw
	movsl
```

一条 movsb 搬 1 字节、movsw 搬 2 字节、movsl 搬 4 字节，指针各按宽度自增。适合"量体裁衣"式分段搬；整串搬则用循环（movstest3.s）或 REP（reptest1.s）。`std` 反序搬运见 movstest2.s。

## CMPS 族与 REPE

- `cmpsl`：比较 (%esi) 与 (%edi)，等价做 `src - dest` 置 EFLAGS——注意方向影响 SF/CF 的含义但 ZF 只管相等与否。
- `repe cmpsb`：ZF=1 且 ecx≠0 继续；首次不等（ZF=0）或 ecx 耗尽即停。停机后 %ecx = 剩余次数，可反推差异位置；ZF/CF 告诉你"谁大谁小"。
- CMPS 之后直接 `je` 分支是惯用法（cmpstest1/2 均如此）。

## LODS / STOS：就地转换流水线

`convert.s:15-22` 展示 `lodsb`（取一字节进 %al）→ 条件改写 → `stosb`（写回并推进 %edi）的最短转换回路。二者组合时无需任何显式寻址。

## REP 前缀与 LOOP 的取舍

- `rep movsb`（reptest1.s）一条顶 `movsb + loop` 二十三圈（movstest3.s），且微码在长串上更快。
- LOOP 指令自带 `decl %ecx; jne`，与 REP 复用同一个 %ecx，二者混用时注意别嵌套抢寄存器。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| movstest1.s | MOVS 正向三段搬（b/w/l） | `movsb`/`movsw`/`movsl` |
| movstest2.s | std 反向搬 | `std` + `leal value+22, %esi` |
| movstest3.s | LOOP 手写整串复制 | `movsb` + `loop loop1` |
| reptest1.s | REP MOVS 正确用法 | `rep movsb`（ecx=23） |
| reptest2.s | **书中错误示例**：REP MOVSL 越界 | `rep movsl`（ecx=6=24 字节） |
| cmpstest1.s | 单条 CMPSL 比较相等 | `cmpsl` + `je equal` |
| cmpstest2.s | REPE CMPSB 找首个差异 | `repe cmpsb`、`movl %ecx, %ebx` |
| convert.s | LODSB/STOSB 大小写转换 | `lodsb`/`subb $0x20, %al`/`stosb` |

## 逐文件详解

### movstest1.s — 正向 MOVS 的三段搬运

源串 23 字节 `"this is a test string.\n"`（`movstest1.s:4`），output 为 `.lcomm output, 23`。未写 cld（入口 DF=0）。逐条推演：movsb 搬 [0]='t'，esi/edi→1；movsw 搬 [1..2]="hi"，指针→3；movsl 搬 [3..6]="s is"，指针→7。合计 output[0..6]=**"this is"**（t-h-i-s-空格-i-s），[7..22] 保持 .bss 的 0。%esi=%edi=起点+7。

### movstest2.s — 反向搬运的字节落点

`movstest2.s:10-15`：`std` 后从 `value+22`/'\n'（下标 22）起手，指针只会减。movsb 搬 [22]='\n'，指针→21；movsw 搬 [20..21]="g."，指针→19；movsl 搬 [16..19]="trin"，指针→15。落点：output[16..22]=**"tring.\n"**，其余为 0。反向 MOVS 按"块"对齐递减：每次以当前指针为块高端取数，保证字符串倒着搬仍不撕裂字节序（小端下 movsw/movsl 取出的整字与原串同序）。

### movstest3.s — LOOP 版整串复制

`movstest3.s:12-16`：`movl $23, %ecx; cld; loop1: movsb; loop loop1`。每圈搬 1 字节并让 loop 递减 %ecx、非零跳转，23 圈后整串完整复制，内容与 reptest1.s 等价；%esi/%edi 各 +23。这是理解 REP 语义的"手工档"。

### reptest1.s — REP MOVS 正确姿势

`reptest1.s:10-14`：ecx=23 与串长、缓冲区大小（23 字节）三者一致，`rep movsb` 搬完 %ecx=0、无越界。REP 展开等价于 movstest3 的循环，但省去循环指令开销。

### reptest2.s — 错误示例逐段剖析

`reptest2.s:12-16`：

```
	leal value1, %esi
	leal output, %edi
	movl $6, %ecx
	cld
	rep movsl
```

三处叠加的错误：(1) `movsl` 每轮搬 **4 字节**，ecx=6 → 共 24 字节，而 value1 只有 23 字节：最后一轮把紧随其后（.data 中相邻放置）的 value2 首字节 'O'（0x4F）也当成串尾读走；(2) output 在 .bss 只 `.lcomm output, 23`，第 24 字节静默写坏 .bss 相邻数据——典型的缓冲区溢出；(3) 想按"字"数设置 ecx 时应为 23/4=5 且余 3 字节无法整除——该场景本就该用 `rep movsb` 配 ecx=23。结论：REP 不感知任何边界，字节数=ecx×尺寸必须由人算对。

### cmpstest1.s — CMPSL 判等

`cmpstest1.s:10-20`：两串都是 "Test"（4 字节）。先 `movl $1, %eax` 预定 exit 系统调用号（cmpsl 不碰 %eax，可提前装载）。cld 后一条 `cmpsl` 比较两 dword：'T'+'e'+'s'+'t' 两侧全同 → ZF=1 → `je equal` → ebx=0 → exit(0)。%esi/%edi 各前进 4。

### cmpstest2.s — REPE CMPSB 的差异定位

`cmpstest2.s:10-21`：value1 首字符 'T'（0x54），value2 首字符 't'（0x74）。`repe cmpsb` 第一轮即 0x54−0x74：ZF=0（不等）、CF=1（被减数小）→ 循环立刻退出，%ecx=**38**（39−1）。`je equal` 不跳，走 `movl %ecx, %ebx; int $0x80` → 退出码 **38**。读法：剩余计数 38 → 差异在下标 39−38=**0** 处；若两串全同则 ecx=0、ZF=1 → exit(0)。本例把"剩余 ecx 当退出码"只是演示，真实程序应算 `39-%ecx` 得偏移。

### convert.s — LODSB/STOSB 就地大小写转换

`convert.s:15-22`：

```
	lodsb
	cmpb $'a', %al
	jl skip
	cmpb $'z', %al
	jg skip
	subb $0x20, %al
skip:
	stosb
	loop loop1
```

`movl %esi, %edi`（`convert.s:11`）让两指针同起点：lodsb 读 (%esi) 后 +1，stosb 写 (%edi) 后 +1，两指针始终同步 → 字节 i 读 i 写 i，就地转换成立（若目的异址则退化为普通复制流）。逐字符规则：al 在 [a,z] 才 `subb $0x20`（ASCII 'a'−'A'=0x20），其余原样写回。43 个字符（length=.int 43，不含 .asciz 的 NUL）处理后得 **"THIS IS A TEST, OF THE CONVERSION PROGRAM!\n"**；NUL 在 [43] 原地未动，printf 安全收尾。`cmpb $'a'` 用字符常数、signed jl/jg 对 ASCII（<0x80）无符号歧义问题。

## 实践与踩坑

- **reptest2.s 是教科书级反例**，敲它不是为了用而是为了看懂坏在哪：movsl×6=24>23。用 `objdump -d` 或 gdb 观察 .data 中 value1/value2 相邻，能亲眼看到多读的那 1 字节正是 value2 的 'O'。
- **ecx 语义陷阱**：REP 的 ecx 是"迭代次数"不是"字节数"——`rep movsb` 时恰好相等，`rep movsl` 时要记得 ×4。movstest3/reptest1 用 23 没问题，reptest2 沿用 6（按字数脑算）就炸。
- **std 之后必须记得 cld**：movstest2.s 结尾 DF 仍为 1；本例直接 exit 无害，但在真实程序里带 DF=1 返回 libc（如 glibc 的 REP STOS 优化路径按 DF=0 设计）会产生诡异反向写内存。System V ABI 要求函数返回时 DF=0。
- **CMPS 的比较方向**：AT&T 下 `cmpsb` 做 (%esi) − (%edi)，CF/SF 的"谁大于谁"读法与 `cmp` 一致；只用 je/jne 判等最稳，判大小先手画一遍。
- **LODS/STOS 单字符宽度**：只有 lodsb/stosb 配 %al 最省心；lods 不会帮你跳过 NUL，convert.s 靠显式 length 变量控制圈数。
- **cmpstest2 退出码上限 255**：exit 系统调用内核只取 ebx 低 8 位（本例 38 无碍），若用剩余计数当退出码需 ecx≤255 才可见。
- **性能注记**：短串（< 几十字节）用 loop/lodsb 循环可能快过 rep movsb（REP 启动开销），现代 CPU 的 ERMS 特性另谈；学习阶段以正确性为先。

## 复习清单

- [ ] 能默写 %esi/%edi/%ecx/DF 与 MOVS/CMPS/STOS/LODS/SCAS 的配合关系
- [ ] 能手算 movstest1 复制出的前 7 字节 "this is" 与 movstest2 的 "tring.\n" 落点
- [ ] 能解释 reptest2.s 的越界字节从哪来、写到哪去，并给出正确改法
- [ ] 能说出 cmpstest2.s 为什么 exit 码是 38、差异下标为什么是 0
- [ ] 能说明 convert.s 用同一缓冲区做 lodsb+stosb 为什么安全
- [ ] 能区分 repe cmpsb 与 loop+cmpsb+jne 的手写等价形式
- [ ] 知道 rep movsb 结束 %ecx=0，CMPS/STOS 类 REP 依赖 ZF 提前终止
