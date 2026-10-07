# ass
A place to store my assembly language code.

学习下Professional Assembly Language这本书，一样是边看边敲。将一些汇编代码段记录在github上。

## 学习笔记

按书中译本章节整理的笔记在 [docs/](docs/README.md)，含每章对应的代码文件、逐文件详解与踩坑记录：[docs/README.md](docs/README.md)。

## 构建与多平台检查

[.github/workflows/build.yml](.github/workflows/build.yml) 会在 Linux（i386 汇编+链接+运行、x86-64 产物）、Windows（i686 GNU as 语法检查）、macOS（可移植 C 例子）上跑 [scripts/asm-ci.sh](scripts/asm-ci.sh)。本地执行方式与每个分组的原因都写在该脚本头部注释里。
