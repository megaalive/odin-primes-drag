#+feature using-stmt
// Berdasarkan sieve prima karya Dave Plummer dan komunitas Odin.
package main

import "core:fmt"
import "core:time"
import "core:math"
import "core:thread"
import "core:sync";
import "base:intrinsics"


expected :: proc(upper: u64) -> u64 {
    switch upper {
    case 10:            return 4;
    case 100:           return 25;
    case 1_000:         return 168;
    case 10_000:        return 1229;
    case 100_000:       return 9592;
    case 1_000_000:     return 78498;
    case 10_000_000:    return 664579;
    case 100_000_000:   return 5761455;
    }
    panic("Unreachable");
}

SIEVE_BACKING :: u64;
SIEVE_BACKING_BITS :: size_of(SIEVE_BACKING) * 8;
BitSieve :: struct {
    upper: u64,
    bits: []SIEVE_BACKING,
}

make_bits :: proc(using sieve: ^BitSieve, size: u64) {
    half := size / 2;
    count := (half + SIEVE_BACKING_BITS - 1) / SIEVE_BACKING_BITS;
    bits = make([]SIEVE_BACKING, int(count), context.allocator);
}

get_bit :: proc(using sieve: ^BitSieve, index: u64) -> bool #no_bounds_check {
    backing := bits[index / SIEVE_BACKING_BITS];
    masked := backing & (1 << (index & (SIEVE_BACKING_BITS - 1)));
    return masked != 0;
}

set_bit :: proc(using sieve: ^BitSieve, index: u64, value: SIEVE_BACKING) #no_bounds_check {
    bits[index / SIEVE_BACKING_BITS] |= value << (index & (SIEVE_BACKING_BITS - 1));
}

mark_factor_three :: proc(using sieve: ^BitSieve) #no_bounds_check {
    masks: [3]SIEVE_BACKING;
    for phase := u64(0); phase < 3; phase += 1 {
        for bit := phase; bit < 64; bit += 3 {
            masks[phase] |= SIEVE_BACKING(1) << bit;
        }
    }

    words := u64(len(bits));
    if words == 0 {
        return;
    }
    first_mask := SIEVE_BACKING(0);
    for bit := u64(4); bit < 64; bit += 3 {
        first_mask |= SIEVE_BACKING(1) << bit;
    }
    bits[0] = first_mask;

    word := u64(1);
    for word + 3 <= words {
        bits[word] = masks[0];
        bits[word + 1] = masks[2];
        bits[word + 2] = masks[1];
        word += 3;
    }
    for word < words {
        switch word % 3 {
        case 1: bits[word] = masks[0];
        case 2: bits[word] = masks[2];
        case 0: bits[word] = masks[1];
        }
        word += 1;
    }
}

