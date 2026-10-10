#+feature using-stmt
package main

import "core:testing"
import "core:math"

reference_prime :: proc(n: u64) -> bool {
    if n < 2 { return false }
    for d := u64(2); d*d <= n; d += 1 {
        if n % d == 0 { return false }
    }
    return true
}

@test
test_small_even_limits :: proc(t: ^testing.T) {
    for limit := u64(4); limit <= 2_048; limit += 2 {
        bit := run_sieve_bit(limit)
        byte := run_sieve_byte(limit)
        want := u64(1)
        for n := u64(3); n < limit; n += 2 {
            is_prime := reference_prime(n)
            if is_prime { want += 1 }
            testing.expect(t, !get_bit(&bit, n/2) == is_prime)
            testing.expect(t, !byte.bits[n/2] == is_prime)
        }
        testing.expect(t, count_primes_bit(&bit) == want)
        testing.expect(t, count_primes_byte(&byte) == want)
        free((^rawptr)(&bit.bits)^, context.allocator)
        free((^rawptr)(&byte.bits)^, context.allocator)
    }
}

@test
test_official_limit :: proc(t: ^testing.T) {
    bit := run_sieve_bit(1_000_000)
    byte := run_sieve_byte(1_000_000)
    testing.expect(t, count_primes_bit(&bit) == 78_498)
    testing.expect(t, count_primes_byte(&byte) == 78_498)
    free((^rawptr)(&bit.bits)^, context.allocator)
    free((^rawptr)(&byte.bits)^, context.allocator)
}

@test
test_dense_forward_reverse_equivalence :: proc(t: ^testing.T) {
    factors := [?]u64{5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61}
    for words in 1..=130 {
        for factor in factors {
            if (factor*factor)/2 >= u64(words)*64 { continue }
            forward := BitSieve{upper = u64(words)*128, bits = make([]SIEVE_BACKING, words)}
            reverse := BitSieve{upper = u64(words)*128, bits = make([]SIEVE_BACKING, words)}
            mark_dense_factor(&forward, factor, false)
            mark_dense_factor(&reverse, factor, true)
            for i in 0..<words {
                testing.expect(t, forward.bits[i] == reverse.bits[i])
            }
            free((^rawptr)(&forward.bits)^, context.allocator)
            free((^rawptr)(&reverse.bits)^, context.allocator)
        }
    }
}

@test
test_sparse_forward_reverse_equivalence :: proc(t: ^testing.T) {
    limits := [?]u64{4_489, 4_490, 8_192, 65_536, 1_000_000}
    factors := [?]u64{67, 71, 79, 97, 127, 131, 137, 139, 149, 157, 163, 167, 173, 179, 181, 191, 251, 499, 997}
    for limit in limits {
        for factor in factors {
            words := int((limit/2 + 63)/64)
            forward := BitSieve{upper = limit, bits = make([]SIEVE_BACKING, words)}
            reverse := BitSieve{upper = limit, bits = make([]SIEVE_BACKING, words)}
            mark_sparse_factor(&forward, factor, false)
            mark_sparse_factor(&reverse, factor, true)
            for i in 0..<words {
                testing.expect(t, forward.bits[i] == reverse.bits[i])
            }
            free((^rawptr)(&forward.bits)^, context.allocator)
            free((^rawptr)(&reverse.bits)^, context.allocator)
        }
    }
}

@test
test_high_end_membership :: proc(t: ^testing.T) {
    sieve := run_sieve_bit(1_000_000)
    for n := u64(995_001); n < 1_000_000; n += 2 {
        testing.expect(t, !get_bit(&sieve, n/2) == reference_prime(n))
    }
    free((^rawptr)(&sieve.bits)^, context.allocator)
}


