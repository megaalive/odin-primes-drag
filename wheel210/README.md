# Odin Wheel-210

This directory contains the **public Wheel-210 Sieve of Eratosthenes** for the Odin Primes Drag Race. It is independent of the [Base source](../src/main.odin). The code allocates a fresh packed candidate buffer on each timed pass, using one bit per wheel candidate. It prepares wheel masks and factor strike-starts before timing; every timed pass produces a complete sieve. The program outputs `algorithm=wheel,faithful=yes,bits=1` (classification pending upstream maintainer review).

## Build and run

From this directory:

```sh
docker build --target build -t odin-wheel210:build .
docker run --rm odin-wheel210:build sh -lc 'odin test . -define:ODIN_TEST_THREADS=1'
docker build -t odin-wheel210 .
docker run --rm odin-wheel210
```

The [Dockerfile](Dockerfile) pins the official Odin `dev-2026-10` Linux/amd64 archive and validates its SHA-256 before building using `-o:speed -no-bounds-check -microarch:native`. The source rejects limits exceeding 100,000,000, as its prime table reaches 10,000. At 1,000,000 the packed buffer is 38,096 bytes; fitting L1 cache depends on CPU core architecture.

The independent tests inspect all primality results through 1,000,000 against an independent oracle, test small and prime-square boundaries, and validate known prime counts through 10,000,000. Tests are serialized because their global one-time initialization must run before worker use.

## Public CI and evidence

The repository's [workflow](../.github/workflows/verify.yml) builds and tests Wheel-210 separately from Base, captures a five-second single and parallel benchmark, validates official-form output and publishes runner CPU, compiler version, source revision and run link at [Wheel-210 GitHub Pages](https://megaalive.github.io/odin-primes-drag/wheel.html). Reported laptop runs are displayed separately from CI.

This is reproducible screening evidence, **not** an official PrimeView ranking or a CPU-matched competitor victory. The code uses the repository's [BSD 3-Clause License](../LICENSE), and its proposed `faithful=yes` output classification remains subject to maintainer review. No upstream PR is opened by this change.