mark_dense_factor :: proc(using sieve: ^BitSieve, factor: u64, backwards: bool) #no_bounds_check {
    masks: [128]SIEVE_BACKING;
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
    cycle: [128]SIEVE_BACKING;
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
            offset := factor;
            for offset >= 4 {
                offset -= 4;
                mask := #simd[4]u64{
                    cycle[offset], cycle[offset + 1],
                    cycle[offset + 2], cycle[offset + 3],
                };
                ptr := cast(^#simd[4]u64)(&bits[begin + offset]);
                previous := intrinsics.unaligned_load(ptr);
                intrinsics.unaligned_store(ptr, previous | mask);
            }
            for offset > 0 {
                bits[begin + offset - 1] |= cycle[offset - 1];
                offset -= 1;
            }
            end = begin;
        }
        return;
    }

    for word + factor <= words {
        offset := u64(0);
        for offset + 4 <= factor {
            mask := #simd[4]u64{
                cycle[offset], cycle[offset + 1],
                cycle[offset + 2], cycle[offset + 3],
            };
            ptr := cast(^#simd[4]u64)(&bits[word + offset]);
            previous := intrinsics.unaligned_load(ptr);
            intrinsics.unaligned_store(ptr, previous | mask);
            offset += 4;
        }
        for offset < factor {
            bits[word + offset] |= cycle[offset];
            offset += 1;
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


mark_dense_extended :: proc(sieve: ^BitSieve, factor: u64, backwards: bool) #no_bounds_check {
    words := len(sieve.bits);
    if words == 0 {
        return;
    }
    valid := (sieve.upper / 2) & 63;
    if valid == 0 {
        mark_dense_factor(sieve, factor, backwards);
        return;
    }
    last := words - 1;
    valid_mask := (u64(1) << valid) - 1;
    prior_padding := sieve.bits[last] &~ valid_mask;
    mark_dense_factor(sieve, factor, backwards);
    sieve.bits[last] = (sieve.bits[last] & valid_mask) | prior_padding;
}

mark_dense_specialized :: proc($F: u64, using sieve: ^BitSieve, backwards: bool) #no_bounds_check {
    #assert(F == 5 || F == 7 || F == 11 || F == 13 || F == 17 || F == 19 || F == 23 || F == 29 || F == 31);

    FIRST_INDEX :: (F * F) / 2;
    FIRST_WORD :: FIRST_INDEX / 64;
    words := u64(len(bits));
    if words <= FIRST_WORD {
        return;
    }

    first_mask: u64 = 0;
    for bit := FIRST_INDEX & 63; bit < 64; bit += F {
        first_mask |= u64(1) << bit;
    }
    bits[FIRST_WORD] |= first_mask;

    cycle: [F]u64;
    #unroll for slot in 0..<F {
        mask: u64 = 0;
        word_offset := (FIRST_WORD + 1 + u64(slot)) * 64 - FIRST_INDEX;
        start_bit := (F - word_offset % F) % F;
        for bit := start_bit; bit < 64; bit += F {
            mask |= u64(1) << bit;
        }
        cycle[slot] = mask;
    }

    word := FIRST_WORD + 1;
    if backwards {
        full_end := word + ((words - word) / F) * F;
        tail := words;
        for tail > full_end {
            tail -= 1;
            bits[tail] |= cycle[tail - full_end];
        }

        end := full_end;
        for end > word {
            begin := end - F;
            offset := F;
            for offset >= 4 {
                offset -= 4;
                mask := #simd[4]u64{
                    cycle[offset], cycle[offset + 1],
                    cycle[offset + 2], cycle[offset + 3],
                };
                ptr := cast(^#simd[4]u64)(&bits[begin + offset]);
                previous := intrinsics.unaligned_load(ptr);
                intrinsics.unaligned_store(ptr, previous | mask);
            }
            for offset > 0 {
                bits[begin + offset - 1] |= cycle[offset - 1];
                offset -= 1;
            }
            end = begin;
        }
        return;
    }

    for word + F <= words {
        offset := u64(0);
        for offset + 4 <= F {
            mask := #simd[4]u64{
                cycle[offset], cycle[offset + 1],
                cycle[offset + 2], cycle[offset + 3],
            };
            ptr := cast(^#simd[4]u64)(&bits[word + offset]);
            previous := intrinsics.unaligned_load(ptr);
            intrinsics.unaligned_store(ptr, previous | mask);
            offset += 4;
        }
        for offset < F {
            bits[word + offset] |= cycle[offset];
            offset += 1;
        }
        word += F;
    }
    offset := u64(0);
    for word < words {
        bits[word] |= cycle[offset];
        offset += 1;
        word += 1;
    }
}

mark_sparse_forward_phase :: proc($RESIDUE: u64, using sieve: ^BitSieve, factor: u64) #no_bounds_check {
    #assert(RESIDUE == 1 || RESIDUE == 3 || RESIDUE == 5 || RESIDUE == 7);
    first := factor * factor / 2;
    limit := upper / 2;
    if first >= limit {
        return;
    }
    remaining := 1 + (limit - 1 - first) / factor;
    if remaining < 16 {
        for index := first; index < limit; index += factor {
            set_bit(sieve, index, 1);
        }
        return;
    }

    bytes := cast([^]u8)raw_data(bits);
    offsets: [8]u64;
    byte_index := first / 8;
    for lane := u64(0); lane < 8; lane += 1 {
        offsets[lane] = (first + lane * factor) / 8 - byte_index;
    }

    index := first;
    for remaining >= 8 {
        bytes[byte_index + offsets[0]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 0 * RESIDUE) & 7);
        bytes[byte_index + offsets[1]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 1 * RESIDUE) & 7);
        bytes[byte_index + offsets[2]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 2 * RESIDUE) & 7);
        bytes[byte_index + offsets[3]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 3 * RESIDUE) & 7);
        bytes[byte_index + offsets[4]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 4 * RESIDUE) & 7);
        bytes[byte_index + offsets[5]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 5 * RESIDUE) & 7);
        bytes[byte_index + offsets[6]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 6 * RESIDUE) & 7);
        bytes[byte_index + offsets[7]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 7 * RESIDUE) & 7);
        remaining -= 8;
        index += 8 * factor;
        byte_index += factor;
    }
    for remaining > 0 {
        set_bit(sieve, index, 1);
        remaining -= 1;
        index += factor;
    }
}