@test
test_sparse_eight_way_matches_scalar_and_canaries :: proc(t: ^testing.T) {
    factors := [?]u64{67, 71, 73, 79, 97, 127, 131, 137, 139, 149, 157, 163, 167, 173, 179, 181, 191, 251, 499, 997}
    for factor in factors {
        first := factor * factor / 2;
        for n := u64(0); n <= 73; n += 1 {
            for odd := u64(0); odd < 2; odd += 1 {
                upper := 2 * (first + n * factor) + odd;
                words := int(((upper / 2) + 63) / 64);
                reference_storage := make([]SIEVE_BACKING, words + 2);
                proposed_storage := make([]SIEVE_BACKING, words + 2);
                reference_storage[0] = 0xdeadbeefcafebabe;
                reference_storage[words + 1] = 0x0123456789abcdef;
                proposed_storage[0] = 0xdeadbeefcafebabe;
                proposed_storage[words + 1] = 0x0123456789abcdef;
                for direction in 0..<2 {
                    backwards := direction == 1;
                    for i in 1..=words {
                        reference_storage[i] = 0;
                        proposed_storage[i] = 0;
                    }
                    reference := BitSieve{upper = upper, bits = reference_storage[1:words+1]};
                    proposed := BitSieve{upper = upper, bits = proposed_storage[1:words+1]};
                    mark_sparse_factor_scalar_ref(&reference, factor, backwards);
                    mark_sparse_factor(&proposed, factor, backwards);
                    testing.expect(t, proposed_storage[0] == 0xdeadbeefcafebabe);
                    testing.expect(t, proposed_storage[words+1] == 0x0123456789abcdef);
                    for i in 0..<words {
                        testing.expect(t, proposed.bits[i] == reference.bits[i]);
                    }
                }
                free((^rawptr)(&reference_storage)^, context.allocator);
                free((^rawptr)(&proposed_storage)^, context.allocator);
            }
        }
    }
}

@test
test_reverse_alignment_preserves_prefill_and_canaries :: proc(t: ^testing.T) {
    factors := [?]u64{131, 137, 139, 149, 157, 163, 167, 173, 179, 181, 191, 251, 499, 997};
    hit_counts := [?]u64{16, 17, 23, 24, 25, 31, 32, 33, 63, 64, 65, 127, 128, 129};
    for factor in factors {
        first := factor * factor / 2;
        for n in hit_counts {
            upper := 2 * (first + n * factor);
            words := int(((upper / 2) + 63) / 64);
            scalar_storage := make([]u64, words + 2);
            trial_storage := make([]u64, words + 2);
            scalar_storage[0] = 0x1122334455667788;
            trial_storage[0] = 0x1122334455667788;
            scalar_storage[words + 1] = 0x8877665544332211;
            trial_storage[words + 1] = 0x8877665544332211;
            for i in 1..=words {
                seed := u64(i) * 0x9e3779b97f4a7c15;
                scalar_storage[i] = seed;
                trial_storage[i] = seed;
            }
            reference := BitSieve{upper = upper, bits = scalar_storage[1:words+1]};
            candidate := BitSieve{upper = upper, bits = trial_storage[1:words+1]};
            mark_sparse_factor_scalar_ref(&reference, factor, true);
            mark_sparse_factor(&candidate, factor, true);
            testing.expect(t, trial_storage[0] == 0x1122334455667788);
            testing.expect(t, trial_storage[words+1] == 0x8877665544332211);
            for i in 0..<words {
                testing.expect(t, reference.bits[i] == candidate.bits[i]);
            }
            free((^rawptr)(&scalar_storage)^, context.allocator);
            free((^rawptr)(&trial_storage)^, context.allocator);
        }
    }
}

@test
test_full_sieve_matches_scalar_sparse :: proc(t: ^testing.T) {
    limit := u64(1_000_000);
    actual := run_sieve_bit(limit);
    expected_bitset := BitSieve{upper = limit};
    make_bits(&expected_bitset, limit);
    q := u64(math.sqrt(f64(limit)));
    backwards := true;
    for factor := u64(3); factor <= q; factor += 2 {
        if get_bit(&expected_bitset, factor/2) {
            continue;
        }
        if factor == 3 {
            mark_factor_three(&expected_bitset);
        } else if factor < 64 {
            mark_dense_factor_scalar_ref(&expected_bitset, factor, backwards);
            backwards = !backwards;
        } else {
            mark_sparse_factor_scalar_ref(&expected_bitset, factor, backwards);
            backwards = !backwards;
        }
    }
    testing.expect(t, count_primes_bit(&actual) == 78_498);
    testing.expect(t, count_primes_bit(&expected_bitset) == 78_498);
    for i in 0..<len(actual.bits) {
        testing.expect(t, actual.bits[i] == expected_bitset.bits[i]);
    }
    free((^rawptr)(&actual.bits)^, context.allocator);
    free((^rawptr)(&expected_bitset.bits)^, context.allocator);
}


