> 笔记对应《Professional Assembly Language》(Richard Blum) 第 8 章，代码为本仓库实际敲过的样例。

# 第 8 章 基本数学功能：整数运算指令集

## 本章要点

- ADD/SUB 是双操作数指令（目的操作数同时是源），不允许内存到内存；GNU as 用 AT&T 语法 `addl %src, %dst`，后缀 b/w/l 决定操作宽度（Byte/Word/Long）。
- 六个标志位是本章核心：CF（Carry Flag，无符号进位/借位）、ZF、SF、OF（Overflow Flag，有符号溢出）、PF、AF（Auxiliary Flag，半字节进位）。无符号错误看 CF，有符号错误看 OF，二者相互独立（addtest3.s vs addtest4.s）。
- ADC（Add with Carry）/SBB（Subtract with Borrow）把 CF 当作第 33 位参与运算，是 32 位 CPU 上做 64 位（.quad）加减法的标准手法：先 `addl` 低 32 位，再 `adcl` 高 32 位（adctest.s/sbbtest.s）。
- MUL（无符号乘）/IMUL（有符号乘）在结果超过 32 位时写入 `edx:eax`；DIV（无符号除）商在 eax、余数在 edx，被除数必须是 edx:eax 对，故 edx 要先清/装高位。
- 十进制调整指令 AAA（ASCII Adjust after Addition）、DAS（Decimal Adjust after Subtraction）配合 AAM/AAD 处理非压缩/压缩 BCD（Binary-Coded Decimal）算术（aaatest.s/dastest.s）。
- 辅助指令：BSWAP（字节序翻转，big-endian↔little-endian）、CMPXCHG/CMPXCHG8B（比较并交换，原子操作原语，Pentium 起）。

## ADD 与 SUB 族

- `add/sub 操作数2, 操作数1`：AT&T 顺序与 Intel 相反，结果写操作数1。
- 宽度后缀必须与寄存器匹配：`%al` 配 `addb`、`%bx` 配 `addw`、`%eax` 配 `addl`。
- `movsx %al, %eax`（符号扩展 Move with Sign-Extend）在本仓库写法不带尺寸后缀，某些 GNU as 版本要写 `movsbl %al, %eax`。
- 负数在 CPU 里是二进制补码（two's complement），ADD 对正负一视同仁；只有 OF 才告诉你有符号结果是否错。

## 进位与溢出检测：ADC / SBB / JC / JO

- ADC 定义：`dst = dst + src + CF`；SBB 定义：`dst = dst - src - CF`。
- 64 位模拟：低半 `addl` 置 CF，高半 `adcl` 吃掉 CF；减法同理 `subl`+`sbbl`。
- `jc`（Jump if Carry）看 CF 判无符号越界；`jo`（Jump if Overflow）看 OF 判有符号越界。负+负得正是 OF 的典型触发条件。

## 乘除族：MUL / IMUL / DIV

- `mull src`：`edx:eax = eax * src`（无符号，64 位结果）；高 32 位非零时 CF=OF=1。
- IMUL 有一/二/三操作数形式：`imull %ebx, %ecx`（ecx*=ebx）、`imull $2, %edx, %eax`（eax=edx*2，三操作数只存低 32 位）。
- `divl src`：`eax = edx:eax / src`，`edx = edx:eax MOD src`。32 位被除数必须保证 edx=0，否则 #DE（Divide Error）。

## BCD 调整：AAA / DAS

- 非压缩 BCD（unpackeBCD）每字节只放一个十进制位（低 4 位）。`aaa` 规则：若 AF=1 或 al>9，则 `al+=6`、`ah+=1`、`al 高 4 位清零`、CF=AF=1；否则仅清高 4 位、CF=AF=0。carry 通过 CF 交给下一位的 `adcb`（aaatest.s）。
- `das`（压缩 BCD 减法后调整）：低半字节>9 或 AF=1 → al-=6 且 AF=1；CF=1 或高半字节>9 → al-=0x60 且 CF=1（dastest.s）。

## 辅助指令：BSWAP / CMPXCHG / CMPXCHG8B

