# 第16章 使用文件(Working with Files)

> 笔记对应《Professional Assembly Language》(Richard Blum) 第 16 章，代码为本仓库实际敲过的样例。

## 本章要点

- 纯系统调用做文件 I/O 的三步曲：open（号 5）→ write（号 4）→ close（号 6），全程不经 C 标准库。
- open 的参数协议：`%ebx`=路径名指针、`%ecx`=标志位（flags，八进制常量）、`%edx`=权限模式（mode）；成功返回文件描述符（file descriptor），失败返回负错误码。
- 标志 `01101`（八进制）= O_WRONLY(1) | O_CREAT(0100) | O_TRUNC(01000)：只写、没有则创建、有则清空——"覆盖写"组合。
- 错误处理靠检查返回值符号位：`test %eax, %eax; js badfile`——int 0x80 失败不设置 errno 变量，负数就在 %eax 里。
- 文件 I/O 的返回值语义与 write 到 stdout 不同：必须用 open 返回的句柄，不能凭空用 3 之类的数字。

## 一、cpuidfile.s 全流程

先取 CPUID 并填进格式串（与第 17 章 cpuid.s 同款手法，见 cpuidfile.s:12-17），然后进入文件操作。

打开：

```
	movl $5, %eax
	movl $filename, %ebx
	movl $01101, %ecx
	movl $0644, %edx
	int $0x80

	test %eax, %eax
	js badfile
	movl %eax, filehandle
```
（cpuidfile.s:19-27）

- `filename: .asciz "cpuid.txt"`（cpuidfile.s:3-4）必须是 NUL 结尾路径串。
- `%ecx=01101`（八进制字面量，GNU as 里前导 0 即八进制）= O_WRONLY|O_CREAT|O_TRUNC；`%edx=0644` = rw-r--r-- 权限（受 umask 再裁剪）。
- 成功后 `movl %eax, filehandle` 把描述符存进 `.lcomm filehandle, 4`（cpuidfile.s:8）——后面两次调用都要从内存取它，因为 %eax 很快会被挪用。

写入：

```
	movl $4, %eax
	movl filehandle, %ebx
	movl $output, %ecx
	movl $42, %edx
	int $0x80
	test %eax, %eax
	js badfile
```
（cpuidfile.s:29-35）

write 的参数布局与 stdout 那次完全相同，只是 %ebx 从 1 换成打开返回的句柄；长度 42 是整条消息（28 前缀 + 12 厂商 ID + 2 结尾引号换行）。

关闭与退出：

```
	movl $6, %eax
	movl filehandle, %ebx
	int $0x80

badfile:
	movl %eax, %ebx
	movl $1, %eax
	int $0x80
```
（cpuidfile.s:37-44）

注意 `badfile` 的双重身份：成功路径 close 之后**顺序落入** badfile，把 close 的返回值（0）当退出码正常终止；失败路径则是 js 跳进来，把负错误码交给 exit 当退出码。一次标签两用，省了一段 jmp——但可读性差，是书例的"聪明写法"。

## 二、结果验证：cpuid.txt

运行 `./cpuidfile` 后目录里生成：

```
the processor vendor ID is 'GenuineIntel'
```
（cpuid.txt:1，本仓库留存的实际输出）

注意与屏幕版 cpuid.s 的差异：串首字母小写（"the processor..."），且 `output` 占位符从 28(%edi) 起被 ebx/edx/ecx 三段覆盖（cpuidfile.s:14-17），最终 42 字节写全。

## 三、对照：不用文件的两个近亲

- cpuid2.s：把厂商 ID 拷进 `.lcomm buffer, 12`（cpuid2.s:6-16）后用 `printf("%s")` 打印——第 16 章之前"文件=终端"的对照组，证明同一段 cpuid 数据可以走 C 库、也可以走裸 syscall。
- cpuid.s：直接 write 到 fd 1。三者构成同一数据的三条出口：stdout 裸调用 / stdout C 库 / 磁盘文件。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| cpuidfile.s | open/write/close 全 syscall 文件输出 | `movl $5, %eax`；`movl $01101, %ecx`；`test %eax, %eax; js badfile` |
| cpuid.txt | 程序运行产物（结果留档） | 第一行即 'GenuineIntel' 输出 |
| cpuid2.s | 对照：同数据走 printf（C 库 I/O） | `pushl $buffer; pushl $output; call printf` |

## 逐文件详解

- **cpuidfile.s**：全文件只有四个寄存器复用模式（eax 号、ebx 参数 1、ecx 参数 2、edx 参数 3），把第 12 章协议落到真实场景。`.section .bss` 只放了 filehandle 一个变量——"能进寄存器的短命值"与"必须跨调用保存的值"的分界很清晰。
- **cpuid.txt**：`cat cpuid.txt` 与 stdout 运行结果应一致；文件内容证明 O_TRUNC 生效（重复运行不会变成两行）。
- **cpuid2.s（交叉引用第 17 章）**：本章只关心它的 I/O 侧：printf 内部也是 fflush/write 系统调用族，但程序视角是"缓冲流"；对比两者 strace 可以看到差异（实践 4）。

## 实践与踩坑

1. **flags 是八进制不是十进制**：把 `01101` 写成 `1101`（十进制）后 O_CREAT 位丢失，文件不存在时 open 直接返回 -2（-ENOENT）。GNU as 里 `0` 前缀即八进制，务必保留。
2. **句柄忘了存**：open 后若不先 `movl %eax, filehandle` 就设置 write 参数，%eax 被覆盖，write 拿着垃圾 fd 返回 -EBADF（-9）。
3. **badfile 的 fallthrough 是双刃剑**：close 失败时也会以 close 的错误码退出，语义上"写成功但关失败"与"从未打开"共用一个出口，真实代码应分开处理。
4. **length 与内容不同步**：改格式串忘了改 `%edx=42`，文件就短一截或多出尾部残留；nanotest.s 的 `.equ` 差值写法可以移植过来根治。
5. **混用 printf 与裸 write 的乱序**：C 库全缓冲到换行/flush，裸 write 立刻落盘；同一 fd 上两种写法交织会乱序——demo 里最好只用一种。
6. **验证手法**：`strace ./cpuidfile` 能直接看到 openat/write/close 序列与返回值，是本章节最好的"显微镜"。

## 复习清单

- [ ] 默写 open/write/close 的调用号与参数寄存器分配。
- [ ] 解码 01101 与 0644：分别对应哪些 O_* 位、哪些权限位。
- [ ] 解释 test/js 判负数的原理与"没有 errno 变量"的含义。
- [ ] 说明 badfile 同时充当错误出口与正常出口的执行路径。
- [ ] 能对比 cpuid.s、cpuid2.s、cpuidfile.s 三条输出通路的系统调用差异。
