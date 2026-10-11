// Prime sieve (Sieve of Eratosthenes) untuk "Software Drag Race" - Odin
// algorithm=wheel, faithful=yes, bits=1, single-thread, LIMIT = 1.000.000
//
// Desain:
//  - Wheel-30: 1 byte = 8 kandidat (residu 1,7,11,13,17,19,23,29) -> 33.334 byte.
//  - Prima 7,11,13 : pola periodik 1001 byte, digandakan ke seluruh array.
//  - Prima 17..P_CUT: pola dibangun saat runtime, di-OR ke array dengan vektor 32 byte sejajar.
//  - Prima >= P_CUT : satu loop gabungan untuk 8 kelas residu, topeng bit berupa immediate
//    (dispesialisasi per p mod 30), dibagi 2 loop @4 kelas agar muat di register.
//  - Setiap pass mengalokasikan sieve baru; prima ditemukan dinamis dari array.
//
// Build (Odin dev-2026-10, perlu clang untuk linking):
//   odin build main.odin -file -o:speed -microarch:native -no-bounds-check -disable-assert -out:primes
// Jalankan:  ./primes      -> hasil "label;passes;durasi;threads;tags" di stdout, detail di stderr
// Cek penuh vs sieve naif:  -define:CHECK=true   |  Batas lain: -define:LIMIT=10000000
//
package main

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"

LIMIT       :: #config(LIMIT, 1_000_000)
RUN_SECONDS :: #config(RUN_SECONDS, 5)
P_CUT       :: #config(P_CUT, 160)
CHECK       :: #config(CHECK, false)

NBYTES :: LIMIT / 30 + 1
SLACK  :: 16384

BIT_OF :: [30]u8{1 = 1, 7 = 2, 11 = 4, 13 = 8, 17 = 16, 19 = 32, 23 = 64, 29 = 128}
CLASS  :: [8]int{1, 7, 11, 13, 17, 19, 23, 29}

@(rodata)
BIT_TAB := [30]u8{1 = 1, 7 = 2, 11 = 4, 13 = 8, 17 = 16, 19 = 32, 23 = 64, 29 = 128}

VW :: #config(VW, 32)
Vec :: #simd[VW]u8

Sieve :: struct {
	arr: [^]u8,
	buf: []u8,
	pat: [^]u8,
}

// Menandai kelipatan prima p = 30a + R (p >= P_CUT) dengan satu loop gabungan
// untuk 8 kelas residu. Topeng bit konstan (immediate) karena R diketahui compile-time.
mark_big :: #force_inline proc "contextless" ($R: int, a: int, arr: [^]u8, nbytes: int) {
	p := 30 * a + R
	o0 := a * 1 + (R * 1) / 30
	o1 := a * 7 + (R * 7) / 30
	o2 := a * 11 + (R * 11) / 30
	o3 := a * 13 + (R * 13) / 30
	o4 := a * 17 + (R * 17) / 30
	o5 := a * 19 + (R * 19) / 30
	o6 := a * 23 + (R * 23) / 30
	o7 := a * 29 + (R * 29) / 30
	m0 :: BIT_OF[(R * 1) % 30]
	m1 :: BIT_OF[(R * 7) % 30]
	m2 :: BIT_OF[(R * 11) % 30]
	m3 :: BIT_OF[(R * 13) % 30]
	m4 :: BIT_OF[(R * 17) % 30]
	m5 :: BIT_OF[(R * 19) % 30]
	m6 :: BIT_OF[(R * 23) % 30]
	m7 :: BIT_OF[(R * 29) % 30]
	for base := p * a; base + o0 < nbytes; base += p {
		arr[base + o0] |= m0
		arr[base + o1] |= m1
		arr[base + o2] |= m2
		arr[base + o3] |= m3
	}
	for base := p * a; base + o4 < nbytes; base += p {
		arr[base + o4] |= m4
		arr[base + o5] |= m5
		arr[base + o6] |= m6
		arr[base + o7] |= m7
	}
}

