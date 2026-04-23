module test_lru_eviction;
	localparam N_SETS = 4;
	localparam N_WAYS = 4;

	logic				clk;
	logic				reset;

	logic [2:0]			cache_operation;

	logic [$clog2(N_SETS)-1:0]	set_index;
	logic [$clog2(N_WAYS)-1:0]	way_index;

	logic [$clog2(N_WAYS)-1:0]	evicted_way_index;

	lru_eviction #(.N_SETS(N_SETS), .N_WAYS(N_WAYS)) lru_eviction (
		.clk(clk),
		.reset(reset),
		.cache_operation(cache_operation),
		.set_index(set_index),
		.way_index(way_index),
		.evicted_way_index(evicted_way_index)
	);

	always begin: clock
		#5 clk = ~clk;
	end: clock

	initial begin: test_logic
		# 10 reset = 1;	// reset the synchronous elements of the lru_eviction on the first clock edge

		set_index = 0;
		// to start the test, I'll just keep miss set so the eviction tracker just marks
		// each entry as evicted (as if it's awaiting its fill request)
		cache_operation[1:0] = 'b10;
		# 2	// let signals from above assertion propagate, but no clock edge has passed
		assert(evicted_way_index == 0);
		# 8	// allow the remaining time in the clock period pass
		assert(evicted_way_index == 1);
		# 10
		assert(evicted_way_index == 2);
		# 10
		assert(evicted_way_index == 3);
		// so now every way in this set has been evicted.  the behavior for what happens on the next miss is undefined

		reset = 0;
		# 10
		reset = 1;

		cache_operation[1:0] = 'b11;	// hit
		set_index = 1;
		way_index = 2;
		# 10
		// now index 2 has been recently used
		// miss, which will evict index 0, and can be refilled later
		cache_operation[1:0] = 'b10;	// miss
		# 2	// allow ^ to propagate, but the clock edge hasn't passed
		assert(evicted_way_index == 0);
		# 8	// now the clock edge has passed

		cache_operation[1:0] = 'b11;	// hit
		way_index = 1;
		# 10
		// now index 0 is evicted, 1 and 2 are recently used

		cache_operation[1:0] = 'b10;	// miss
		# 2
		assert(evicted_way_index == 3);
		# 8

		$display("All assertions passed.");
		$finish();
	end: test_logic
endmodule