@test
test_dense_four_lane_matches_scalar :: proc(t: ^testing.T) {
    factors := [?]u64{5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61};
    for words in 1..=132 {
        for factor in factors {
            if (factor * factor) / 2 >= u64(words) * 64 {
                continue;
            }
            old_data := make([]SIEVE_BACKING, words + 2);
            new_data := make([]SIEVE_BACKING, words + 2);
            for direction in 0..<2 {
                backwards := direction == 1;
                old_data[0], old_data[words+1] = 0xcafebabedeadbeef, 0x0123456789abcdef;
                new_data[0], new_data[words+1] = 0xcafebabedeadbeef, 0x0123456789abcdef;
                for i in 1..=words {
                    seed := SIEVE_BACKING(i) * 0x9e3779b97f4a7c15;
                    old_data[i] = seed;
                    new_data[i] = seed;
                }
                baseline := BitSieve{upper = u64(words) * 128, bits = old_data[1:words+1]};
                candidate := BitSieve{upper = u64(words) * 128, bits = new_data[1:words+1]};
                mark_dense_factor_scalar_ref(&baseline, factor, backwards);
                mark_dense_factor(&candidate, factor, backwards);
                testing.expect(t, new_data[0] == 0xcafebabedeadbeef);
                testing.expect(t, new_data[words+1] == 0x0123456789abcdef);
                for i in 0..<words {
                    testing.expect(t, baseline.bits[i] == candidate.bits[i]);
                }
            }
            free((^rawptr)(&old_data)^, context.allocator);
            free((^rawptr)(&new_data)^, context.allocator);
        }
    }
}

mark_dense_factor_scalar_ref :: proc(using sieve: ^BitSieve, factor: u64, backwards: bool) #no_bounds_check {
    masks: [64]SIEVE_BACKING;
    for phase := u64(0); phase < factor; phase += 1 {
        mask := SIEVE_BACKING(0);
        for bit := phase; bit < 64; bit += factor {
            mask |= SIEVE_BACKING(1) << bit;
        }
        masks[phase] = mask;
    }

    first_index := (factor * factor) / 2;
    word := first_index / 64;
    bit := first_index & 63;
    first_mask := SIEVE_BACKING(0);
    for bit < 64 {
        first_mask |= SIEVE_BACKING(1) << bit;
        bit += factor;
    }
    bits[word] |= first_mask;
    word += 1;

    next_phase := bit - 64;
    remainder := u64(64) % factor;
    cycle: [64]SIEVE_BACKING;
    for i := u64(0); i < factor; i += 1 {
        cycle[i] = masks[next_phase];
        if next_phase >= remainder {
            next_phase -= remainder;
        } else {
            next_phase += factor - remainder;
        }
    }

    words := u64(len(bits));
    if backwards {
        first_full_word := word;
        full_end := first_full_word + ((words - first_full_word) / factor) * factor;

        tail := words;
        for tail > full_end {
            tail -= 1;
            bits[tail] |= cycle[tail - full_end];
        }

        end := full_end;
        for end > first_full_word {
            begin := end - factor;
            for offset := factor; offset > 0; offset -= 1 {
                bits[begin + offset - 1] |= cycle[offset - 1];
            }
            end = begin;
        }
        return;
    }

    for word + factor <= words {
        for offset := u64(0); offset < factor; offset += 1 {
            bits[word + offset] |= cycle[offset];
        }
        word += factor;
    }

    offset := u64(0);
    for word < words {
        bits[word] |= cycle[offset];
        word += 1;
        offset += 1;
    }
}


mark_sparse_factor_scalar_ref :: proc(using sieve: ^BitSieve, factor: u64, backwards: bool) #no_bounds_check {
    first := (factor * factor) / 2;
    limit := upper / 2;
    if first >= limit {
        return;
    }

    if backwards {
        last := first + ((limit - 1 - first) / factor) * factor;
        index := last;
        for index > first {
            set_bit(sieve, index, 1);
            index -= factor;
        }
        set_bit(sieve, first, 1);
        return;
    }

    for index := first; index < limit; index += factor {
        set_bit(sieve, index, 1);
    }
}