- `bswap %ebx`：32 位寄存器按字节逆序，`0x12345678 → 0x78563412`，用于大小端转换。
- `cmpxchg %ebx, data`（AT&T 里 dest 在内存）：若 `eax == data` 则 `data = ebx`、ZF=1；否则 `eax = data`、ZF=0。
- `cmpxchg8b data`（Pentium 引入）：64 位版本，比较 `edx:eax` 与 mem64，相等则写入 `ecx:ebx`。

## 仓库对应代码

| 文件名 | 演示内容 | 关键指令/片段 |
|---|---|---|
| addtest1.s | ADD 的 b/w/l 宽度、立即数/寄存器/内存三种源 | `addb $10, %al`、`movsx`、`addl data, %eax` |
| addtest2.s | 负数（补码）参与 ADD | `addl data, %eax`（data=.int -40） |
| addtest3.s | 8 位加法进位，JC 分支 | `addb %al, %bl` + `jc over` |
| addtest4.s | 32 位有符号溢出，JO 分支，调 printf | `addl %eax, %ebx` + `jo over` |
| adctest.s | ADC 拼 64 位加法 | `addl %ebx, %edx` / `adcl %eax, %ecx` |
| sbbtest.s | SBB 拼 64 位减法 | `subl %ebx, %edx` / `sbbl %eax, %ecx` |
| multest.s | 无符号 MUL，edx:eax 存 .quad 结果 | `mull data2`、`movl %edx, result+4` |
| imultest.s | IMUL 双/三操作数形式 | `imull %ebx, %ecx`、`imull $2, %edx, %eax` |
| divtest.s | DIVL 商与余数分放 | `divl divisor`、`movl %edx, remainder` |
| aaatest.s | 非压缩 BCD 多位加法 + AAA | `adcb` / `aaa` / `loop loop1` |
| dastest.s | 压缩 BCD 多字节减法 + DAS | `sbbb` / `das` |
| swaptest.s | BSWAP 字节序翻转 | `bswap %ebx` |
| cmpxchgtest.s | CMPXCHG 32 位比较交换 | `cmpxchg %ebx, data` |
| cmpxchg8Btest.s | CMPXCHG8B 64 位比较交换 | `cmpxchg8b data` |

## 逐文件详解

### addtest1.s — ADD 的宽度与寻址

`addtest1.s:12-21`：

```
	movb $20, %al
	addb $10, %al
	movsx %al, %eax
	movw $100, %cx
	addw %cx, %bx
	movsx %bx, %ebx
	movl $100, %edx
	addl %edx, %edx
	addl data, %eax
	addl %eax, data
```

逐步推演（十进制）：%al=20+10=30 → `movsx` 符号扩展 30（正数）→ %eax=30；%bx=0+100=100 → %ebx=100；%edx=100+100=200（自身相加演示，不碰 eax）；`addl data, %eax`：eax=30+40=70；`addl %eax, data`：内存作目的，data=40+70=**110**。退出码 0。注意同一变量既当源又当目的，演示 ADD 是读-改-写指令。

### addtest2.s — 负数加法

`addtest2.s:9-16`：%eax=-10，加 data(-40) → -50；加 %ecx(80) → 30；加 %ebx(-200) → **-170**；写回 data=-40+(-170)=-210；`addl $210, data` 后 data=0。全程未越 32 位补码范围，CF 虽有无意义（有符号不看 CF），OF=0。

### addtest3.s — 进位检测与退出码反转

`addtest3.s:6-16`：

```
	movl $0, %ebx
	movb $190, %bl
	movb $100, %al
	addb %al, %bl
	jc over
	movl $1, %eax
	int $0x80
over:
	movl $1, %eax
	movl $0, %ebx
	int $0x80
```

190+100=290=0x122，8 位放不下：%bl=0x22(34)，CF=1 → `jc over` 必跳。语义是"进位=成功"，所以 over 路径退出码 0、fall-through 路径退出码 1——与直觉"出错才非零"相反（详见踩坑）。movb 只改低字节，%ebx 先清零是必要的。

### addtest4.s — 溢出检测（JO）

