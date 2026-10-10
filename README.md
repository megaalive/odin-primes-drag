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

## Validation

The test suite checks known prime counts, independent reference comparisons, sieve boundaries, and traversal equivalence. The runtime verifies the known count for the competition limit of 1,000,000.

## Attribution

Based on the Odin prime-sieve community work credited to omgitsmoe, Ginger Bill, and Kelimion, and Dave Plummer's original base sieve. The competition and its implementations are maintained in [PlummersSoftwareLLC/Primes](https://github.com/PlummersSoftwareLLC/Primes). See [LICENSE](LICENSE).
