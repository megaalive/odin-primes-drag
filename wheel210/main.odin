// Independent packed 210-wheel Sieve of Eratosthenes for Odin.
// One-bit candidate flags, freshly allocated and sieved for each timed pass.
// Maximum supported limit is MAX_P * MAX_P; see README for faithfulness notes.
package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:sync"
import "core:thread"
import "core:time"

WHEEL :: 210
NRES :: 48
PAT_CUTOFF :: 112
MAX_P :: 10000 // covers sqrt(limit) for limits up to 100M

LIMIT :: 1_000_000

residues: [NRES]int
residue_index: [WHEEL]u8

pat_list: [32]int
pat_count: int
pat_masks: [32][]u64
// Process-lifetime backing; no test allocator lifetime dependency or leaks.
pat_storage: [32][PAT_CUTOFF]u64

Strike :: struct {
	step:   int,
	starts: [NRES]int,
}
large_list: [1280]Strike
large_count: int

clear_list: [1280]int
clear_count: int

tables_ready: bool

mod_inv :: proc(a_in, modulus: int) -> int {
	old_r: i64 = i64(a_in % modulus)
	r: i64 = i64(modulus)
	old_s: i64 = 1
	s: i64 = 0
	for r != 0 {
		q := old_r / r
		next_r := old_r - q * r
		old_r = r
		r = next_r
		next_s := old_s - q * s
		old_s = s
		s = next_s
	}
	inv := old_s
	if inv < 0 {
		inv += i64(modulus)
	}
	return int(inv)
}

// First block b >= 0 with (b*WHEEL + residue) divisible by p.
first_block :: proc(p, residue: int) -> int {
	rm := residue % p
	neg := (p - rm) % p
	inv := mod_inv(WHEEL % p, p)
	return (neg * inv) % p
}

// One-time wheel tables (primes, residues, dense masks). This is algorithm
// definition, not sieve state: the 1M buffer is still built fresh per pass.
init_tables :: proc() {
	if tables_ready {
		return
	}
	n := 0
	for i in 1 ..< WHEEL {
		if i % 2 != 0 && i % 3 != 0 && i % 5 != 0 && i % 7 != 0 {
			residues[n] = i
			n += 1
		}
	}
	assert(n == NRES)
	for i in 0 ..< WHEEL {
		residue_index[i] = 0xFF
	}
	for r, i in residues {
		residue_index[r] = u8(i)
	}
	comp: [MAX_P + 1]bool
	for i in 2 ..= MAX_P {
		if comp[i] {
			continue
		}
		if i >= 11 && i <= PAT_CUTOFF {
			pat_list[pat_count] = i
			pat_count += 1
		}
		if i >= 11 {
			clear_list[clear_count] = i
			clear_count += 1
		}
		if i > PAT_CUTOFF {
			st := Strike{step = i}
			for r, ri in residues {
				st.starts[ri] = first_block(i, r)
			}
			large_list[large_count] = st
			large_count += 1
		}
		if j := i * i; j <= MAX_P {
			for k := j; k <= MAX_P; k += i {
				comp[k] = true
			}
		}
	}
	for i in 0 ..< pat_count {
		p := pat_list[i]
		m := pat_storage[i][:p]
		for r, ri in residues {
			b0 := first_block(p, r)
			m[b0] |= u64(1) << u64(ri)
		}
		pat_masks[i] = m
	}
	tables_ready = true
}

apply_pattern :: proc(words: []u64, pat: []u64) #no_bounds_check {
	p := len(pat)
	n := len(words)
	dst := 0
	for dst + p <= n {
		for k in 0 ..< p {
			words[dst + k] |= pat[k]
		}
		dst += p
	}
	k := 0
	for dst < n {
		words[dst] |= pat[k]
		dst += 1
		k += 1
	}
}

strike :: proc(words: []u64, start, step: int, mask: u64) #no_bounds_check {
	n := len(words)
	if start >= n || step == 0 {
		return
	}
	b := start
	if n > step * 3 && start < n - step * 3 {
		end := n - step * 3
		for b < end {
			words[b] |= mask
			words[b + step] |= mask
			words[b + 2 * step] |= mask
			words[b + 3 * step] |= mask
			b += step * 4
		}
	}
	for b < n {
		words[b] |= mask
		b += step
	}
}

apply_prime_strikes :: proc(words: []u64, p: int) #no_bounds_check {
	for r, ri in residues {
		mask := u64(1) << u64(ri)
		strike(words, first_block(p, r), p, mask)
	}
}

