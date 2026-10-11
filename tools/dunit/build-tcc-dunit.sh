#!/bin/sh
# Build the ON-DEVICE Dunit tcc: compile tcc's own sources with dunit-cc into a
# native x86_64-dunit static ELF (the future /system/bin/tcc). This is the
# compiler that runs ON Dunit, as opposed to the host cross-tcc from
# build-tcc.sh.
#
# ONE_SOURCE build model: tcc.c (the frontend) #includes libtcc.c, which
# #includes every lib unit AND the x86_64 backend, and tcc.c also #includes
# tcctools.c. So a single compile of tcc.c + a single link produces the whole
# compiler — no libtcc.a, no separate backend objects.
#
# Usage:  tools/dunit/build-tcc-dunit.sh <abs-path-to-dunit-sysroot> [out]
#
# Prerequisite: config.h must exist with the x86_64 target defines — run
# ./configure (or tools/dunit/build-tcc.sh <sysroot>) first. CONFIG_TCCDIR is
# overridden here to the on-device path (/system/tcc, where libtcc1.a + tcc's
# own include/ are packaged). The sysinclude/lib/crt paths baked from config.h
# still point at the host sysroot; packaging the on-device sysroot and baking
# /system paths into those is the next phase (P3b in PORTING.md).
set -e

SYSROOT="${1:?usage: build-tcc-dunit.sh <abs-dunit-sysroot> [out]}"
DCC="$SYSROOT/bin/dunit-cc"
[ -x "$DCC" ] || { echo "no dunit-cc at $DCC" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$HERE"
[ -f config.h ] || { echo "no config.h — run ./configure or build-tcc.sh first" >&2; exit 1; }

OUT="${2:-$HERE/tcc-dunit}"
"$DCC" -I. -DCONFIG_TCCDIR='"/system/tcc"' -c tcc.c -o "$HERE/tcc-dunit.o"
"$DCC" "$HERE/tcc-dunit.o" -o "$OUT"

echo "built on-device Dunit tcc: $OUT"
echo "(a static x86_64-dunit ELF; ships as /system/bin/tcc)"