mark_sparse_reverse_phase :: proc($RESIDUE: u64, using sieve: ^BitSieve, factor: u64) #no_bounds_check {
    #assert(RESIDUE == 1 || RESIDUE == 3 || RESIDUE == 5 || RESIDUE == 7);
    first := factor * factor / 2;
    limit := upper / 2;
    if first >= limit {
        return;
    }
    remaining := 1 + (limit - 1 - first) / factor;
    index := first + (remaining - 1) * factor;
    if remaining < 16 {
        for remaining > 0 {
            set_bit(sieve, index, 1);
            remaining -= 1;
            if remaining > 0 {
                index -= factor;
            }
        }
        return;
    }

    tail := remaining & 7;
    for tail > 0 {
        set_bit(sieve, index, 1);
        tail -= 1;
        remaining -= 1;
        index -= factor;
    }

    bytes := cast([^]u8)raw_data(bits);
    offsets: [8]u64;
    byte_index := index / 8;
    for lane := u64(0); lane < 8; lane += 1 {
        hit := index - lane * factor;
        offsets[lane] = byte_index - hit / 8;
    }
    for remaining >= 8 {
        bytes[byte_index - offsets[0]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 7 * RESIDUE) & 7);
        bytes[byte_index - offsets[1]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 6 * RESIDUE) & 7);
        bytes[byte_index - offsets[2]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 5 * RESIDUE) & 7);
        bytes[byte_index - offsets[3]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 4 * RESIDUE) & 7);
        bytes[byte_index - offsets[4]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 3 * RESIDUE) & 7);
        bytes[byte_index - offsets[5]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 2 * RESIDUE) & 7);
        bytes[byte_index - offsets[6]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 1 * RESIDUE) & 7);
        bytes[byte_index - offsets[7]] |= u8(1) << (((RESIDUE * RESIDUE) / 2 + 0 * RESIDUE) & 7);
        remaining -= 8;
        if remaining > 0 {
            byte_index -= factor;
        }
    }
}

mark_sparse_factor :: proc(using sieve: ^BitSieve, factor: u64, backwards: bool) #no_bounds_check {
    if backwards {
        switch factor & 7 {
        case 1: mark_sparse_reverse_phase(1, sieve, factor);
        case 3: mark_sparse_reverse_phase(3, sieve, factor);
        case 5: mark_sparse_reverse_phase(5, sieve, factor);
        case 7: mark_sparse_reverse_phase(7, sieve, factor);
        }
        return;
    }
    switch factor & 7 {
    case 1: mark_sparse_forward_phase(1, sieve, factor);
    case 3: mark_sparse_forward_phase(3, sieve, factor);
    case 5: mark_sparse_forward_phase(5, sieve, factor);
    case 7: mark_sparse_forward_phase(7, sieve, factor);
    }
}


find_next_factor_bit :: proc(using sieve: ^BitSieve, start, last: u64) -> u64 #no_bounds_check {
    if start > last {
        return last + 1;
    }

    word := start / 64;
    unseen := ~bits[word] & (~u64(0) << (start & 63));
    for {
        if unseen != 0 {
            index := word * 64 + u64(intrinsics.count_trailing_zeros(unseen));
            if index <= last {
                return index;
            }
            return last + 1;
        }
        word += 1;
        if word > last / 64 {
            return last + 1;
        }
        unseen = ~bits[word];
    }
}

run_sieve_bit :: proc(upper: u64) -> (sieve: BitSieve) #no_bounds_check {
    sieve.upper = upper;
    make_bits(&sieve, upper);

    q := u64(math.sqrt(f64(upper)));
    backwards := true;
    if q >= 3 {
        last := (q - 1) / 2;
        index := u64(1);
        for {
            index = find_next_factor_bit(&sieve, index, last);
            if index > last {
                break;
            }
            factor := 2 * index + 1;
            if factor == 3 {
                mark_factor_three(&sieve);
            } else if factor < 64 {
                switch factor {
                case 5: mark_dense_specialized(5, &sieve, backwards);
                case 7: mark_dense_specialized(7, &sieve, backwards);
                case 11: mark_dense_specialized(11, &sieve, backwards);
                case 13: mark_dense_specialized(13, &sieve, backwards);
                case 17: mark_dense_specialized(17, &sieve, backwards);
                case 19: mark_dense_specialized(19, &sieve, backwards);
                case 23: mark_dense_specialized(23, &sieve, backwards);
                case 29: mark_dense_specialized(29, &sieve, backwards);
                case 31: mark_dense_specialized(31, &sieve, backwards);
                case: mark_dense_factor(&sieve, factor, backwards);
                }
                backwards = !backwards;
            } else {
                if factor < 128 {
                    mark_dense_extended(&sieve, factor, backwards);
                } else {
                    mark_sparse_factor(&sieve, factor, backwards);
                }
                backwards = !backwards;
            }
            index += 1;
        }
    }
    return sieve;
}

count_primes_bit :: proc(using sieve: ^BitSieve) -> (count: u64) #no_bounds_check {
    count = 1 if upper >= 2 else 0;
    for i := u64(3) / 2; i < upper / 2; i += 1 {
        if !get_bit(sieve, i) {
            count += 1;
        }
    }
    return count;
}

