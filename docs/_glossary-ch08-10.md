> 笔记对应《Professional Assembly Language》(Richard Blum) 第 8~10 章，代码为本仓库实际敲过的样例。

# 术语表（第 8~10 章）中英对照

配套文件：docs/ch08-integer-instructions.md、docs/ch09-floating-point.md、docs/ch10-string-instructions.md

## 第 8 章：整数运算与标志位

| 中文 | 英文 | 释义 / 出现位置 |
|---|---|---|
| 加 | ADD (Add) | addtest1~4.s |
| 带进位加 | ADC (Add with Carry) | adctest.s，dst=dst+src+CF |
| 带借位减 | SBB (Subtract with Borrow) | sbbtest.s，dst=dst-src-CF |
| 无符号乘 | MUL (Multiply Unsigned) | multest.s，结果入 edx:eax |
| 有符号乘 | IMUL (Signed Multiply) | imultest.s，一/二/三操作数形式 |
| 无符号除 | DIV (Divide Unsigned) | divtest.s，商 eax、余 edx |
| 有符号除 | IDIV (Signed Divide) | 本章提及，仓库未敲样例 |
| 加法后 ASCII 调整 | AAA (ASCII Adjust after Addition) | aaatest.s，非压缩 BCD |
| 减法后十进制调整 | DAS (Decimal Adjust after Subtraction) | dastest.s，压缩 BCD |
| 乘法/除法后 ASCII 调整 | AAM / AAD (ASCII Adjust after Multiply/Division) | 正文概念，样例未覆盖 |
| 二进制编码十进制 | BCD (Binary-Coded Decimal) | aaatest/dastest |
| 非压缩 / 压缩 BCD | Unpacked / Packed BCD | 每字节 1 位 vs 2 位十进制 |
| 进位标志 | CF (Carry Flag) | 无符号越界；jc 检测 |
| 溢出标志 | OF (Overflow Flag) | 有符号越界；jo 检测 |
| 零/符号/奇偶/半进位标志 | ZF / SF / PF / AF (Zero/Sign/Parity/Auxiliary Flag) | AF 供 AAA/DAS 用 |
| 方向标志 | DF (Direction Flag) | 第 10 章，cld/std |
| 二进制补码 | Two's Complement | addtest2.s 负数 |
| 字节序翻转 | BSWAP (Byte Swap) | swaptest.s |
| 大端 / 小端 | Big-Endian / Little-Endian | .quad 手工拼字（adctest/multest） |
| 比较并交换 | CMPXCHG (Compare and Exchange) | cmpxchgtest.s |
| 64 位比较并交换 | CMPXCHG8B | cmpxchg8Btest.s，Pentium 起 |
| 交换加 | XADD (Exchange and Add) | 正文提及，未敲样例 |
| 符号扩展 | MOVSX (Move with Sign-Extension) | addtest1.s |
| 零扩展 | MOVZX (Move with Zero-Extension) | 正文概念 |

## 第 9 章：x87 浮点

| 中文 | 英文 | 释义 / 出现位置 |
|---|---|---|
| 浮点运算单元 | FPU (Floating-Point Unit) | 全章 |
| 寄存器栈 | Register Stack (st(0)~st(7)) | fpuvals.s 七连压 |
| 栈顶 | Top of Stack, st(0) | 编号随 TOP 指针重映射 |
| 状态字 / 控制字 / 标签字 | Status Word / Control Word / Tag Word | premtest.s 读状态字 |
| 比较标志 | C0~C3 (Condition Codes) | C2=FPREM 约简未完，位 10 |
| 浮点初始化 | FINIT (FPU Initialize) | premtest.s 开头 |
| 装入单/双精度 | FLDS / FLDL (Load Floating) | floattest.s、tempconv.s |
| 装入整型 | FILD (Load Integer) | fildl，area.s / tempconv.s |
| 存储 / 存储并弹栈 | FSTS / FSTPS (Store / Store and Pop) | area.s |
| 预置常量 | Load Constant (FLD1, FLDL2T, FLDPI, FLDLG2, FLDLN2, FLDZ) | fpuvals.s |
| 乘 / 乘并弹栈 | FMUL / FMULP | areafunc.s / area.s |
| 反向减除 | Reverse 后缀 r（FSUBR/FDIVR/FMULP 族） | tempconv.s 的 fsubrp/fdivrp |
| 精确部分余数 | FPREM1 (IEEE Partial Remainder) | premtest.s |
| 部分余数 / 完全约简 | Partial Remainder / Full Reduction | C2 循环判据 |
| 扩展精度 | Extended Precision (80-bit) | FPU 内部运算宽度 |
| 单精度 / 双精度 | Single / Double Precision (IEEE 754) | .float=4B、.double=8B |
| 最近舍入 | Round-to-Nearest | FPREM1 商用取整方式 |
| 位型 / 位模式 | Bit Pattern | area.s 经 %eax 返回 float 编码 |
| 可变参数 | Variadic Arguments (varargs) | printf %f 需传 double |
| 提升（float→double） | Widening / Promotion | tempconv.s 的 flds+fstpl |
| 调用约定 | Calling Convention (cdecl) | 浮点返回值留在 st(0) |
| 应用程序二进制接口 | ABI (Application Binary Interface) | tempconv.s 对照意义 |

## 第 10 章：字符串指令

| 中文 | 英文 | 释义 / 出现位置 |
|---|---|---|
| 串传送 | MOVS (Move String) | movstest1~3、reptest1~2 |
| 串比较 | CMPS (Compare String) | cmpstest1~2 |
| 串存储 | STOS (Store String) | convert.s 的 stosb |
| 串装载 | LODS (Load String) | convert.s 的 lodsb |
| 串扫描 | SCAS (Scan String) | 正文概念，未敲样例 |
| 重复前缀 | REP (Repeat Prefix) | reptest1/2 |
| 相等/为零时重复 | REPE / REPZ (Repeat while Equal/Zero) | cmpstest2.s |
| 不等/非零时重复 | REPNE / REPNZ | 正文概念 |
| 源变址寄存器 | Source Index (%esi) | 全部字符串样例 |
| 目的变址寄存器 | Destination Index (%edi) | 全部字符串样例 |
| 计数寄存器 | Counter (%ecx) | reptest、cmpstest2 |
| 清/置方向标志 | CLD / STD (Clear/Set Direction Flag) | movstest2.s 用 std |
| 循环指令 | LOOP (Loop while ECX not Zero) | movstest3.s、convert.s |
| 就地转换 | In-Place Transformation | convert.s esi=edi |
| 缓冲区溢出 | Buffer Overflow | reptest2.s（书中错误示例） |
| 剩余计数 | Remaining Count (ECX after REP) | cmpstest2 退出码 38 |

## 通用 / 工具类

| 中文 | 英文 | 释义 |
|---|---|---|
| 汇编语法（源,目的 顺序） | AT&T Syntax | 本仓库全部 .s |
| 汇编器 / 链接器 | GNU as / GNU ld | 32 位需 .code32 与 -m32 |
| 以零初始化节 | .bss / .lcomm (Reserve Space) | 各样例缓冲区 |
| 系统调用中断 | System Call Interrupt (int $0x80) | eax=1 → exit(ebx) |
| 退出状态码 | Exit Status | 内核取 %ebx 低 8 位 |
| 调试器 | GDB (GNU Debugger) | `info float` 看 ST 栈 |