// Fuse two discovered small factors into one runtime-generated periodic mask.
// Both flags are inspected in the current sieve before using this fast path.
blit_pair :: proc "contextless" ($P: int, $Q: int, arr: [^]u8, nbytes: int, E: [^]u8) {
	PERIOD :: P * Q
	LP :: VW * PERIOD
	mem.zero(E, PERIOD)
	for p in ([2]int{P, Q}) {
		for c in CLASS {
			n := p * c
			m := BIT_TAB[n % 30]
			for x := n / 30; x < PERIOD; x += p {
				E[x] |= m
			}
		}
	}
	filled := PERIOD
	for filled < LP {
		n := min(filled, LP - filled)
		mem.copy(E[filled:], E, n)
		filled += n
	}
	for blk := 0; blk < nbytes; blk += LP {
		for i := 0; i < LP; i += VW {
			pa := (^Vec)(arr[blk + i:])
			pe := (^Vec)(E[i:])
			pa^ |= pe^
		}
	}
	arr[P / 30] &~= BIT_TAB[P % 30]
	arr[Q / 30] &~= BIT_TAB[Q % 30]
}

// Pola periodik 7*11*13 (1001 byte), digandakan ke seluruh array.
init_pattern :: proc "contextless" (arr: [^]u8, nbytes: int) {
	PERIOD :: 7 * 11 * 13
	mem.zero(arr, PERIOD + 32)
	for p in ([3]int{7, 11, 13}) {
		for c in CLASS {
			n := p * c
			b := n / 30
			m := BIT_TAB[n % 30]
			for b < PERIOD {
				arr[b] |= m
				b += p
			}
		}
	}
	filled := PERIOD
	for filled < nbytes + 32 {
		n := min(filled, nbytes + 32 - filled)
		mem.copy(arr[filled:], arr, n)
		filled += n
	}
}

// OR pola kelipatan p ke seluruh array. Buffer pola E panjangnya 32*p sehingga
// akses array dan E sama-sama sejajar 32 byte (tanpa split cache line).
blit_prime :: proc "contextless" (arr: [^]u8, nbytes: int, p: int, E: [^]u8) {
	Lp := VW * p
	mem.zero(E, Lp)
	for c in CLASS {
		n := p * c
		m := BIT_TAB[n % 30]
		for x := n / 30; x < Lp; x += p {
			E[x] |= m
		}
	}
	for blk := 0; blk < nbytes; blk += Lp {
		for i := 0; i < Lp; i += VW {
			pa := (^Vec)(arr[blk + i:])
			pe := (^Vec)(E[i:])
			pa^ |= pe^
		}
	}
	arr[p / 30] &~= BIT_TAB[p % 30]
}

run_sieve :: proc(s: ^Sieve) {
	arr := s.arr
	paired_17_19 := false
	paired_23_29 := false
	init_pattern(arr, NBYTES)
	arr[7 / 30] &~= BIT_TAB[7 % 30]
	arr[11 / 30] &~= BIT_TAB[11 % 30]
	arr[13 / 30] &~= BIT_TAB[13 % 30]
	arr[0] |= 1 // n = 1 bukan prima

	outer: for a := 0;; a += 1 {
		for r in CLASS {
			n := 30 * a + r
			if n < 17 {continue}
			if n * n > LIMIT {break outer}
			if n == 19 && paired_17_19 {continue}
			if n == 29 && paired_23_29 {continue}
			if arr[a] & BIT_TAB[r] != 0 {continue}
			// The sieve already establishes both 17 and 19 as prime here:
			// striking 17 cannot change the flag for 19.
			if n == 17 && P_CUT > 19 && 19 * 19 <= LIMIT && arr[19 / 30] & BIT_TAB[19 % 30] == 0 {
				blit_pair(17, 19, arr, NBYTES, s.pat)
				paired_17_19 = true
				continue
			}
			// Both factors are still discovered from this pass's own sieve.
			if n == 23 && P_CUT > 29 && 29 * 29 <= LIMIT && arr[29 / 30] & BIT_TAB[29 % 30] == 0 {
				blit_pair(23, 29, arr, NBYTES, s.pat)
				paired_23_29 = true
				continue
			}
			if n < P_CUT {
				blit_prime(arr, NBYTES, n, s.pat)
			} else {
				switch r {
				case 1:  mark_big(1, a, arr, NBYTES)
				case 7:  mark_big(7, a, arr, NBYTES)
				case 11: mark_big(11, a, arr, NBYTES)
				case 13: mark_big(13, a, arr, NBYTES)
				case 17: mark_big(17, a, arr, NBYTES)
				case 19: mark_big(19, a, arr, NBYTES)
				case 23: mark_big(23, a, arr, NBYTES)
				case 29: mark_big(29, a, arr, NBYTES)
				}
			}
		}
	}
}

