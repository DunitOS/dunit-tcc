#!/bin/sh
# Build a host-hosted tcc that TARGETS the Dunit sysroot (x86_64-dunit, static).
#
# This is the P1 intermediate: a Linux-hosted cross-tcc that emits native Dunit
# static ELFs (crt + libc.a from the Dunit musl sysroot). The on-device
# /system/bin/tcc (built with dunit-cc) comes in a later phase; both share this
# configuration. See PORTING.md.
#
# Usage:  tools/dunit/build-tcc.sh <abs-path-to-dunit-sysroot>
#   e.g.  tools/dunit/build-tcc.sh /path/to/dunit-os/build/dunit-sysroot
#
# Notes on the configure flags:
#   --config-musl        libc is musl, not glibc (linking/crt conventions).
#   --config-bcheck=no   bounds checker runtime uses glibc-isms (__ctype_b_loc);
#   --config-backtrace=no deferred with -run/-bt (PORTING.md P5).
#   --sysincludepaths .../include:{B}/include   our headers + tcc's own ({B}).
#   --libpaths .../lib:{B}   our libc.a + tcc's libtcc1.a (lives at {B}).
#   --crtprefix .../lib  crt1.o/crti.o/crtn.o from the Dunit musl sysroot.
#   --tcc-switches=-static   static-only (no dynamic loader on Dunit yet).
set -e

SYSROOT="${1:?usage: build-tcc.sh <abs-path-to-dunit-sysroot>}"
case "$SYSROOT" in /*) ;; *) echo "sysroot must be an absolute path" >&2; exit 1;; esac
[ -f "$SYSROOT/lib/libc.a" ] || { echo "no libc.a under $SYSROOT/lib" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")/../.." && pwd)"   # fork root
cd "$HERE"

make clean >/dev/null 2>&1 || true
./configure \
  --cc="${CC:-gcc}" \
  --config-musl --config-bcheck=no --config-backtrace=no \
  --sysincludepaths="$SYSROOT/include:{B}/include" \
  --libpaths="$SYSROOT/lib:{B}" \
  --crtprefix="$SYSROOT/lib" \
  --tcc-switches=-static
make

echo "built: $HERE/tcc  (+ $HERE/libtcc1.a)"
echo "try:   $HERE/tcc <file>.c -o <out>   # emits a static x86_64-dunit ELF"
