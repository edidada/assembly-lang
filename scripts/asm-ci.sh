#!/usr/bin/env bash
#
# asm-ci.sh — build/verify harness for the *Professional Assembly Language* samples.
#
# Usage: asm-ci.sh <mode>
#
#   linux32     GNU as, x86-32 (ELF, Linux i386 syscalls). Assemble + link + run.
#   linux64     GNU as, x86-64 (the gcc -S outputs that were generated in 64-bit mode)
#               plus the portable C examples.
#   win32-syntax  i686-w64-mingw32 GNU as --32: assemble-only syntax check.
#               int $0x80 has no meaning on Windows, so nothing is linked or run.
#   macos-c     Apple clang: compile + run the self-contained C examples only.
#
# Targets are grouped by *what the sample actually is*, not by chapter:
#   RUN_*     programs that must terminate on their own (no signal, no timeout)
#   LINK_ONLY programs that intentionally sleep for ~50s, or that need the Linux
#             startup registers (%eax = argc) and therefore fault when started
#             through the C runtime — the book demos them under gdb, not as
#             batch programs, so we only verify they build.
#
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

MODE=${1:-linux32}
CC=${CC:-gcc}
RUN_TIMEOUT=${RUN_TIMEOUT:-20}
OBJDIR=${OBJDIR:-/tmp/asm-ci}
# macOS has no coreutils `timeout`; without it the programs simply run unbounded
# (they are all finite loops, the guard is only there to catch a runaway build).
if command -v timeout >/dev/null 2>&1; then TMO="timeout $RUN_TIMEOUT"; else TMO=""; fi
rm -rf "$OBJDIR"
mkdir -p "$OBJDIR/obj" "$OBJDIR/bin" "$OBJDIR/log"

# ---------------------------------------------------------------- targets ---

# Programs with `.globl main` that exit(0) cleanly under -m32.
RUN_EXIT0="
aaatest adctest addtest1 addtest2 addtest3 addtest4 bcdtest betterloop bubble
calctest calctest2 cmovtest cmpstest1 condtest condtest2 convert cpuid2
cpuidfile dastest divtest floattest fpuvals functest1 globaltest imultest
loop mmxtest movstest1 movstest2 movstest3 movtest3 multest
premtest quadtest reptest1 reptest2 sbbtest signtest sse2float ssefloat
ssetest sums sums2 syscalltest pushpop
temp tempconv tempconv2 vartest vartest2
"

# Programs that finish normally but leave the exit status in %ebx (the book
# examples were meant to be stepped through in gdb, so the code is not 0).
RUN_ANYEXIT="cmpstest2 cmptest cmpxchgtest inttest jumptest movtest4 swaptest"

# Linux `_start` programs: no C runtime, linked with -nostartfiles.
RUN_NOSTART="cpuid movtest1 movtest2 sizetest1 sizetest2 sizetest3"

# Build but do not run: 50s of sleeps (cfunctest/nanotest) or argc taken from
# %eax, which only holds on a real _start (paramtest1).
LINK_ONLY="cfunctest nanotest paramtest1"

# asm object + companion translation unit.
PAIRS="
mainprog.c asmfunc.s
multtest.c greater.s
floattest.c areafunc.s
inttest.c square.s
stringtest.c cpuidfunc.s
functest2.s area.s
"

# Standalone C examples that build and run under -m32.
C_M32="
calctest cfunctest condtest csetest for globaltest ifthen mactest1 mactest2
regtest1 sums tempconv vartest
"

# x86-64 assembly actually present in the repo (gcc -S run on an x86-64 box:
# for.s / ifthen.s use pushq / %rsp / %rbp and only assemble in 64-bit mode).
ASM_X86_64="for ifthen"

# C examples with no inline asm and no external asm symbols: portable to any
# C compiler / OS.
C_PORTABLE="calctest cfunctest condtest csetest for ifthen mactest1 sums tempconv vartest"

# Sources whose section directives are ELF-specific. The win32-syntax pass now
# normalises those away, so nothing is skipped any more; the list is kept as an
# escape hatch for anything that genuinely cannot be expressed in COFF.
WIN_SKIP=""