ByteSieve :: struct {
    upper: u64,
    bits: []bool,
}

run_sieve_byte :: proc(upper: u64) -> (sieve: ByteSieve) #no_bounds_check {
    sieve.upper = upper;
    sieve.bits = make([]bool, upper / 2, context.allocator);
    factor := u64(3);
    q := u64(math.sqrt(f64(upper)));

    for ; factor <= q; factor += 2 {
        for num := factor / 2; num < upper / 2; num += 1 {
            if !sieve.bits[num] {
                factor = num * 2 + 1;
                break;
            }
        }

        for num := factor * factor / 2; num < upper / 2; num += factor {
            sieve.bits[num] = true;
        }
    }

    return sieve;
}

count_primes_byte :: proc(using sieve: ^ByteSieve) -> (count: u64) #no_bounds_check {
    count = 1 if upper >= 2 else 0;
    for i := u64(3) / 2; i < upper / 2; i += 1 {
        if !bits[i] {
            count += 1;
        }
    }
    return count;
}

count_primes :: proc{ count_primes_bit, count_primes_byte };

measure_run :: proc(size: u64, run_func: $T) -> (passes: u32, total_time: f64) {
    start_time := time.tick_now();

    for time.tick_since(start_time) < 5*time.Second {
        sieve := run_func(size);
        passes += 1;
        free((^rawptr)(&sieve.bits)^, context.allocator);
    }
    total_time = time.duration_seconds(time.tick_since(start_time));
    return passes, total_time;
}

thread_worker_bit :: proc(passes: ^u32, wg: ^sync.Wait_Group, size: u64) {
    passes^, _ = measure_run(size, run_sieve_bit);
    sync.wait_group_done(wg);
}

thread_worker_byte :: proc(passes: ^u32, wg: ^sync.Wait_Group, size: u64) {
    passes^, _ = measure_run(size, run_sieve_byte);
    sync.wait_group_done(wg);
}

run_threaded_bit :: proc(thread_count: int, size: u64) -> (total_passes: u32, total_time: f64) {
    start_time := time.tick_now();

    wg := sync.Wait_Group{};
    sync.wait_group_add(&wg, thread_count);

    local_passes := make([]u32, thread_count);
    for i in 0..<thread_count {
        thread.run_with_poly_data3(&local_passes[i], &wg, size, thread_worker_bit);
    }

    sync.wait_group_wait(&wg);

    for c in local_passes {
        total_passes += c;
    }
    total_time = time.duration_seconds(time.tick_since(start_time));
    return total_passes, total_time;
}

run_threaded_byte :: proc(thread_count: int, size: u64) -> (total_passes: u32, total_time: f64) {
    start_time := time.tick_now();

    wg := sync.Wait_Group{};
    sync.wait_group_add(&wg, thread_count);

    local_passes := make([]u32, thread_count);
    for i in 0..<thread_count {
        thread.run_with_poly_data3(&local_passes[i], &wg, size, thread_worker_byte);
    }

    sync.wait_group_wait(&wg);

    for c in local_passes {
        total_passes += c;
    }
    total_time = time.duration_seconds(time.tick_since(start_time));
    return total_passes, total_time;
}

main :: proc() {
    size :: 1_000_000;

    bit_check := run_sieve_bit(size);
    if count_primes(&bit_check) != expected(size) {
        panic("Bit sieve prime count mismatch");
    }
    free((^rawptr)(&bit_check.bits)^, context.allocator);
    byte_check := run_sieve_byte(size);
    if count_primes(&byte_check) != expected(size) {
        panic("Byte sieve prime count mismatch");
    }
    free((^rawptr)(&byte_check.bits)^, context.allocator);

    passes, total := measure_run(size, run_sieve_bit);
    fmt.printf("\nodin_bit_moe;%v;%v;1;algorithm=base,faithful=yes,bits=1", passes, total);
    passes, total = measure_run(size, run_sieve_byte);
    fmt.printf("\nodin_byte_moe;%v;%v;1;algorithm=base,faithful=yes,bits=8", passes, total);

    thread_count := get_num_cores();
    if thread_count < 1 {
        thread_count = 1;
    }
    passes, total = run_threaded_bit(thread_count, size);
    fmt.printf(
        "\nodin_bit_threaded_moe;%v;%v;%v;algorithm=base,faithful=yes,bits=1",
        passes, total, thread_count);
    passes, total = run_threaded_byte(thread_count, size);
    fmt.printf(
        "\nodin_byte_threaded_moe;%v;%v;%v;algorithm=base,faithful=yes,bits=8",
        passes, total, thread_count);
}
