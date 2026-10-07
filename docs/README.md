# 学习笔记 · Professional Assembly Language

> 书：Richard Blum, *Professional Assembly Language*（Wrox, 2005；中译本《汇编语言程序设计》，清华大学出版社）。
> 本目录按书中译本的章节顺序整理，每篇笔记的示例代码都取自本仓库里实际敲过的 `.s` / `.c` 文件，摘录时注明文件名与行号。

## 目录

### 第一部分 汇编语言程序设计环境基础

| 章节 | 笔记 | 对应代码 |
| --- | --- | --- |
| 第1章 什么是汇编语言 | [ch01-what-is-assembly.md](ch01-what-is-assembly.md) | 概念梳理，代码从第4章起 |
| 第2章 IA-32平台 | [ch02-ia32-platform.md](ch02-ia32-platform.md) | `cpuid.s`、`cpuid.txt`、`ssetest.s`、`mmxtest.s` |
| 第3章 相关的工具 | [ch03-development-tools.md](ch03-development-tools.md) | `compiler.md`、`jumptest.txt`（objdump 实录）、`pushpop.s` |
| 第4章 汇编语言程序范例 | [ch04-assembly-program-examples.md](ch04-assembly-program-examples.md) | `cpuid.s`、`cpuid2.s`、`sizetest1~3.s`、`movtest1~2.s` |

### 第二部分 汇编语言程序设计基础

| 章节 | 笔记 | 对应代码 |
| --- | --- | --- |
| 第5章 传送数据 | [ch05-transferring-data.md](ch05-transferring-data.md) | `movtest1~4.s`、`pushpop.s`、`sizetest1~3.s` |
| 第6章 控制执行流程 | [ch06-controlling-execution.md](ch06-controlling-execution.md) | `jumptest.s`、`cmptest.s`、`loop.s`、`betterloop.s`、`calltest.s`、`cmovtest.s`、`bubble.s` |
| 第7章 使用数字 | [ch07-working-with-numbers.md](ch07-working-with-numbers.md) | `inttest.s`、`quadtest.s`、`bcdtest.s`、`signtest.s`、`mmxtest.s`、`ssefloat.s`、`sse2float.s`、`floattest.s` |
| 第8章 基本数学功能 | [ch08-integer-instructions.md](ch08-integer-instructions.md) | `addtest1~4.s`、`adctest.s`、`sbbtest.s`、`multest.s`、`imultest.s`、`divtest.s`、`aaatest.s`、`dastest.s`、`swaptest.s`、`cmpxchgtest.s`、`cmpxchg8Btest.s` |
| 第9章 高级数学功能 | [ch09-floating-point.md](ch09-floating-point.md) | `fpuvals.s`、`premtest.s`、`area.s`、`areafunc.s`、`square.s`、`tempconv.c/.s` |
| 第10章 处理字符串 | [ch10-string-instructions.md](ch10-string-instructions.md) | `movstest1~3.s`、`cmpstest1~2.s`、`reptest1~2.s`、`convert.s` |
| 第11章 使用函数 | [ch11-using-functions.md](ch11-using-functions.md) | `functest1~2.s`、`asmfunc.s`+`mainprog.c`、`greater.s`+`multtest.c`、`cfunctest.s`、`paramtest1.s` |
| 第12章 使用Linux系统调用 | [ch12-linux-syscalls.md](ch12-linux-syscalls.md) | `syscalltest.s`、`nanotest.s`、`cpuid.s`、`paramtest1.s` |

### 第三部分 高级汇编语言技术

| 章节 | 笔记 | 对应代码 |
| --- | --- | --- |
| 第13章 使用内联汇编 | [ch13-inline-assembly.md](ch13-inline-assembly.md) | `mactest2.c`、`regtest1.c`、`globaltest.c/.s`、`vartest.c/.s` |
| 第14章 调用汇编库 | [ch14-assembly-libraries.md](ch14-assembly-libraries.md) | `area.s`/`areafunc.s`+`floattest.c`、`square.s`+`inttest.c`、`cpuidfunc.s`+`stringtest.c` |
| 第15章 优化例程 | [ch15-optimizing-routines.md](ch15-optimizing-routines.md) | `ifthen.c/.s`、`condtest.c/.s/.2.s`、`for.c/.s`、`sums.c/.s/.2.s`、`calctest.c/.s/.2.s`、`csetest.c`、`mactest1.c` |
| 第16章 使用文件 | [ch16-working-with-files.md](ch16-working-with-files.md) | `cpuidfile.s` |
| 第17章 使用高级IA-32特性 | [ch17-advanced-ia32.md](ch17-advanced-ia32.md) | `cpuid.s`、`cpuid2.s`、`mmxtest.s`、`ssetest.s`、`cmpxchg8Btest.s` |

### 复习用术语表

- [_glossary-ch01-04.md](_glossary-ch01-04.md)
- [_glossary-ch05-07.md](_glossary-ch05-07.md)
- [_glossary-ch08-10.md](_glossary-ch08-10.md)
- [_glossary-ch11-17.md](_glossary-ch11-17.md)

## 本地怎么跑

```sh
# Linux（需要 gcc-multilib / libc6-dev-i386 才能编 i386）
bash scripts/asm-ci.sh linux32      # 全书主战场：汇编 + 链接 + 运行
bash scripts/asm-ci.sh linux64      # for.s / ifthen.s 是 64 位产物，外加可移植 C 例子
AS=/mingw32/bin/as.exe bash scripts/asm-ci.sh win32-syntax   # Windows：只做语法/编码检查
CC=cc bash scripts/asm-ci.sh macos-c                          # macOS：只跑自包含的 C 例子
```

CI 见 `.github/workflows/build.yml`：ubuntu-22.04 / ubuntu-24.04 / windows-2022 / windows-2025 / macos-latest。

## 读代码前需要知道的几件事

1. **`for.s`、`ifthen.s` 是 64 位产物。** 它们是 `gcc -S` 时忘记加 `-m32` 的结果（`pushq %rbp`、System V 传参），只能用 64 位模式汇编，其余 75 个 `.s` 都是 i386。
2. **`pushpop.s:11` 原本写的是 `movb $100, %eax`**，GNU as 直接报错（`movb` 的目标不能是 32 位寄存器，书中该例是 `%al`）。原行保留但用 `.if 0` 变成惰性，下面补了正确的一行，构建不再被挡住。
3. **一部分例子退出码不是 0。** 它们用 `movl $1,%eax; int $0x80` 退出却没清 `%ebx`，退出码就是 `%ebx` 的残留值（`cmptest.s`=10、`jumptest.s`=20、`cmpstest2.s`=38、`movtest4.s`=100、`swaptest.s`=18、`cmpxchgtest.s`=5、`inttest.s`=211）。这些例子本来就是给 gdb 单步看的，脚本只要求它们"自己跑完、不被信号打死"。
4. **三个例子只构建不运行**：`cfunctest.s` 和 `nanotest.s` 循环 10 次、每次睡 5 秒（约 50s）；`paramtest1.s` 从 `(%esp)` 取 argc，而通过 glibc 的 `main` 进来时 argc 在 `%eax`，直接跑会段错误——这是 Linux 启动约定的坑，不是笔误。
5. **`reptest2.s` 是书中的反例**（`rep movsl` 多搬一个字节越界），`dastest.s` 缺 `clc`、`addtest3.s` 的进位分支语义相反，详见对应章节的"实践与踩坑"。
