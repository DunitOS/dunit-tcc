# Upstream provenance

This repository (`DunitOS/dunit-tcc`) is **Dunit OS's fork of TinyCC (tcc)**,
being ported onto Dunit's own native syscall ABI and its ported musl libc — so
that C source can be compiled **on the device**, by a compiler that itself runs
on Dunit. It is NOT a Linux-compatibility layer; the goal is source portability
against Dunit's ABI (the same philosophy as `DunitOS/dunit-musl`).

## Source

- Project: **TinyCC (tcc)** — a small, self-contained C compiler with a built-in
  assembler and linker, so it compiles + assembles + links in a single process
  (no external `as`/`ld`, no `fork`/`exec`/pipes for a build).
- Canonical upstream: `https://repo.or.cz/tinycc.git` (development branch `mob`).
- Fork base taken from the GitHub mirror `https://github.com/TinyCC/tinycc`
  (`mob`), tracked here as the `upstream` remote.

## Pinned base

- Commit: `43c7708b85681a2fd4451c8a541af4494a8919b2`
- Date: 2026-10-03
- Subject: `tccelf: Fix static linking with musl`
- `VERSION`: `0.9.28rc`

The fork's `master` branch starts exactly at this upstream commit (pristine), and
every Dunit change lands as a commit on top. Upstream bug/security fixes are
pulled by rebasing/cherry-picking from the `upstream` remote.

## License

TinyCC is **LGPL-2.1** (see `COPYING`; `RELICENSING` lists contributor relicensing
consent). Dunit's changes keep the same license. No upstream files are deleted —
unported pieces are disabled in the build profile, not removed (same rule as the
musl fork), so upstream merges stay clean.

## Why a real fork (not vendored files)

A long-lived, OS-specific port is only maintainable as a git fork that can track
and rebase upstream. The Dunit delta is kept small and documented (see
`PORTING.md` and, once generated, `DELTA.md`) rather than smeared across the tree.
