package main

import "core:testing"
import "core:math"

reference_prime :: proc(n: int) -> bool {
    if n < 2 { return false }
    for d := 2; d*d <= n; d += 1 {
        if n % d == 0 { return false }
    }
    return true
}

@test
wheel210_small_limits_and_residue_boundaries :: proc(t: ^testing.T) {
    init_tables()
    for limit := 0; limit <= 2_048; limit += 1 {
        pk := run_packed(limit)
        for n := 0; n <= limit + 2; n += 1 {
            testing.expect(t, is_prime(&pk, n) == (n <= limit && reference_prime(n)))
        }
        delete(pk.words)
    }
}

@test
wheel210_dense_cutoff_and_prime_square_boundaries :: proc(t: ^testing.T) {
    init_tables()
    limits := [?]int{
        10_000, 12_542, 12_543, 12_544, 12_545,
        12_766, 12_767, 12_768, 12_769, 12_770,
        16_900, 17_161, 100_000,
    }
    for limit in limits {
        pk := run_packed(limit)
        for n := 2; n <= limit; n += 1 {
            testing.expect(t, is_prime(&pk, n) == reference_prime(n))
        }
        delete(pk.words)
    }
}

@test
wheel210_full_bitset_independent_oracle :: proc(t: ^testing.T) {
    init_tables()
    limit := 1_000_000
    pk := run_packed(limit)
    defer delete(pk.words)
    composite := make([]bool, limit+1)
    defer delete(composite)
    for p := 2; p*p <= limit; p += 1 {
        if composite[p] { continue }
        for k := p*p; k <= limit; k += p {
            composite[k] = true
        }
    }
    count := 0
    for n := 2; n <= limit; n += 1 {
        prime := !composite[n]
        testing.expect(t, is_prime(&pk, n) == prime)
        if prime { count += 1 }
    }
    testing.expect(t, count == 78_498)
    testing.expect(t, prime_count(&pk) == count)
}

@test
wheel210_large_range_reference_counts :: proc(t: ^testing.T) {
    init_tables()
    limits := [?]int{1_000_000, 10_000_000}
    expected := [?]int{78_498, 664_579}
    for limit, i in limits {
        pk := run_packed(limit)
        testing.expect(t, prime_count(&pk) == expected[i])
        delete(pk.words)
    }
}