`addtest4.s:9-25`：%ebx=-1590876934（0xA12D24FA），%eax=-1259230143（0xB4F1AC41）。真值 -2850107077 小于 -2^31，32 位回绕得 0x561ED13B=1444860219（正数）。负+负=正 → OF=1，`jo over` 跳转。over 分支 `pushl $0` 后 printf，实际打印 "The result is 0"（演示的是"检测到溢出"这一事实，不打印回绕值）。此文件用了 libc（printf/exit），须用 `gcc` 链接而非 `as+ld`。

### adctest.s — ADC 做 64 位加法

`adctest.s:13-18`：data1=7252051615（低字 0xB041869F=2957084319，高字 1），data2=5732348928（低字 0x55ACB400=1437381632，高字 1）。`addl %ebx, %edx`：2957084319+1437381632=4394465951 ≥ 2^32 → 低字 99498655(0x5ED9E4BF)，CF=1。`adcl %eax, %ecx`：1+1+1=3。最终 edx:ecx 重组的 64 位结果 = 3×2^32+99498655 = **12984400543**，即 7252051615+5732348928，正确。printf 用 `%qd`（旧式 long long 格式）。

### sbbtest.s — SBB 做 64 位减法

`sbbtest.s:17-18`：`subl %ebx, %edx`：2957084319-1437381632=1519702687（0x5A94D29F），无借位 CF=0；`sbbl %eax, %ecx`：1-1-0=0。结果 = **1519702687** = 7252051615-5732348928，正确。若低位产生借位，高位会自动多减 1，这正是 SBB 的价值。

### multest.s — 无符号 MUL

`multest.s:15-18`：eax=315814，`mull data2`（165432）→ 64 位积 52245741648 = **edx=12，eax=706134096(0x2A16C050)**。`movl %eax, result` / `movl %edx, result+4` 演示小端 .quad 的手动拼装：低字放低地址。乘积 >2^32，故 CF=OF=1（MUL 用 CF 表示"高位非零"）。

### imultest.s — IMUL 多格式

`imultest.s:13-17`：二操作数形式 %ecx = -35 × 10 = **-350**（0xFFFFFEA2）；三操作数形式 `imull $2, %edx, %eax` = 400×2=**800**，但 %eax 随即被退出码覆盖，结果只能 gdb 里看。两结果均在 32 位可表示范围内，OF/CF=0。

### divtest.s — DIV 与余数位置

`divtest.s:17-21`：被除数 8335 是 .quad，低字进 eax、高字 0 进 edx（必须清高位否则商溢出 #DE）。`divl divisor` → eax=**333**（商），edx=**10**（余数），8335=25×333+10。`movl %edx, remainder` 就是 DIV 唯一的"副作用"取回。注意 pushl 的是 quotient/remainder 变量（内存操作数=值），不是地址。

### aaatest.s — 非压缩 BCD 逐位加法

`aaatest.s:13-23`：value1 字节序 [5,2,1,8,3]（低地址=低位）表示十进制 38125，value2 [3,3,9,2,5] 表示 52933。每轮：装一位 → `adcb`（带上轮 CF）→ `aaa`。逐位推演：5+3=8；2+3=5；1+9=10 → al 调成 0、CF=1；8+2+1=11 → al+=6 得 0x11，掩低半字节 =1、CF=1；3+5+1=9、CF=0。sum 数组 = [8,5,0,1,9,0] → 十进制 **91058** = 38125+52933，正确。循环后 `adcb $0, sum(, %edi, 1)` 把最终进位写入第 6 字节（此处为 0）。注意 `aaa` 会顺手 `ah+1`，%ah 被污染但无害——只存 %al。

### dastest.s — 压缩 BCD 逐字节减法

`dastest.s:16-22`：value2 字节 [0x33,0x29,0x05]=压缩 BCD 52933，value1 [0x25,0x81,0x02]=28125。逐轮：0x33-0x25=0x0E → DAS 低半>9 → al-=6 → **0x08**；0x29-0x81 借位 → al=0xA8、CF=1 → DAS 高半>9 → al-=0x60 → **0x48**、CF 保持 1；0x05-0x02-1=0x02 → **0x02**、CF=0。循环尾 `sbbb $0, result(,%edi,1)` 写 0。result = [08,48,02,00] → **24808** = 52933-28125，正确。本文件没有 `clc`，首轮 CF=0 全靠 `xor %edi, %edi` 恰好清 CF（逻辑运算清 CF/OF）——运气式正确，值得警惕。

