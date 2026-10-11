# Odin Wheel-30

This is the byte-identical user-submitted `main.odin` (SHA256 `75cfe0048f6300d6cf740ce1f6576ea9d38dc4e26965b27d17b90fb7df397d34`). An immutable copy exists in the private research archive.

Wheel-30 packs eight residues per byte, uses periodic patterns for 7/11/13, 32-byte SIMD for smaller factors, and specialized marking for larger factors. Each single-thread pass allocates a new sieve and discovers primes dynamically. Classification `algorithm=wheel,faithful=yes,bits=1` is proposed and subject to upstream review.

## Reproducible build

```sh
docker build --target build -t wheel30:build wheel30
docker build -t wheel30:runtime wheel30
docker run --rm wheel30:runtime
docker run --rm wheel30:build sh -lc 'odin build main.odin -file -o:speed -microarch:native -no-bounds-check -define:CHECK=true -define:LIMIT=1000000 -define:RUN_SECONDS=0 -out:check-primes && ./check-primes'
```

The Odin dev-2026-10 compiler archive is checksum-pinned. GitHub Actions performs independent oracle tests at 100, 10000, 1000000, and 10000000, and a five-second single-thread benchmark. There is no multithreaded Wheel-30 lane.

Developer-reported Intel Xeon comparisons are stored separately in [wheel30-reported.json](../wheel30-reported.json). Rust #1092 used a non-matching compiler; Zig #1090/#1094 was not tested. These numbers are not an official PrimeView ranking.
