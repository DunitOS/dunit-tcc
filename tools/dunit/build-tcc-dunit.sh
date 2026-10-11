#!/bin/sh
# Build the ON-DEVICE Dunit tcc: compile tcc's own sources with dunit-cc into a
# native x86_64-dunit static ELF (the /system/bin/tcc that runs ON Dunit), as
# opposed to the host cross-tcc from build-tcc.sh.
#
# ONE_SOURCE: tcc.c #includes libtcc.c (all lib units + the x86_64 backend) and
# tcctools.c, so a single compile of tcc.c + a single link produce the whole
# compiler.
#
# The on-device tcc must look for headers/libs/crt on the DEVICE, not on the
# build host. config.h bakes those paths unconditionally (so -D can't override
# them), and it is shared with the host-cross build, so we temporarily swap in a
# /system-rooted config.h just for this compile and restore the host one after.
#
# Usage:  tools/dunit/build-tcc-dunit.sh <abs-path-to-dunit-sysroot> [out]
# Prerequisite: config.h must exist (run ./configure or build-tcc.sh first).
set -e

SYSROOT="${1:?usage: build-tcc-dunit.sh <abs-dunit-sysroot> [out]}"
DCC="$SYSROOT/bin/dunit-cc"
[ -x "$DCC" ] || { echo "no dunit-cc at $DCC" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$HERE"
[ -f config.h ] || { echo "no config.h — run ./configure or build-tcc.sh first" >&2; exit 1; }

OUT="${2:-$HERE/tcc-dunit}"

# On-device search paths. {B} expands to CONFIG_TCCDIR (= /system/tcc) at
# runtime, so {B}/include is /system/tcc/include and {B} is /system/tcc. crt is
# packaged into both /system/lib and /system/tcc.
restore() { [ -f config.h.hostbak ] && mv -f config.h.hostbak config.h; }
trap restore EXIT
cp config.h config.h.hostbak
sed -e 's|^#define CONFIG_TCC_SYSINCLUDEPATHS .*|#define CONFIG_TCC_SYSINCLUDEPATHS "/system/include:{B}/include"|' \
    -e 's|^#define CONFIG_TCC_LIBPATHS .*|#define CONFIG_TCC_LIBPATHS "/system/lib:{B}"|' \
    -e 's|^#define CONFIG_TCC_CRTPREFIX .*|#define CONFIG_TCC_CRTPREFIX "/system/lib:{B}"|' \
    config.h.hostbak > config.h

"$DCC" -I. -DCONFIG_TCCDIR='"/system/tcc"' -c tcc.c -o "$HERE/tcc-dunit.o"
"$DCC" "$HERE/tcc-dunit.o" -o "$OUT"

echo "built on-device Dunit tcc: $OUT  (/system paths baked)"
