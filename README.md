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

## Separate Base and Wheel-210 tracks

The [Base dashboard](https://megaalive.github.io/odin-primes-drag/) and [Wheel-210 dashboard](https://megaalive.github.io/odin-primes-drag/wheel.html) use separate benchmark jobs and compiler pins. Wheel-210 is built with Odin `dev-2026-10`; its implementation and tests are public. Both pages show actual GitHub Actions measurements with runner CPU metadata. The historical i9-12900H report is displayed separately as developer-provided evidence. Neither track claims an official PrimeView ranking, and Wheel-210's `faithful=yes` classification remains subject to upstream review.

## Wheel-210 files and validation

Wheel-210 lives in [`wheel210/`](wheel210/) alongside the Base implementation. Its [source](wheel210/main.odin), [oracle tests](wheel210/tests.odin), [Dockerfile](wheel210/Dockerfile), and [build notes](wheel210/README.md) are public. The GitHub Actions workflow separately builds, checks and benchmarks both algorithms, then publishes Pages only when both pass. The [Wheel dashboard](https://megaalive.github.io/odin-primes-drag/wheel.html) shows actual CI runner throughput, CPU metadata and compiler provenance. Historical laptop numbers remain explicitly developer-reported, not comparable to results from different CPUs or official PrimeView.
