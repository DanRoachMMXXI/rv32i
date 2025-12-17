module test_load_queue;
	import lsu_pkg::*;

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
	logic [ROB_TAG_WIDTH-1:0]	load_executed_rob_tag;
	logic				load_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	load_succeeded_rob_tag;
	logic				rob_commit;
	logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag;
	logic [LDQ_SIZE-1:0]		order_failures;

	load_queue_entry [15:0]		load_queue_entries;

	load_queue /* #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) */ ldq (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),
		.store_mask(store_mask),
		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),
		.load_executed(load_executed),
		.load_executed_rob_tag(load_executed_rob_tag),
		.load_succeeded(load_succeeded),
		.load_succeeded_rob_tag(load_succeeded_rob_tag),
		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),
		.order_failures(order_failures),
		.load_queue_entries(load_queue_entries),
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
		assert(load_queue_entries[0].valid == 0);

		alloc_ldq_entry = 1;
		rob_tag_in = 19;
		# 10
		// The first LDQ entry has been allocated.
		assert(load_queue_entries[0].valid == 1);

		alloc_ldq_entry = 0;
		rob_tag_in = 0;
		agu_address_valid = 1;
		agu_address_data = 42;
		# 10
		// An address is valid and active on the bus, but the ROB
		// tag does not match the ROB tag stored in the first queue
		// entry.  The address should not be updated.
		assert(load_queue_entries[0].address_valid == 0);
		assert(load_queue_entries[0].address == 0);	// it should never have changed after reset to 0

		agu_address_rob_tag = 19;
		# 10
		// The address ROB tag now matches the ROB tag stored in
		// the first queue entry. Asserting that the address is
		// valid and the address is 42.
		assert(load_queue_entries[0].address_valid == 1);
		assert(load_queue_entries[0].address == 42);

		// clearing all AGU signals after they were set last cycle.
		agu_address_valid = 0;
		agu_address_rob_tag = 0;
		agu_address_data = 0;

		load_executed = 1;
		load_executed_rob_tag = 19;
		# 10
		// We've now stated that we've executed the load with ROB tag
		// 19.  Asserting that the first entry's executed bit is set.
		assert(load_queue_entries[0].executed == 1);

		load_executed = 0;
		load_executed_rob_tag = 0;
		load_succeeded = 1;
		load_succeeded_rob_tag = 19;
		# 10
		// We've stated that the load with ROB tag 19 succeeded.
		// Asserting that the first entry's succeeded bit is set.
		assert(load_queue_entries[0].succeeded == 1);

		load_succeeded = 0;
		load_succeeded_rob_tag = 0;
		rob_commit = 1;
		rob_commit_tag = 19;
		# 10
		assert(load_queue_entries[0].committed == 1);

		# 10
		// The next cycle, since the head of the buffer has been
		// committed, we should see the entry be cleared
		assert(load_queue_entries[0].valid == 0);

		/*
		 * this test is by no means comprehensive, nor even complete
		 * for one entry.  I just wanted to validate compilation and
		 * a handful of basic features.
		 * TODO: would love to finish this test
		 */
		$display("All assertions passed.");
		$finish();
	end
endmodule
