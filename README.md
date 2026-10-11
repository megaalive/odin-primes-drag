# Odin Primes Drag Race

An Odin implementation of the Sieve of Eratosthenes for [Primes — A Software Drag Race](https://github.com/PlummersSoftwareLLC/Primes).

The code reports the competition protocol with `algorithm=base`, `faithful=yes`, and `bits=1` for the packed-bit implementation. Each timed pass calculates a new sieve. A byte-storage implementation is also included.

## Build and run

Linux/amd64 with Docker:

```sh
docker build --target build -t odin-primes:build .
docker run --rm odin-primes:build sh -lc 'odin test .'
docker build -t odin-primes .
docker run --rm odin-primes
```

The Docker build pins the Odin compiler source revision and uses native CPU optimizations. Run locally on the target machine for representative performance. Shared GitHub-hosted CI confirms builds and correctness, not official leaderboard position.

## CI results

[GitHub Pages dashboard](https://megaalive.github.io/odin-primes-drag/) displays each validated GitHub Actions benchmark lane alongside the recorded CPU model, logical CPU count, commit SHA and CI evidence. Values are CI screening data, not official PrimeView rankings or cross-hardware comparisons.

## Validation

The test suite checks known prime counts, independent reference comparisons, sieve boundaries, and traversal equivalence. The runtime verifies the known count for the competition limit of 1,000,000.

## Attribution

Based on the Odin prime-sieve community work credited to omgitsmoe, Ginger Bill, and Kelimion, and Dave Plummer's original base sieve. The competition and its implementations are maintained in [PlummersSoftwareLLC/Primes](https://github.com/PlummersSoftwareLLC/Primes). See [LICENSE](LICENSE).

## Complementary Odin strategies

**Base**, **Wheel-210**, and **Wheel-30** are separate Odin sieve implementations. Each has its own source, correctness checks and benchmark results. GitHub Actions records the runner CPU, compiler and source revision for every measured track.

**Base compiler compatibility:** The public Base source includes `#+feature using-stmt` in the two files that use the feature, matching Odin `dev-2026-10`. The public Base Dockerfile now verifies the checksum-pinned October compiler, keeping parity with the Wheel-210 toolchain. The experimental E22 kernel and sieve logic are unchanged; the private historical compiler pin and research baseline are independent.


## Separate Base and Wheel-210 tracks

The [Base dashboard](https://megaalive.github.io/odin-primes-drag/) and [Wheel-210 dashboard](https://megaalive.github.io/odin-primes-drag/wheel.html) use separate benchmark jobs and compiler pins. Wheel-210 is built with Odin `dev-2026-10`; its implementation and tests are public. Both pages show actual GitHub Actions measurements with runner CPU metadata. Local benchmark comparisons are available exclusively on the dedicated [Local machine](https://megaalive.github.io/odin-primes-drag/local.html) page. Neither track claims an official PrimeView ranking, and Wheel-210's `faithful=yes` classification remains subject to upstream review.

## Wheel-210 files and validation

Wheel-210 lives in [`wheel210/`](wheel210/) alongside the Base implementation. Its [source](wheel210/main.odin), [oracle tests](wheel210/tests.odin), [Dockerfile](wheel210/Dockerfile), and [build notes](wheel210/README.md) are public. The GitHub Actions workflow separately builds, checks and benchmarks both algorithms, then publishes Pages only when both pass. The [Wheel dashboard](https://megaalive.github.io/odin-primes-drag/wheel.html) shows actual CI runner throughput, CPU metadata and compiler provenance. The per-algorithm pages show CI results only; local measurements are collected on the Local machine page.


## Wheel-30 — third independent algorithm

Wheel-30 has its own [public dashboard](https://megaalive.github.io/odin-primes-drag/wheel30.html), [source](wheel30/main.odin), [Dockerfile](wheel30/Dockerfile), [build notes](wheel30/README.md), and checksum-pinned GitHub CI validation. It runs **one single-thread lane** with an independent prime-membership oracle at four limits before the five-second benchmark. The dashboard publishes only verified GitHub Actions measurements with recorded runner CPU, compiler provenance and source revision. No local cross-language measurements are published for Wheel-30. The run is CI screening, not an official PrimeView ranking, and proposed `faithful=yes` remains subject to upstream review.

Wheel-30 joins Base and Wheel-210 as a complementary Odin algorithm; all three pursue the same non-Odin competitors.

## Local machine — three-way i9-12900H comparison

The [local machine dashboard](https://megaalive.github.io/odin-primes-drag/local.html) compares **Base E22, Wheel-30 and Wheel-210** on one Intel Core i9-12900H under Odin dev-2026-10. Single-thread confirmation used 6 paired blocks; 20-thread shared-window testing used 7 blocks. Verified prime counts and raw per-block aggregate measurements are in [`local-i9-12900h.json`](local-i9-12900h.json). Full CSV, report, audit and the research multi-thread runner are in the private lab. This is not GitHub Actions or PrimeView; the original Wheel-30 public competition executable remains single-thread.
