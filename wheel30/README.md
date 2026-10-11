# Odin Wheel-30 — B2 (CI-selected)

The public release in `main.odin` is **Wheel-30 B2**, selected from same-runner GitHub Actions correctness and paired throughput evidence on 11 October 2026. It retains the same competition output protocol (`odin_wheel30`, `algorithm=wheel,faithful=yes,bits=1`), freshly allocated sieve per pass, and dynamic prime discovery. `faithful=yes` is proposed, subject to upstream review.

## What was actually measured?

| Dataset | Kernel | Where | Meaning |
| --- | --- | --- | --- |
| [Wheel-30 CI dashboard](../wheel30.html) | **B2, current public source** | GitHub Actions | Independent four-limit oracle and current 5-second single-thread throughput, with runner/commit/source provenance |
| [Local machine dashboard](../local.html) | **Original Wheel-30, pre-B2** | Intel Core i9-12900H / Xeon W-1350P | 11 October 2026 pinned original kernel, tested at [commit `af227f9`](https://github.com/megaalive/odin-primes-drag/commit/af227f9fbe9278ec02b16f0ddbc38febd432abab) |
| B2 research selection | B2 compared directly against the original | GitHub-hosted CI, single same-runner job | Six paired confirmation blocks showed median +16.19% for B2 in that session; not an official or cross-host claim |

**No B2 local Intel results exist yet.** Do not assign original local results to B2. The original source remains accessible at [the historical pinned commit](https://github.com/megaalive/odin-primes-drag/blob/af227f9fbe9278ec02b16f0ddbc38febd432abab/wheel30/main.odin); its SHA-256 is `75cfe0048f6300d6cf740ce1f6576ea9d38dc4e26965b27d17b90fb7df397d34`.

## Reproducible public build

```sh
docker build --target build -t wheel30:build wheel30
docker build -t wheel30:runtime wheel30
docker run --rm wheel30:runtime
docker run --rm wheel30:build sh -lc 'odin build main.odin -file -o:speed -microarch:native -no-bounds-check -define:CHECK=true -define:LIMIT=1000000 -define:RUN_SECONDS=0 -out:check-primes && ./check-primes'
```

GitHub CI uses checksum-pinned Odin `dev-2026-10-nightly:84bc3fc`, checks prime membership at 100, 10,000, 1,000,000 and 10,000,000, and publishes only actual five-second GitHub-runner measurements. The page displays the exact source revision, SHA-256, build label, compiler and runner CPU. It does not claim universal superiority or an official PrimeView ranking.
