# com

```shell
[root@10-23-29-39 assembly-lang]# as -o cpuid2.o cpuid2.s
[root@10-23-29-39 assembly-lang]# gcc -o cpuid2 cpuid2.o
[root@10-23-29-39 assembly-lang]# ./cpuid2 
Segmentation fault (core dumped)
```

gdb一条一条指令跟
ni是单步指令的命令