count_primes :: proc(s: ^Sieve) -> int {
	full := (NBYTES - 1) // byte penuh 0 .. NBYTES-2
	words := full / 8
	w := (^[^]u64)(&s.arr)^
	total := 0
	for i in 0 ..< words {
		total += int(intrinsics.count_ones(w[i]))
	}
	for i in words * 8 ..< full {
		total += int(intrinsics.count_ones(s.arr[i]))
	}
	// byte terakhir: hanya bit untuk n <= LIMIT yang valid
	last: u8 = 0
	for r, bi in CLASS {
		if (NBYTES - 1) * 30 + r <= LIMIT {last |= u8(1) << uint(bi)}
	}
	total += int(intrinsics.count_ones(s.arr[NBYTES - 1] & last))
	valid := full * 8 + int(intrinsics.count_ones(last))
	return 3 + (valid - total)
}

is_prime :: proc(s: ^Sieve, n: int) -> bool {
	switch n {
	case 2, 3, 5: return true
	}
	r := n % 30
	if BIT_TAB[r] == 0 {return false}
	return s.arr[n / 30] & BIT_TAB[r] == 0
}

new_sieve :: proc() -> Sieve {
	s: Sieve
	s.buf = mem.alloc_bytes_non_zeroed(NBYTES + SLACK + max(VW * P_CUT, VW * 23 * 29) + 256, 64) or_else nil
	s.arr = raw_data(s.buf)
	s.pat = raw_data(s.buf)[(NBYTES + SLACK + 63) &~ 63:]
	return s
}

free_sieve :: proc(s: ^Sieve) {
	mem.free(raw_data(s.buf))
}

expected_count :: proc() -> int {
	switch LIMIT {
	case 10:          return 4
	case 100:         return 25
	case 1_000:       return 168
	case 10_000:      return 1229
	case 100_000:     return 9592
	case 1_000_000:   return 78498
	case 10_000_000:  return 664579
	case 100_000_000: return 5761455
	}
	return -1
}

sink: u8

main :: proc() {
	passes := 0
	start := time.tick_now()
	limit := time.Duration(RUN_SECONDS) * time.Second
	last: Sieve
	have_last := false
	for {
		s := new_sieve()
		run_sieve(&s)
		sink += s.arr[NBYTES - 1]
		passes += 1
		if time.tick_since(start) >= limit {
			last = s
			have_last = true
			break
		}
		free_sieve(&s)
	}
	elapsed := time.duration_seconds(time.tick_since(start))
	_ = have_last
	count := count_primes(&last)
	want := expected_count()
	valid := want < 0 || count == want

	fmt.eprintfln("Passes: %d, Time: %f, Avg: %f us, Limit: %d, Count: %d, Valid: %v", passes, elapsed, elapsed / f64(passes) * 1e6, LIMIT, count, valid)
	fmt.printfln("odin_wheel30;%d;%f;1;algorithm=wheel,faithful=yes,bits=1", passes, elapsed)

	when CHECK {
		bad := 0
		comp := make([]bool, LIMIT + 1)
		for i in 2 ..= LIMIT {comp[i] = false}
		for i := 2; i * i <= LIMIT; i += 1 {
			if !comp[i] {
				for j := i * i; j <= LIMIT; j += i {comp[j] = true}
			}
		}
		for n in 2 ..= LIMIT {
			if is_prime(&last, n) != !comp[n] {
				bad += 1
				if bad < 10 {fmt.eprintfln("MISMATCH n=%d got=%v want=%v", n, is_prime(&last, n), !comp[n])}
			}
		}
		fmt.eprintfln("CHECK: %d mismatches", bad)
		if bad > 0 {os.exit(2)}
	}
	if !valid {os.exit(1)}
}