### swaptest.s — BSWAP

`swaptest.s:6-7`：%ebx=0x12345678 → `bswap` → **0x78563412**。隐藏彩蛋：退出码取 %ebx 低 8 位，`echo $?` 得 **0x12=18**，正好验证最高字节被换到了低位。

### cmpxchgtest.s — 32 位比较交换

`cmpxchgtest.s:9-11`：eax=10 与 data(=10) 相等 → ZF=1，data ← %ebx=**5**。若不等则 data 不变而 eax ← data（用于原子循环重试）。这是 LOCK XADD/CAS 无锁编程的原语。

### cmpxchg8Btest.s — 64 位比较交换

`cmpxchg8Btest.s:9-13`：data 8 字节 [0x11..0x88] 小端组成 edx:eax 期望值（低字 0x44332211、高字 0x88776655）。eax=0x44332211、edx=0x88776655 完全匹配 → ZF=1，mem64 ← ecx:ebx = 0x22222222:0x11111111，data 变为 [0x11,0x11,0x11,0x11,0x22,0x22,0x22,0x22]。不匹配则 edx:eax 被刷成内存现值。

## 实践与踩坑

- **addtest3.s 的退出码语义是反的**：`jc over` 跳到 `over:` 后 exit(0)，即"检测到进位=程序成功"；不跳反而 exit(1)。照抄书例时用 `echo $?` 验证，别按"非零=出错"的常识读。
- **aaatest.s 的 `movb value1(, %edi, 1), %al`**：不带 `$` 是内存操作数（取该地址的字节），带 `$` 就变成了立即数（地址值本身）——BCD 逐位取数必须不带 `$`；`b` 尺寸后缀不可省略，因为基址变长寻址不告诉汇编器读写几个字节，且 `value1` 是 .byte 标签无类型信息。GNU as 对无基址的 `disp(, %reg, scale)` 形式完全接受。
- **dastest.s 缺 `clc`**：靠前面 `xor %edi,%edi` 清 CF 侥幸成立；改成先 `movl $3,%ecx` 之类的写法就可能首轮带错借位。BCD/多精度循环开头显式 `clc` 是好习惯（aaatest.s 就写了）。
- **ADC/SBB 顺序不可颠倒**：必须先低字 `addl/subl` 再高字 `adcl/sbbl`，反了 CF 无从产生。
- **DIV 忘清 edx**：`divtest.s` 用 .quad 高字 0 恰好清 edx；若直接对被除数是 .int 的变量做 `divl`，edx 残留随机值会触发 Divide Error（SIGFPE）。
- **addtest1.s 的 `movsx %al, %eax`**：新汇编器要求 `movsbl %al, %eax`；报 "operand type mismatch" 时补后缀。
- **addtest4.s/multest.s 等依赖 printf/exit**：必须 `gcc -m32 xxx.s` 链接；纯 `as+ld` 会 undefined reference to printf。`%qd` 是老 glibc 的 64 位格式，现代写成 `%lld`。
- **cmpxchg8b 在 32 位用户态无锁前缀也能用**（Pentium+），但跨核原子性需 `lock` 前缀；本例单线程只演示语义。

## 复习清单

- [ ] 能说出 CF/OF 分别在什么情况下有意义，并解释 addtest3 与 addtest4 为何一个用 jc 一个用 jo
- [ ] 能手推 adctest.s 的 12984400543 与 sbbtest.s 的 1519702687
- [ ] 能解释 mull 后 edx:eax = 12:706134096 怎么来的，以及 result 变量的拼装方式
- [ ] 能写出 divl 前为什么 edx 必须为 0，并说出 8335/25 的商余
- [ ] 能用 AAA 的"+6、ah+1、掩低半字节"规则逐位复算 aaatest.s 得 91058
- [ ] 能解释 DAS 在 dastest.s 第二轮如何把 0xA8 调成 0x48
- [ ] 能说出 bswap 后 %ebx=0x78563412 及退出码 18 的原因
- [ ] 能写出 CMPXCHG 相等/不等两条路径各改写哪个寄存器/内存