# ----------------------------------------------------------------- helpers ---
pass=0
fail=0
failed=""

ok()   { pass=$((pass + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); failed="$failed
 - $1"; printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -s "${LOG:-}" ] && sed 's/^/       /' "$LOG" | head -20; return 0; }

hdr()  { printf '\n== %s ==\n' "$1"; }

# assemble <name> — object only
asm_obj() {
  LOG="$OBJDIR/log/$1.asm"
  if $CC $ASM_FLAGS -c -o "$OBJDIR/obj/$1.o" "$1.s" 2>"$LOG"; then ok "assemble $1.s"; else bad "assemble $1.s"; fi
}

# build_and_run <label> <exit-policy> <sources...>
build_and_run() {
  local label=$1 policy=$2; shift 2
  LOG="$OBJDIR/log/$label.link"
  if ! $CC $LD_FLAGS -o "$OBJDIR/bin/$label" "$@" 2>"$LOG"; then
    bad "link $label"; return
  fi
  if [ "$policy" = link ]; then ok "link $label"; return; fi
  LOG="$OBJDIR/log/$label.run"
  $TMO "$OBJDIR/bin/$label" >"$LOG" 2>&1
  local rc=$?
  if [ $rc -eq 124 ]; then
    bad "run $label (timed out after ${RUN_TIMEOUT}s)"
  elif [ $rc -ge 128 ] && [ $rc -le 160 ]; then
    # 128+n means the process died from signal n (139 = SIGSEGV, 134 = SIGABRT ...)
    bad "run $label (killed by signal $((rc - 128)))"
  elif [ "$policy" = exit0 ] && [ $rc -ne 0 ]; then
    bad "run $label (exit code $rc, expected 0)"
  else
    ok "run $label (rc=$rc)"
  fi
}

# c_build_and_run <name> <compiler flags>
c_build_and_run() {
  local name=$1 flags=$2
  LOG="$OBJDIR/log/$name.c"
  if ! $CC $flags -o "$OBJDIR/bin/c_$name" "$name.c" 2>"$LOG"; then
    bad "cc $name.c"
    return
  fi
  LOG="$OBJDIR/log/c_$name.run"
  $TMO "$OBJDIR/bin/c_$name" >"$LOG" 2>&1
  local rc=$?
  if [ $rc -ne 0 ]; then bad "run c_$name (rc=$rc)"; else ok "cc+run $name.c"; fi
}

# ------------------------------------------------------------------- modes ---
case "$MODE" in
  linux32)
    ASM_FLAGS="-m32 -no-pie"
    LD_FLAGS="-m32 -no-pie"
    hdr "assemble every .s (x86-32)"
    for f in *.s; do
      n=${f%.s}
      case " $ASM_X86_64 " in *" $n "*) printf '  skip %s.s (x86-64 only, built in the linux64 job)\n' "$n"; continue ;; esac
      asm_obj "$n"
    done

    hdr "programs: must exit 0"
    for n in $RUN_EXIT0; do
      [ -f "$n.s" ] || { bad "missing source $n.s"; continue; }
      build_and_run "$n" exit0 "$OBJDIR/obj/$n.o"
    done

    hdr "programs: exit status left in %ebx by the example"
    for n in $RUN_ANYEXIT; do build_and_run "$n" anyexit "$OBJDIR/obj/$n.o"; done

    hdr "programs: bare _start, no C runtime"
    for n in $RUN_NOSTART; do
      LOG="$OBJDIR/log/$n.link"
      $CC -m32 -no-pie -nostartfiles -o "$OBJDIR/bin/$n" "$n.s" 2>"$LOG" \
        && { $TMO "$OBJDIR/bin/$n" >"$OBJDIR/log/$n.run" 2>&1
             [ $? -eq 0 ] && ok "run $n (_start)" || bad "run $n (_start, rc=$?)"; } \
        || bad "link $n (_start)"
    done

    hdr "programs that only build (sleep 50s / need Linux startup regs)"
    for n in $LINK_ONLY; do build_and_run "$n" link "$OBJDIR/obj/$n.o"; done

    hdr "C + assembly translation units"
    set -- $PAIRS
    while [ $# -gt 0 ]; do
      a=$1; b=$2; shift 2
      label="pair_${a%.c}"; label=${label%.s}
      srcs=""
      for s in "$a" "$b"; do
        case "$s" in
          *.s) srcs="$srcs $OBJDIR/obj/${s%.s}.o" ;;
          *)   LOG="$OBJDIR/log/${s%.c}.pair"; $CC -m32 -no-pie -c -o "$OBJDIR/obj/${s%.c}.c.o" "$s" 2>"$LOG" || bad "cc $s"; srcs="$srcs $OBJDIR/obj/${s%.c}.c.o" ;;
        esac
      done
      build_and_run "$label" exit0 $srcs
    done

    hdr "standalone C examples (-m32)"
    for n in $C_M32; do c_build_and_run "$n" "-m32 -no-pie"; done
    ;;

  linux64)
    ASM_FLAGS="-no-pie"
    LD_FLAGS="-no-pie"
    hdr "x86-64 assembly samples (gcc -S output from a 64-bit box)"
    for n in $ASM_X86_64; do
      asm_obj "$n"
      build_and_run "$n" exit0 "$OBJDIR/obj/$n.o"
    done
    hdr "portable C examples (native 64-bit)"
    for n in $C_PORTABLE; do c_build_and_run "$n" "-no-pie"; done
    ;;

  win32-syntax)
    # GNU as for the i686-w64-mingw32 target (PE/COFF). Called directly: there is
    # no C runtime involved, we only prove the sources parse and encode.
    AS=${AS:-as}
    hdr "i686 COFF assemble-only syntax check (int \$0x80 cannot run on Windows)"
    for f in *.s; do
      n=${f%.s}
      case " $WIN_SKIP " in
        *" $n "*) printf '  skip %s.s (ELF-only .section attributes, see list in this script)\n' "$n"; continue ;;
      esac
      case " $ASM_X86_64 " in
        *" $n "*) printf '  skip %s.s (x86-64 output of gcc -S)\n' "$n"; continue ;;
      esac
      LOG="$OBJDIR/log/$n.asm"
      # GNU as exits non-zero for *warnings* too, and COFF GAS rejects the ELF-only
      # directives these sources use (`.type foo,@function`, `.size foo,4`,
      # `.section .text.unlikely,"ax",@progbits`, the `.cfi_*` unwind records the
      # gcc -S output carries). Those are object-format/DWARF metadata, not
      # instruction syntax, so the COFF pass normalises them away and the check
      # still covers every mnemonic, operand, label and section that is target neutral.
      sed -e '/^[[:space:]]*\.type[[:space:]].*,[[:space:]]*@/d' \
          -e '/^[[:space:]]*\.size[[:space:]]/d' \
          -e '/^[[:space:]]*\.cfi_/d' \
          -e '/^[[:space:]]*\.section[[:space:]]*\.note\.GNU-stack/d' \
          -e 's/^\([[:space:]]*\.section[[:space:]]*\.[A-Za-z0-9_.-]*\)[[:space:]]*,.*$/\1/' \
          "$f" > "$OBJDIR/norm-$n.s"
      rm -f "$OBJDIR/obj/$n.o"
      $AS --32 -o "$OBJDIR/obj/$n.o" "$OBJDIR/norm-$n.s" >"$LOG" 2>&1
      w=$(grep -c 'Warning:' "$LOG" || true)
      if grep -q 'Error:' "$LOG" || [ ! -s "$OBJDIR/obj/$n.o" ]; then
        bad "as --32 $f"
      elif [ "$w" -gt 0 ]; then
        ok "as --32 $f ($w COFF warning(s), no error)"
      else
        ok "as --32 $f"
      fi
    done
    ;;

  macos-c)
    hdr "self-contained C examples (Apple clang)"
    for n in $C_PORTABLE; do c_build_and_run "$n" ""; done
    ;;

  *)
    echo "unknown mode: $MODE" >&2
    exit 2
    ;;
esac

# ------------------------------------------------------------------ report ---
printf '\n================ %s ================\n' "$MODE"
printf 'passed: %s   failed: %s\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'failures:%s\n' "$failed"
  exit 1
fi