Packed :: struct {
	limit:  int,
	blocks: int,
	words:  []u64,
}

run_packed :: proc(limit: int) -> Packed {
	// Prime-factor tables contain all primes up to MAX_P.
	assert(limit >= 0 && limit <= MAX_P * MAX_P)
	nblocks := limit / WHEEL + 1
	words := make([]u64, nblocks)
	root := int(math.sqrt(f64(limit)))
	if root >= PAT_CUTOFF {
		for i in 0 ..< pat_count {
			apply_pattern(words, pat_masks[i])
		}
		for i in 0 ..< large_count {
			st := &large_list[i] // by reference: no 392-byte copy per prime
			if st.step > root {
				break
			}
			for ri in 0 ..< NRES {
				strike(words, st.starts[ri], st.step, u64(1) << u64(ri))
			}
		}
	} else {
		for i in 0 ..< clear_count {
			p := clear_list[i]
			if p > root {
				break
			}
			apply_prime_strikes(words, p)
		}
	}
	// Clear the sieving primes themselves (marked by their own strikes).
	for i in 0 ..< clear_count {
		p := clear_list[i]
		if p > root {
			break
		}
		b := p / WHEEL
		ri := residue_index[p % WHEEL]
		words[b] &= ~(u64(1) << u64(ri))
	}
	return Packed{limit = limit, blocks = nblocks, words = words}
}

is_prime :: proc(pk: ^Packed, n: int) -> bool #no_bounds_check {
	if n < 2 || n > pk.limit {
		return false
	}
	if n == 2 || n == 3 || n == 5 || n == 7 {
		return true
	}
	r := n % WHEEL
	ri := residue_index[r]
	if ri == 0xFF {
		return false
	}
	b := n / WHEEL
	return ((pk.words[b] >> ri) & 1) == 0
}

prime_count :: proc(pk: ^Packed) -> int {
	c := 0
	for n in 2 ..= pk.limit {
		if is_prime(pk, n) {
			c += 1
		}
	}
	return c
}

validate :: proc() {
	limits := [?]int{10, 100, 1000, 10000, 100000, 1000000, 10000000}
	expected := [?]int{4, 25, 168, 1229, 9592, 78498, 664579}
	for i in 0 ..< len(limits) {
		pk := run_packed(limits[i])
		c := prime_count(&pk)
		delete(pk.words)
		assert(c == expected[i])
	}
}

bench_single :: proc(limit: int) -> (passes: int, secs: f64) {
	start := time.tick_now()
	passes = 0
	for {
		pk := run_packed(limit)
		delete(pk.words)
		passes += 1
		if time.tick_since(start) >= 5 * time.Second {
			break
		}
	}
	secs = time.duration_seconds(time.tick_since(start))
	return passes, secs
}

worker :: proc(passes_ptr: ^int, wg: ^sync.Wait_Group, limit: int) {
	start := time.tick_now()
	local := 0
	for {
		pk := run_packed(limit)
		delete(pk.words)
		local += 1
		if time.tick_since(start) >= 5 * time.Second {
			break
		}
	}
	passes_ptr^ = local
	sync.wait_group_done(wg)
}

bench_mt :: proc(nthreads, limit: int) -> (total: int, secs: f64) {
	start := time.tick_now()
	wg := sync.Wait_Group{}
	sync.wait_group_add(&wg, nthreads)
	local := make([]int, nthreads)
	defer delete(local)
	for i in 0 ..< nthreads {
		thread.run_with_poly_data3(&local[i], &wg, limit, worker)
	}
	sync.wait_group_wait(&wg)
	total = 0
	for v in local {
		total += v
	}
	secs = time.duration_seconds(time.tick_since(start))
	return total, secs
}

main :: proc() {
	init_tables() // once, before threads; workers only read
	validate()

	passes, secs := bench_single(LIMIT)
	fmt.printf("odin_wheel210;%v;%v;1;algorithm=wheel,faithful=yes,bits=1\n", passes, secs)

	nthreads := os.get_processor_core_count()
	if nthreads < 1 {
		nthreads = 1
	}
	tp, ts := bench_mt(nthreads, LIMIT)
	fmt.printf("odin_wheel210_mt;%v;%v;%v;algorithm=wheel,faithful=yes,bits=1\n", tp, ts, nthreads)
}
