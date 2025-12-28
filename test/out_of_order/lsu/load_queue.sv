module test_load_queue;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH=32;
	localparam LDQ_SIZE=16;
	localparam STQ_SIZE=16;

	logic clk = 0;
	logic reset = 0;

	logic				alloc_ldq_entry;
	logic [ROB_TAG_WIDTH-1:0]	rob_tag_in;
	logic [STQ_SIZE-1:0]		store_mask;
	logic				agu_address_valid;
	logic [XLEN-1:0]		agu_address_data;
	logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag;
	logic				load_executed;
	logic [$clog2(LDQ_SIZE)-1:0]	load_executed_index;
	logic				load_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	load_succeeded_rob_tag;
	logic				rob_commit;
	logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag;
	logic [LDQ_SIZE-1:0]		order_failures;
	logic				stq_entry_fired;
	logic [3:0]			stq_entry_fired_index;

	logic [LDQ_SIZE-1:0]				ldq_valid;
	logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address;
	logic [LDQ_SIZE-1:0]				ldq_address_valid;
	logic [LDQ_SIZE-1:0]				ldq_executed;
	logic [LDQ_SIZE-1:0]				ldq_succeeded;
	logic [LDQ_SIZE-1:0]				ldq_committed;
	logic [LDQ_SIZE-1:0]				ldq_order_fail;
	logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask;
	logic [LDQ_SIZE-1:0]				ldq_forward_stq_data;
	logic [LDQ_SIZE-1:0][$clog2(STQ_SIZE)-1:0]	ldq_forward_stq_index;
	logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag;

	load_queue #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) ldq (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),
		.store_mask(store_mask),
		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),
		.load_executed(load_executed),
		.load_executed_index(load_executed_index),
		.load_succeeded(load_succeeded),
		.load_succeeded_rob_tag(load_succeeded_rob_tag),
		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),
		.order_failures(order_failures),
		.stq_entry_fired(stq_entry_fired),
		.stq_entry_fired_index(stq_entry_fired_index),

		// load queue outputs
		.ldq_valid(ldq_valid),
		.ldq_address(ldq_address),
		.ldq_address_valid(ldq_address_valid),
		.ldq_executed(ldq_executed),
		.ldq_succeeded(ldq_succeeded),
		.ldq_committed(ldq_committed),
		.ldq_order_fail(ldq_order_fail),
		.ldq_store_mask(ldq_store_mask),
		.ldq_forward_stq_data(ldq_forward_stq_data),
		.ldq_forward_stq_index(ldq_forward_stq_index),
		.ldq_rob_tag(ldq_rob_tag),
		.head(),
		.tail(),
		.full()
	);

	initial begin
		#10 reset = 1;
	end

	always begin
		#5 clk = ~clk;
	end

	initial begin
		// test logic
		# 10
		// The queue has been reset, all entries should be empty
		assert(ldq_valid[0] == 0);

		alloc_ldq_entry = 1;
		rob_tag_in = 19;
		store_mask = 'hCAFE;
		# 10
		// The first LDQ entry has been allocated and the store mask
		// has been set.
		assert(ldq_valid[0] == 1);
		assert(ldq_store_mask[0] == 'hCAFE);

		alloc_ldq_entry = 0;
		rob_tag_in = 0;
		store_mask = 0;
		agu_address_valid = 1;
		agu_address_data = 42;
		# 10
		// An address is valid and active on the bus, but the ROB
		// tag does not match the ROB tag stored in the first queue
		// entry.  The address should not be updated.
		assert(ldq_address_valid[0] == 0);
		assert(ldq_address[0] == 0);	// it should never have changed after reset to 0

		agu_address_rob_tag = 19;
		# 10
		// The address ROB tag now matches the ROB tag stored in
		// the first queue entry. Asserting that the address is
		// valid and the address is 42.
		assert(ldq_address_valid[0] == 1);
		assert(ldq_address[0] == 42);

		// clearing all AGU signals after they were set last cycle.
		agu_address_valid = 0;
		agu_address_rob_tag = 0;
		agu_address_data = 0;

		// testing clearing bits in the store mask
		stq_entry_fired = 1;
		stq_entry_fired_index = 7;
		# 10
		assert(ldq_store_mask[0] == 'hCA7E);

		stq_entry_fired_index = 1;
		# 10
		assert(ldq_store_mask[0] == 'hCA7C);

		stq_entry_fired_index = 9;
		# 10
		assert(ldq_store_mask[0] == 'hC87C);

		stq_entry_fired = 0;
		load_executed = 1;
		load_executed_index = 0;
		# 10
		// We've now stated that we've executed the load at index 0.
		// Asserting that the first entry's executed bit is set.
		assert(ldq_executed[0] == 1);

		load_executed = 0;
		load_succeeded = 1;
		load_succeeded_rob_tag = 19;
		# 10
		// We've stated that the load with ROB tag 19 succeeded.
		// Asserting that the first entry's succeeded bit is set.
		assert(ldq_succeeded[0] == 1);

		load_succeeded = 0;
		load_succeeded_rob_tag = 0;
		rob_commit = 1;
		rob_commit_tag = 19;
		# 10
		assert(ldq_committed[0] == 1);

		# 10
		// The next cycle, since the head of the buffer has been
		// committed, we should see the entry be cleared
		assert(ldq_valid[0] == 0);

		// Test storing order failure bits.  The load queue doesn't
		// actually do anything with these, some other combinational
		// component will raise the exception and flush.
		order_failures = 'h1337;	// a bit unrealistic of a mask, but works for test
		# 10
		assert(ldq_order_fail[0]);
		assert(ldq_order_fail[1]);
		assert(ldq_order_fail[2]);
		assert(ldq_order_fail[9]);
		assert(ldq_order_fail[12]);

		/*
		 * this test is by no means comprehensive, nor even complete
		 * for one entry.  I just wanted to validate compilation and
		 * a handful of basic features.
		 */
		$display("All assertions passed.");
		$finish();
	end
endmodule
