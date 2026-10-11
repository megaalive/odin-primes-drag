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

The current public Wheel-30 source is the **CI-selected B2 build**. Six paired confirmation blocks on a single GitHub runner showed a median **+16.19%** vs its original kernel, 6/6 wins; results remain CPU-dependent and are not an Intel/PrimeView result. The public dashboard displays the current B2 compiler and source SHA. The Local machine page intentionally retains historical **original, pre-B2** Wheel-30 measurements, pinned to commit `af227f9`. B2 has not yet been measured on the i9-12900H or Xeon W-1350P. Wheel-30 joins Base and Wheel-210 as a complementary Odin algorithm; all three pursue the same non-Odin competitors.

## Local machine — two CPU profiles

The [Local machine dashboard](https://megaalive.github.io/odin-primes-drag/local.html) offers two selectable profiles for Base E22, Wheel-30 and Wheel-210:

- **Intel Core i9-12900H**: Windows 11, 14 cores / 20 logical processors, six single-worker confirmation blocks and seven 20-worker shared-window blocks; data in [`local-i9-12900h.json`](local-i9-12900h.json).
- **Intel Xeon W-1350P**: Windows 11 Pro for Workstations, 6 cores / **12 usable logical processors**, six single-worker blocks and seven optional 12-worker shared-window blocks; data in [`local-xeon-w-1350p.json`](local-xeon-w-1350p.json). The 20-worker Xeon lane is **unavailable** and intentionally not synthesized.

Both used Odin `dev-2026-10-nightly:84bc3fc`, original kernels from the exact pinned [local-tested commit `af227f9`](https://github.com/megaalive/odin-primes-drag/commit/af227f9fbe9278ec02b16f0ddbc38febd432abab) and independent correctness checks. **The current public Wheel-30 B2 is newer than those local tests** and is not represented by their bars. Wheel-30's multithreaded local run uses the research harness; its official public CI executable remains single-thread. **Each machine's results are reported separately**; i9's 20-worker numbers and Xeon's 12-worker numbers are not a same-worker paired comparison. Private research notes and audits contain further details. No local result is an official PrimeView ranking.
