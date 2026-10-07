# 第12章 使用Linux系统调用(Using Linux System Calls)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 12 章，代码为本仓库实际敲过的样例。

## 本章要点

- 32 位 Linux 上用户态陷入内核的统一入口是 `int $0x80`（软中断，software interrupt）。
- 调用约定（calling convention）：系统调用号放 `%eax`，参数依次放 `%ebx`、`%ecx`、`%edx`、`%esi`、`%edi`、`%ebp`，返回值回到 `%eax`。
- 返回值若为 -1 ~ -4095 表示负错误码（errno 取反），判断办法是看返回值是否为负，例如 `test %eax, %eax; js`（见 cpuidfile.s，另见第 16 章）。
- 系统调用会破坏 `%ebx`（它是第一个参数寄存器），用 `loop` 指令时必须 `pushl %ecx` / `popl %ecx` 保护计数器（nanotest.s、paramtest1.s 都是这个手法）。
- 常用调用号（本仓库用到的）：1=exit、4=write、5=open、6=close、20=getpid、24=getuid、47=getgid、162=nanosleep。
- `cpuid` 不是系统调用，是 CPU 特性查询指令（instruction），但它和 `int $0x80` 在同一个小程序 cpuid.s 里配对演示："查硬件 + 报结果"。

## 一、最小骨架与三个取 ID 的调用

`syscalltest.s` 全篇就是四次系统调用：

```
	movl $20, %eax
	int $0x80
	movl %eax, pid

	movl $24, %eax
	int $0x80
	movl %eax, uid
```
（syscalltest.s:9-14）

- `%eax=20` → getpid，返回值（进程 ID）留在 `%eax`，立刻 `movl %eax, pid` 存进 `.bss` 的 `.lcomm pid, 4`（syscalltest.s:3）。
- `%eax=24` → getuid（真实用户 ID），`%eax=47` → getgid（syscalltest.s:17-19）。
- 结尾 `%eax=1`（exit）、`%ebx=0`（退出码）陷入内核结束进程（syscalltest.s:22-24）。这三个调用无参数，所以 `%ebx` 等都不用设——最能看清"号在 eax、返回值在 eax"的模式。

## 二、带参数的调用：write 与 nanosleep

`nanotest.s` 循环 10 次，每轮做一次 write + 一次 nanosleep：

```
	movl $4, %eax
	movl $1, %ebx
	movl $output, %ecx
	movl $len, %edx
	int $0x80

	movl $162, %eax
	movl $timespec, %ebx
	movl $rem, %ecx
	int $0x80
```
（nanotest.s:17-26）

- write(2)：`%ebx=1`（stdout 文件描述符，file descriptor），`%ecx=缓冲区地址`，`%edx=长度`。长度用汇编期常量：`.equ len, output_end - output`（nanotest.s:8），由两个相邻标号之差算出字符串字节数，比硬编码可靠。
- nanosleep(2)：`%ebx` 指向 `timespec` 结构（`.int 5, 0` = 5 秒 0 纳秒，nanotest.s:3-4），`%ecx` 指向剩余时间缓冲 `.lcomm rem, 8`（nanotest.s:10）。
- 循环骨架 `movl $10, %ecx` + `loop loop1`，而 write/nanosleep 都会把 `%ecx` 当参数寄存器踩掉，所以循环体外圈 `pushl %ecx` … `popl %ecx`（nanotest.s:16、27）——与第 11 章 cfunctest.s 的手法同源，这里的原因从"printf 破坏寄存器"变成"系统调用协议破坏寄存器"。

## 三、cpuid 指令与 _start 入口

`cpuid.s` 是全仓库唯一用 `_start` 作入口的文件：

```
	movl $0, %eax
	cpuid
	movl $output, %edi
	movl %ebx, 28(%edi)
	movl %edx, 32(%edi)
	movl %ecx, 36(%edi)
```
（cpuid.s:8-13）

- `cpuid` 按 `%eax` 里的"叶"(leaf) 返回信息：leaf 0 时 `%eax`=最大支持叶号，厂商 12 字符串拆成三段放在 `%ebx`、`%edx`、`%ecx`。
- 输出串是 `output: .ascii "The processor Vendor ID is 'xxxxxxxxxxxx'\n"`（cpuid.s:3-4），28 个前导字符后正好是 12 个 `x`，所以三条 `movl` 直接覆盖 28/32/36(%edi)——占位符被真厂商 ID（如 GenuineIntel）原地替换。
- 随后是标准的 write(4) 调用：`%ebx=1`、`%ecx=$output`、`%edx=42`（cpuid.s:14-18），再 exit(1)（cpuid.s:19-20）。
- 入口是 `_start` 且纯 `as` + `ld` 链接即可，不需要 C 运行时——这也是它和 `.globl main` 系文件的本质区别。

## 四、main 入口时的 argc/argv

`paramtest1.s` 从栈顶取 argc、沿栈取 argv 逐个 printf（paramtest1.s:10-26，详见第 11 章第六节）。需要在本章语境下说准的是：

