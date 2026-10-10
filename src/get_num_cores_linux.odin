package main

import "core:c"

foreign import libc "system:c"

@(default_calling_convention="c")
foreign libc {
	get_nprocs :: proc() -> c.int ---
}

get_num_cores :: proc() -> int {
	n := int(get_nprocs())
	if n > 0 {
		return n
	}
	return 1
}
