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

**Base**, **Wheel-210**, and **Wheel-30** are independent Odin algorithm tracks with a common objective: outperform the fastest non-Odin entries in the [Prime Sieve Drag Race](https://github.com/PlummersSoftwareLLC/Primes). Their internal measurements do not establish a common category winner or a cross-CPU leaderboard. All three have separate CI and correctness checks.

**Base compiler compatibility:** The public Base source includes `#+feature using-stmt` in the two files that use the feature, matching Odin `dev-2026-10`. The public Base Dockerfile now verifies the checksum-pinned October compiler, keeping parity with the Wheel-210 toolchain. The experimental E22 kernel and sieve logic are unchanged; the private historical compiler pin and research baseline are independent.

**Local Intel i9-12900H Base report:** Seven 2026-10-11 measurements by Sol on Windows 11 with Odin `dev-2026-10-nightly:84bc3fc` are published in [`base-intel12900h.json`](base-intel12900h.json), including all packed-bit and byte-storage raw samples and test/provenance caveats. Base packed-bit medians were **9,721.83 passes/s single (1 worker)** and **38,288.42 passes/s parallel (20 workers)**. The original public source at `f3279ab5b930` failed to compile without the file-level feature directive; tests then passed 14/14 with only that compatibility edit. These are explicitly **developer-reported** local data, not independently reproduced CI figures, and they are not official rankings. The [Base Pages dashboard](https://megaalive.github.io/odin-primes-drag/) displays them in a separate section from GitHub runner results.

## Separate Base and Wheel-210 tracks

The [Base dashboard](https://megaalive.github.io/odin-primes-drag/) and [Wheel-210 dashboard](https://megaalive.github.io/odin-primes-drag/wheel.html) use separate benchmark jobs and compiler pins. Wheel-210 is built with Odin `dev-2026-10`; its implementation and tests are public. Both pages show actual GitHub Actions measurements with runner CPU metadata. The historical i9-12900H report is displayed separately as developer-provided evidence. Neither track claims an official PrimeView ranking, and Wheel-210's `faithful=yes` classification remains subject to upstream review.

## Wheel-210 files and validation

Wheel-210 lives in [`wheel210/`](wheel210/) alongside the Base implementation. Its [source](wheel210/main.odin), [oracle tests](wheel210/tests.odin), [Dockerfile](wheel210/Dockerfile), and [build notes](wheel210/README.md) are public. The GitHub Actions workflow separately builds, checks and benchmarks both algorithms, then publishes Pages only when both pass. The [Wheel dashboard](https://megaalive.github.io/odin-primes-drag/wheel.html) shows actual CI runner throughput, CPU metadata and compiler provenance. Historical laptop numbers remain explicitly developer-reported, not comparable to results from different CPUs or official PrimeView.


## Wheel-30 — third independent algorithm

Wheel-30 has its own [public dashboard](https://megaalive.github.io/odin-primes-drag/wheel30.html), [source](wheel30/main.odin), [Dockerfile](wheel30/Dockerfile), [build notes](wheel30/README.md), and checksum-pinned GitHub CI validation. It runs **one single-thread lane** with an independent prime-membership oracle at four limits before the five-second benchmark. The dashboard publishes only verified GitHub Actions measurements with recorded runner CPU, compiler provenance and source revision. No local cross-language measurements are published for Wheel-30. The run is CI screening, not an official PrimeView ranking, and proposed `faithful=yes` remains subject to upstream review.

Wheel-30 joins Base and Wheel-210 as a complementary Odin algorithm; all three pursue the same non-Odin competitors.