- **直接入口（_start 风格）**：内核把 argc 压在栈顶 `(%esp)`，argv 数组指针从 `4(%esp)` 开始——paramtest1.s 的 `movl (%esp), %ecx` 与 `movl %esp, %ebp; addl $4, %ebp` 后按 `(%ebp)` 迭代，按这个模型是自洽的。
- **glibc 启动后进入 main**：argc 在 `%eax`、argv 在 `%ecx`（寄存器约定，不走栈参数）。用 `gcc paramtest1.s` 链接时走的是这条路，`(%esp)` 处实际是返回地址。

所以同一个文件在不同链接方式下输出差异巨大，这是本章最重要的实践结论。

## 五、系统调用号哪里查

书上的思路是查 `/usr/include/asm/unistd.h`（或 `syscall(2)` 手册页）。本仓库文件里出现的号全部能与 32 位 x86 Linux ABI 对上：1/4/5/6/20/24/47/162。注意 64 位 ABI 用 `syscall` 指令且寄存器表完全不同（rdi/rsi/rdx…），本章代码一律是 32 位的 `int $0x80`。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| syscalltest.s | 无参数调用 getpid/getuid/getgid 并存返回值 | `movl $20, %eax` + `int $0x80` + `movl %eax, pid` |
| nanotest.s | write+nanosleep 循环计时输出 | `.equ len, output_end - output`；`pushl %ecx`/`popl %ecx` 保 loop 计数 |
| cpuid.s | cpuid leaf 0 取厂商 ID，_start 入口，write 输出 | `movl %ebx, 28(%edi)` 三连；`movl $42, %edx` |
| paramtest1.s | 栈上 argc/argv 的启动约定；printf/exit 混用 | `movl (%esp), %ecx`、`pushl (%ebp)`、`call exit` |

## 逐文件详解

- **syscalltest.s**：三个 `.lcomm` 变量 pid/uid/gid（syscalltest.s:3-5）演示"系统调用返回值第一时间离开 %eax 就没处找了"，每次 `int $0x80` 后第一件事就是 `movl %eax, 变量`。结尾用了标号 `end:`（syscalltest.s:21）但并无跳转指向它，只是可读性分段。
- **nanotest.s**：`.ascii` 不带结尾 NUL，因为它只需要按 len 计长输出，不需要 C 字符串语义（nanotest.s:6-8）。timespec/rem 都是 8 字节=两个 `.int`（秒、纳秒）。10 轮 x 5 秒 = 约 50 秒的运行时长，可用 Ctrl-C 中断。
- **cpuid.s**：`movl $output, %edi` 之后用 28/32/36 偏移覆盖占位符的写法，要求你精确数对前导空格字符数——`xxxx` 区长度 12 恰等于厂商串长度，`write` 长度 42 = 全串长度。改格式串必须同步改这两处。
- **paramtest1.s vs cpuid.s**：同样调 printf 系列 vs 纯系统调用，paramtest1.s 必须 `gcc` 链接（有 `call printf/exit`），cpuid.s 可以 `as`+`ld` 直链（入口 `_start`，全用 int 0x80）。对照着跑一遍最能体会两种入口约定的差别。

## 实践与踩坑

1. **%ecx 忘保存**：nanotest.s 若去掉 16/27 行的 push/pop，第一轮 `int $0x80` 后 `%ecx` 变成 write 返回的字节数（16），`loop` 会把循环跑成 16 次甚至更多——参数寄存器同时是"会被踩的寄存器"。
2. **系统调用失败不设置 errno 变量**：失败时 `%eax` 直接是负错误码（如 -9 = -EBADF），要 `test %eax, %eax; js` 判负，C 库的 `perror` 在这里用不上。
3. **exit 前不冲刷 stdio**：`call exit`（glibc）会冲刷缓冲，`int $0x80` 号 1 直接终止——若混用 printf 与直接退出，可能丢输出。paramtest1.s 用 `call exit` 是对的。
4. **write 的长度要数准**：cpuid.s 的 42、cpuidfile.s 的 42（cpuidfile.s:32）都是硬编码，与串长不一致就会少打或多打垃圾；nanotest.s 的 `.equ len` 是推荐写法。
5. **64 位机器上直链要加 `--nmagic`/`-m elf_i386`**：`ld` 默认 64 位模式时 `ld cpuid.o` 会报 `unresolvable relocation R_386_PC32`，需 `ld -m elf_i386 -e _start -o cpuid cpuid.o`（`-e` 指定入口）。
6. **`_start` 与 `main` 不能混**：文件里写 `.globl main` 又被 `ld` 直链会报入口符号找不到；写 `.globl _start` 又用 `gcc` 链接会和你链进的 crt 冲突或重复定义。

## 复习清单

- [ ] 背下 int $0x80 的寄存器协议：eax 号，ebx/ecx/edx/esi/edi/ebp 参数，eax 返回值。
- [ ] 能说出 1/4/5/6/20/24/47/162 各对应哪个调用。
- [ ] 解释 nanotest.s 里 pushl/popl %ecx 的必要性，以及与 cfunctest.s 同手法的原因差异。
- [ ] 说明 `.equ len, output_end - output` 怎么算出字符串长度。
- [ ] 区分 _start（argc 在 (%esp)）与 glibc main（argc 在 %eax、argv 在 %ecx）两种启动约定，并知道 paramtest1.s 在不同链接方式下的行为。
- [ ] 知道系统调用失败时错误码就在 %eax（负数），没有 errno 全局变量。
