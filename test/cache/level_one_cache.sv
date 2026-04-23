module test_cache;
	localparam XLEN = 32;
	localparam CACHE_SIZE = 1024;
	localparam N_WAYS = 4;
	localparam BLOCK_SIZE = 8;	// smaller than typical, but just to test
	localparam N_MSHR = 4;
	localparam FILL_BUFFER_SIZE = 4;

	// parameters not provided to the cache instance, but computed internally and needed to
	// parameterize the test appropriately
	localparam N_SETS = CACHE_SIZE / (BLOCK_SIZE * N_WAYS);
	localparam BLOCK_OFFSET_START = 0;
	localparam BLOCK_OFFSET_END = BLOCK_OFFSET_START + $clog2(BLOCK_SIZE) - 1;
	localparam SET_START = BLOCK_OFFSET_END + 1;
	localparam SET_END = SET_START + $clog2(N_SETS) - 1;
	localparam TAG_START = SET_END + 1;
	localparam TAG_END = XLEN - 1;
	localparam TAG_WIDTH = (TAG_END + 1) - TAG_START;	// _END and _START are indices so that they can be used in inclusive ranges, so we need to add 1 to the _END to count that bit

	logic		clk;
	logic		reset;

	logic		hit;
	logic		miss;

	logic			fire_memory_op;
	logic			memory_op_type;
	logic [XLEN-1:0]	address_in;
	logic [XLEN-1:0]	data_in;
	logic [(XLEN/8)-1:0]	byte_mask;
	logic [XLEN-1:0]	data_out;

	logic [BLOCK_SIZE-1:0][7:0]	cache_block_data_out;

	logic [XLEN-1:0]		missed_block_address;
	logic [XLEN-1:0]		evicted_address;
	logic				write_evicted_data;

	logic				fetch_valid;
	logic [XLEN-1:0]		fetched_block_address;
	logic [BLOCK_SIZE-1:0][7:0]	fetched_block_data;

	logic [2:0]			cache_operation;

	cache #(.XLEN(XLEN), .CACHE_SIZE(CACHE_SIZE), .N_WAYS(N_WAYS), .BLOCK_SIZE(BLOCK_SIZE), .N_MSHR(N_MSHR), .FILL_BUFFER_SIZE(FILL_BUFFER_SIZE)) cache (
		.clk(clk),
		.reset(reset),

		.hit(hit),
		.miss(miss),
		
		.fire_memory_op(fire_memory_op),
		.memory_op_type(memory_op_type),
		.address_in(address_in),
		.data_in(data_in),
		.byte_mask(byte_mask),
		.data_out(data_out),

		.cache_block_data_out(cache_block_data_out),

		.missed_block_address(missed_block_address),
		.evicted_address(evicted_address),
		.write_evicted_data(write_evicted_data),
	
		.fetch_valid(fetch_valid),
		.fetched_block_address(fetched_block_address),
		.fetched_block_data(fetched_block_data),

		.cache_operation(cache_operation)
	);

	always begin
		# 5
		clk = ~clk;
	end

	initial begin
		reset_cache();

		test_stores_then_hit();

		reset_cache();
		$display("All assertions passed.");
		$finish();
	end

	task reset_cache();
		reset = 0;
		# 10
		reset = 1;
	endtask

	task test_stores_then_hit();
		// put a few elements in the cache
		fire_memory_op = 1;
		memory_op_type = 1;	// store
		address_in = 1207947628;
		data_in = 999268129;
		byte_mask = 4'b1111;
		# 2
		assert(miss == 1'b1);
		assert(missed_block_address == get_block_address(1207947628));
		assert(write_evicted_data == 1'b0);	// nothing in the cache to evict
		# 8

		address_in = 2588171924;
		data_in = 1496203539;
		# 2
		assert(miss == 1'b1);
		assert(missed_block_address == get_block_address(2588171924));
		assert(write_evicted_data == 1'b0);	// nothing in the cache to evict
		# 8

		address_in = 2396258840;
		data_in = 3999942774;
		# 2
		assert(miss == 1'b1);
		assert(missed_block_address == get_block_address(2396258840));
		assert(write_evicted_data == 1'b0);	// nothing in the cache to evict
		# 8

		fire_memory_op = 0;

		# 10

		// all previous attempted accesses are waiting in the MSHRs
		provide_fetched_data(1207947628, 'h0123456789ABCDEF);

		// verify the fill is fired this cycle, note that if we set fire_memory_op to
		// perform another operation, that will take priority over the fill
		assert(cache_operation[1:0] == 2'b01);

		# 10

		fire_memory_op = 1;
		memory_op_type = 0;
		address_in = 1207947628;
		# 2
		assert(hit == 1);
		assert(cache_block_data_out == 'h3B8F9F2189ABCDEF);
		# 8
		fire_memory_op = 0;

		provide_fetched_data(2588171924, 'hFEDCBA9876543210);
		# 10	// the entry is taken from the fill buffer and placed in the cache

		fire_memory_op = 1;
		memory_op_type = 0;
		address_in = 2588171924;
		# 2
		assert(hit == 1);
		assert(cache_block_data_out == 'h592E411376543210);
		# 8
		fire_memory_op = 0;

		# 10

		// provide the data for the third cache access
		provide_fetched_data(2396258840, 'hFFFFFFFFFFFFFFFF);
		# 10	// the entry is taken from the fill buffer and placed in the cache

		fire_memory_op = 1;
		memory_op_type = 0;
		address_in = 2396258840;
		# 2
		assert(hit == 1);
		assert(cache_block_data_out == 'hFFFFFFFFEE6A4876);
		# 8
		fire_memory_op = 0;
	endtask

	task test_eviction();
		// first we need to fill each way of a set by providing addresses with the same set
		// index
		logic [$clog2(N_SETS)-1:0]	set_index;
		set_index = $urandom_range(0, N_SETS-1)[$clog2(N_SETS)-1:0];

		// each tag and stored data will just be the index of the way it's stored in
		for (int i = 0; i < N_WAYS; i = i + 1) begin
			fire_memory_op = 1;
			memory_op_type = 1;	// choosing stores so that the data in the cache will be dirty
			address_in[TAG_END:TAG_START] = i[TAG_WIDTH-1:0];
			address_in[SET_END:SET_START] = set_index;
			address_in[BLOCK_OFFSET_END:BLOCK_OFFSET_START] = 0;
			data_in = i[XLEN-1:0];
			# 10 ;
		end

		// TODO do some reads, then test eviction
	endtask

	task provide_fetched_data(int address, logic[BLOCK_SIZE-1:0][7:0] block_data);
		fetch_valid = 1'b1;
		fetched_block_address = get_block_address(address);
		fetched_block_data = block_data;
		# 10	// the fetch is placed in the fill buffer this cycle
		fetch_valid = 1'b0;
	endtask

	function int get_block_address(int address);
		return address & ~(BLOCK_SIZE-1);
	endfunction
endmodule