@test
test_specialized_dense_vs_selected :: proc(t: ^testing.T) {
    factors := [?]u64{5, 7, 11, 13};
    for factor in factors {
        for words in 1..=160 {
            if (factor * factor) / 2 >= u64(words) * 64 {
                continue;
            }
            old_data := make([]u64, words+2);
            new_data := make([]u64, words+2);
            for direction in 0..<2 {
                backwards := direction == 1;
                old_data[0], old_data[words+1] = 0xdebacecacafeface, 0x1020304050607080;
                new_data[0], new_data[words+1] = 0xdebacecacafeface, 0x1020304050607080;
                for i in 1..=words {
                    seed := u64(i)*0x9e3779b97f4a7c15;
                    old_data[i] = seed;
                    new_data[i] = seed;
                }
                baseline := BitSieve{upper=u64(words)*128, bits=old_data[1:words+1]};
                candidate := BitSieve{upper=u64(words)*128, bits=new_data[1:words+1]};
                mark_dense_factor(&baseline, factor, backwards);
                switch factor {
                case 5: mark_dense_specialized(5, &candidate, backwards);
                case 7: mark_dense_specialized(7, &candidate, backwards);
                case 11: mark_dense_specialized(11, &candidate, backwards);
                case 13: mark_dense_specialized(13, &candidate, backwards);
                }
                testing.expect(t, new_data[0] == 0xdebacecacafeface);
                testing.expect(t, new_data[words+1] == 0x1020304050607080);
                for i in 0..<words {
                    testing.expect(t, candidate.bits[i] == baseline.bits[i]);
                }
            }
            free((^rawptr)(&old_data)^, context.allocator);
            free((^rawptr)(&new_data)^, context.allocator);
        }
    }
}


@test
test_word_factor_search_equivalence :: proc(t: ^testing.T) {
    for words in 1..=4 {
        storage := make([]u64, words + 2);
        storage[0] = 0x0ddc0ffeec0ffeec;
        storage[words+1] = 0x1234567890abcdef;
        for kind in 0..<4 {
            for i in 1..=words {
                switch kind {
                case 0: storage[i] = 0;
                case 1: storage[i] = ~u64(0);
                case 2: storage[i] = u64(i) * 0x9e3779b97f4a7c15;
                case 3: storage[i] = ~u64(0) ~ (u64(1) << ((u64(i)*29) & 63));
                }
            }
            sieve := BitSieve{upper=u64(words)*128, bits=storage[1:words+1]};
            for last := u64(0); last < u64(words)*64; last += 1 {
                for first := u64(0); first <= last+1; first += 1 {
                    expected_index := last + 1;
                    for i := first; i <= last; i += 1 {
                        if !get_bit(&sieve, i) {
                            expected_index = i;
                            break;
                        }
                    }
                    actual := find_next_factor_bit(&sieve, first, last);
                    testing.expect(t, actual == expected_index);
                }
            }
        }
        testing.expect(t, storage[0] == 0x0ddc0ffeec0ffeec);
        testing.expect(t, storage[words+1] == 0x1234567890abcdef);
        free((^rawptr)(&storage)^, context.allocator);
    }
}


@test
test_dense_128_matches_sparse :: proc(t: ^testing.T) {
    factors := [?]u64{67,71,73,79,83,89,97,101,103,107,109,113,127};
    for factor in factors {
        for words in 1..=230 {
            if factor*factor/2 >= u64(words)*64 {
                continue;
            }
            reference_store := make([]u64, words+2);
            candidate_store := make([]u64, words+2);
            for direction in 0..<2 {
                backwards := direction == 1;
                reference_store[0], reference_store[words+1] = 0xf00dfade1234abcd, 0x0123456789abcdef;
                candidate_store[0], candidate_store[words+1] = 0xf00dfade1234abcd, 0x0123456789abcdef;
                for i in 1..=words {
                    seed := u64(i) * 0x9e3779b97f4a7c15;
                    reference_store[i] = seed;
                    candidate_store[i] = seed;
                }
                reference := BitSieve{upper=u64(words)*128, bits=reference_store[1:words+1]};
                candidate := BitSieve{upper=u64(words)*128, bits=candidate_store[1:words+1]};
                mark_sparse_factor(&reference, factor, backwards);
                mark_dense_factor(&candidate, factor, backwards);
                testing.expect(t, candidate_store[0] == 0xf00dfade1234abcd);
                testing.expect(t, candidate_store[words+1] == 0x0123456789abcdef);
                for i in 0..<words {
                    testing.expect(t, reference.bits[i] == candidate.bits[i]);
                }
            }
            free((^rawptr)(&reference_store)^, context.allocator);
            free((^rawptr)(&candidate_store)^, context.allocator);
        }
    }
}


