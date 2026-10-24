# Porting TinyCC to Dunit OS

Goal: an **on-device C compiler**. `tcc hello.c -o hello` runs *on Dunit*,
producing a native Dunit static ELF, which `posix_spawn` then runs. This is the
M6 capstone — the on-device counterpart of the off-device `dunit-cc` cross
driver (which wraps the host gcc). tcc is chosen because its built-in assembler
and linker make a whole build a **single process**: no `as`/`ld`, no
`fork`/`exec`/pipes.

See `UPSTREAM.md` for provenance and the fork/branch model.

## ABI contract

tcc is built *for* and runs *on* `x86_64-dunit`, against the ported musl
(`DunitOS/dunit-musl`): Dunit's native syscalls (not Linux numbers), Dunit's
process-entry ABI, static-only ELF `ET_EXEC` at `0x400000` with entry `_start`.
Both tcc itself and the binaries tcc emits follow this contract and link against
the same `libc.a` + `crt1.o/crti.o/crtn.o` from the Dunit sysroot.

## Kernel/libc prerequisites

Status against the Dunit kernel + musl port (dunit-os):

- **Done:** `open/read/write/close`, `lseek` (Seek=80), `stat`/`fstat`
  (Fstat=81), `ftruncate` (Truncate=84), `access` (Stat-based), `O_EXCL` +
  `mkstemp`, `getcwd`/`chdir`, directories + `rewinddir`, `unlink`/`mkdir`,
  `malloc` family, `posix_spawn`/`wait` (to run the output).
- **Not required for file-output compile:** pipes/redirection, sockets, signals,
  dynamic linking.
- **Deferred:** `tcc -run` is a separate policy decision. Existing Dunit
  `mprotect` (syscall 35) already permits RW→RX and forbids simultaneous W+X;
  a new executable-memory syscall is not inherently required. Upstream's
  default x86_64 run-memory policy requests RWX, which is incompatible, but
  its `CONFIG_RUNMEM_RO=2` path separates RX/RO/RW pages after relocation.
  That path still needs an isolated, page-owned allocation/lifetime audit,
  static symbol resolution and runtime-support packaging before it can be
  claimed to work. No JIT policy is selected by the file-output port.

## Executable stack descriptor

The ELF writer reserves and emits `PT_GNU_STACK` with `PF_R | PF_W`, alignment
16, and zero file/memory size for executable output. It explicitly records
the NX-stack contract already enforced by the Dunit loader. This standard
ELF metadata does not change Dunit ABI, create a mapping or affect object
output. Emitted binaries must pass dunit-os's static ELF gate after rebuilding
the compiler; the fork does not interpret a missing header as permission to
execute the stack.

## Build model

tcc is built with `dunit-cc` (the host gcc as cross-compiler + the Dunit
sysroot) into a static Dunit ELF, packed into the OS image. Its configure/make
is driven to:

- target `x86_64`, ELF, **static only** (no PE/macho/DSO backends);
- bake the on-device sysroot paths as defaults (`CONFIG_TCCDIR`, sysinclude and
  library paths) so `tcc hello.c` finds headers + `libc.a` + crt objects without
  flags;
- disable `-run`/bcheck/backtrace paths that need runtime codegen for now.

## On-device sysroot

tcc, at compile time, reads headers and libraries from disk. The OS image ships:

```
/system/tcc/            CONFIG_TCCDIR — tcc's own runtime files (libtcc1.a, include/)
/system/include/        musl public headers + dunit/*.h
/system/lib/            libc.a, crt1.o, crti.o, crtn.o   (from DunitOS/dunit-musl)
/system/bin/tcc         the compiler itself (static Dunit ELF)
```

`/system` is read-mostly per Dunit's path policy. Packaging is done by the
dunit-os image tooling from the already-built `build/dunit-sysroot`.

## Phases

- **P0 — fork scaffolding (this stage):** pristine upstream base + `UPSTREAM.md`
  + `PORTING.md`; wire into dunit-os as the `toolchains/dunit-tcc` submodule
  later.
- **P1 — build tcc for Dunit:** configure/Makefile delta so `dunit-cc` builds a
  static `x86_64-dunit` tcc; thematic `build:` commits. Produce `libtcc1.a`.
- **P2 — default paths + runtime syscalls:** point tcc's default include/lib/
  tccdir at the on-device sysroot; confirm the handful of libc calls tcc makes
  at runtime are all satisfied (all listed above are done).
- **P3 — on-device compile:** `tcc -c` and `tcc -o a.out hello.c` on Dunit;
  verify the emitted ELF matches the Dunit ELF contract.
- **P4 — end-to-end:** `posix_spawn` the emitted binary; marker
  `[TCC] compiled+ran OK`.
- **P5 (deferred):** `tcc -run` (JIT) — needs a W^X decision.

## Delta discipline (same as the musl fork)

- No upstream file is deleted; unported backends are disabled in the build
  profile. Dunit code lives in small, named units; `#ifdef`s are not smeared
  across the tree.
- Thematic commits (`build:`, `syscall:`, `paths:`, `elf:`, `docs:`); a `DELTA.md`
  table (generated) tracks the divergence from the pinned upstream base.
- **M6.1 rule:** an unsupported path returns a documented error, never a silent
  fake success.
- Everything is built and verified through dunit-os's `tools/qemu_test.py`
  marker harness — a green `cargo`/`make` is not proof; observed on-device
  behavior is.

## Risks

- tcc's own include/library **path probing** (needs `access()` — done) and temp
  files (`mkstemp` — done).
- **Memory footprint:** tcc is malloc-heavy on large translation units; the user
  heap / mmap budget may need raising. To be measured on real inputs.
- **ELF/linker correctness:** tcc's built-in linker must emit exactly the Dunit
  static ELF layout (entry, PT_LOAD perms incl. NX stack, no PT_INTERP).
- `setjmp`/`longjmp` and other libc corners tcc leans on must exist in the port
  (upstream musl provides them; verify under Dunit).