@test
test_full_range_and_padding_equivalence :: proc(t: ^testing.T) {
    limits := [?]u64{16_385, 65_536, 131_073, 1_000_000, 1_000_001};
    factors := [?]u64{67,71,73,79,83,89,97,101,103,107,109,113,127};
    for limit in limits {
        for factor in factors {
            if factor*factor/2 >= limit/2 {
                continue;
            }
            words := int((limit/2 + 63)/64);
            old_data := make([]u64, words+2);
            new_data := make([]u64, words+2);
            for direction in 0..<2 {
                backwards := direction == 1;
                old_data[0], old_data[words+1] = 0x12345678abcddcba, 0xabcdef0123456789;
                new_data[0], new_data[words+1] = 0x12345678abcddcba, 0xabcdef0123456789;
                for i in 1..=words {
                    seed := u64(i) * 0x9e3779b97f4a7c15;
                    old_data[i] = seed;
                    new_data[i] = seed;
                }
                baseline := BitSieve{upper=limit, bits=old_data[1:words+1]};
                candidate := BitSieve{upper=limit, bits=new_data[1:words+1]};
                mark_sparse_factor(&baseline, factor, backwards);
                mark_dense_extended(&candidate, factor, backwards);
                testing.expect(t, new_data[0] == 0x12345678abcddcba);
                testing.expect(t, new_data[words+1] == 0xabcdef0123456789);
                for i in 0..<words {
                    testing.expect(t, candidate.bits[i] == baseline.bits[i]);
                }
            }
            free((^rawptr)(&old_data)^, context.allocator);
            free((^rawptr)(&new_data)^, context.allocator);
        }
    }
}


@test
test_larger_factor_specializations_match_dense :: proc(t: ^testing.T) {
    factors := [?]u64{17, 19, 23, 29, 31};
    for factor in factors {
        for words in 1..=256 {
            if (factor * factor) / 2 >= u64(words) * 64 {
                continue;
            }
            scalar_storage := make([]u64, words + 2);
            special_storage := make([]u64, words + 2);
            for direction in 0..<2 {
                backwards := direction == 1;
                scalar_storage[0], scalar_storage[words+1] = 0x11223344deadbeef, 0x8877665544332211;
                special_storage[0], special_storage[words+1] = 0x11223344deadbeef, 0x8877665544332211;
                for i in 1..=words {
                    seed := u64(i)*0x9e3779b97f4a7c15;
                    scalar_storage[i] = seed;
                    special_storage[i] = seed;
                }
                scalar := BitSieve{upper=u64(words)*128, bits=scalar_storage[1:words+1]};
                special := BitSieve{upper=u64(words)*128, bits=special_storage[1:words+1]};
                mark_dense_factor(&scalar, factor, backwards);
                switch factor {
                case 17: mark_dense_specialized(17, &special, backwards);
                case 19: mark_dense_specialized(19, &special, backwards);
                case 23: mark_dense_specialized(23, &special, backwards);
                case 29: mark_dense_specialized(29, &special, backwards);
                case 31: mark_dense_specialized(31, &special, backwards);
                }
                testing.expect(t, special_storage[0] == 0x11223344deadbeef);
                testing.expect(t, special_storage[words+1] == 0x8877665544332211);
                for i in 0..<words {
                    testing.expect(t, scalar.bits[i] == special.bits[i]);
                }
            }
            free((^rawptr)(&scalar_storage)^, context.allocator);
            free((^rawptr)(&special_storage)^, context.allocator);
        }
    }
}
