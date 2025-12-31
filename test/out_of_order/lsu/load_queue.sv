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
	logic				cdb_active;
	logic [ROB_TAG_WIDTH-1:0]	cdb_tag;
	logic				load_fired;
	logic [$clog2(LDQ_SIZE)-1:0]	load_fired_index;
	logic				load_fired_sleep;
	logic [ROB_TAG_WIDTH-1:0]	load_fired_sleep_rob_tag;
	logic				load_fired_forward;
	logic [$clog2(STQ_SIZE)-1:0]	load_fired_forward_index;
	logic				load_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	load_succeeded_rob_tag;
	logic				rob_commit;
	logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag;
	logic [LDQ_SIZE-1:0]		order_failures;
	logic				store_fired;
	logic [3:0]			store_fired_index;

	logic [LDQ_SIZE-1:0]				ldq_valid;
	logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address;
	logic [LDQ_SIZE-1:0]				ldq_address_valid;
	logic [LDQ_SIZE-1:0]				ldq_sleeping;
	logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_sleep_rob_tag;	// not actually checked in the test
	logic [LDQ_SIZE-1:0]				ldq_executed;
	logic [LDQ_SIZE-1:0]				ldq_succeeded;
	logic [LDQ_SIZE-1:0]				ldq_committed;
	logic [LDQ_SIZE-1:0]				ldq_order_fail;
	logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask;
	logic [LDQ_SIZE-1:0]				ldq_forwarded;
	logic [LDQ_SIZE-1:0][$clog2(STQ_SIZE)-1:0]	ldq_forward_stq_index;
	logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag;

	logic [LDQ_SIZE-1:0]				ldq_rotated_valid;
	logic [LDQ_SIZE-1:0]				ldq_rotated_address_valid;	// TODO add to test
	logic [LDQ_SIZE-1:0]				ldq_rotated_sleeping;
	logic [LDQ_SIZE-1:0]				ldq_rotated_executed;

	logic [$clog2(LDQ_SIZE)-1:0]	head;
	logic [$clog2(LDQ_SIZE)-1:0]	tail;

	logic	full;	// untested yet but happily here waiting to be tested

	load_queue #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) ldq (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),
		.store_mask(store_mask),
		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),
		.cdb_active(cdb_active),
		.cdb_tag(cdb_tag),
		.load_fired(load_fired),
		.load_fired_index(load_fired_index),
		.load_fired_sleep(load_fired_sleep),
		.load_fired_sleep_rob_tag(load_fired_sleep_rob_tag),
		.load_fired_forward(load_fired_forward),
		.load_fired_forward_index(load_fired_forward_index),
		.load_succeeded(load_succeeded),
		.load_succeeded_rob_tag(load_succeeded_rob_tag),
		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),
		.order_failures(order_failures),
		.store_fired(store_fired),
		.store_fired_index(store_fired_index),

		// load queue outputs
		.ldq_valid(ldq_valid),
		.ldq_address(ldq_address),
		.ldq_address_valid(ldq_address_valid),
		.ldq_sleeping(ldq_sleeping),
		.ldq_sleep_rob_tag(ldq_sleep_rob_tag),
		.ldq_executed(ldq_executed),
		.ldq_succeeded(ldq_succeeded),
		.ldq_committed(ldq_committed),
		.ldq_order_fail(ldq_order_fail),
		.ldq_store_mask(ldq_store_mask),
		.ldq_forwarded(ldq_forwarded),
		.ldq_forward_stq_index(ldq_forward_stq_index),
		.ldq_rob_tag(ldq_rob_tag),
		.ldq_rotated_valid(ldq_rotated_valid),
		.ldq_rotated_address_valid(ldq_rotated_address_valid),
		.ldq_rotated_sleeping(ldq_rotated_sleeping),
		.ldq_rotated_executed(ldq_rotated_executed),
		.head(head),
		.tail(tail),
		.full(full)
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
		store_fired = 1;
		store_fired_index = 7;
		# 10
		assert(ldq_store_mask[0] == 'hCA7E);

		store_fired_index = 1;
		# 10
		assert(ldq_store_mask[0] == 'hCA7C);

		store_fired_index = 9;
		# 10
		assert(ldq_store_mask[0] == 'hC87C);

		store_fired = 0;
		load_fired = 1;
		load_fired_index = 0;
		# 10
		// We've now stated that we've executed the load at index 0.
		// Asserting that the first entry's executed bit is set.
		assert(ldq_executed[0] == 1);

		load_fired = 0;
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

		// allocate three more entries in the load queue to test the new
		// load_fired signals and the rotated status bits
		alloc_ldq_entry = 1;
		rob_tag_in = 14;
		store_mask = 'hAAAA;
		# 10
		assert(ldq_valid == 'h0002);
		assert(head == 1);
		assert(tail == 2);
		assert(ldq_rotated_valid == 'h0001);	// assert that the rotated signal is set at 0

		rob_tag_in = 49;
		store_mask = 'hFFFF;
		# 10
		assert(ldq_valid == 'h0006);
		assert(head == 1);
		assert(tail == 3);
		assert(ldq_rotated_valid == 'h0003);

		rob_tag_in = 59;
		store_mask = 'h0000;
		# 10
		assert(ldq_valid == 'h000E);
		assert(head == 1);
		assert(tail == 4);
		assert(ldq_rotated_valid == 'h0007);

		alloc_ldq_entry = 0;
		rob_tag_in = 0;
		store_mask = 0;

		// in practice, we'd have the address_valid and address set in
		// the load queue before we provide signals indicating that
		// the load has been fired, but this is ensured by the
		// lsu_control module.  the load_queue will let us just set
		// the executed, sleep, and forward bits making the assumption
		// that it won't be provided an index for an entry that
		// doesn't have a valid address yet.

		// set the load_fired signals for the first load (at index 1)
		// this load will just be fired, no sleep, no forwarding
		load_fired = 1;
		load_fired_index = 1;
		load_fired_sleep = 0;
		load_fired_sleep_rob_tag = 0;
		load_fired_forward = 0;
		load_fired_forward_index = 0;
		# 10
		assert(ldq_executed == 'h0002);
		assert(ldq_rotated_executed == 'h0001);
		assert(ldq_sleeping == 'h0000);
		assert(ldq_rotated_sleeping == 'h0000);
		assert(ldq_forwarded == 'h0000);

		// set the load_fired signals for the second load (at index 2)
		// this load will be put to sleep
		load_fired = 1;
		load_fired_index = 2;
		load_fired_sleep = 1;
		load_fired_sleep_rob_tag = 30;
		load_fired_forward = 0;
		load_fired_forward_index = 0;
		# 10
		// the expected result for the load at index 2 is executed = 0,
		// sleeping = 1, and forward = 0
		assert(ldq_executed == 'h0002);	// bit 2 is cleared
		assert(ldq_rotated_executed == 'h0001);	// bit 1 is cleared (index - head = 2 - 1 = 1)
		assert(ldq_sleeping == 'h0004);	// bit 2 is set
		assert(ldq_rotated_sleeping == 'h0002);	// bit 1 is set (index - head = 1)
		assert(ldq_forwarded == 'h0000);	// nothing is forwarded

		// set the load_fired signals for the third load (at index 3)
		// this load will have data forwarded
		load_fired = 1;
		load_fired_index = 3;
		load_fired_sleep = 0;
		load_fired_sleep_rob_tag = 0;
		load_fired_forward = 1;
		load_fired_forward_index = 'h7;
		# 10
		// the expected result for the load at index 3 is executed = 1,
		// sleeping = 0, and forward = 1
		assert(ldq_executed == 'h000A);	// bit 3 is set
		assert(ldq_rotated_executed == 'h0005);	// bit 2 is set (index - head = 3 - 1 = 2)
		assert(ldq_sleeping == 'h0004);	// bit 3 is cleared
		assert(ldq_rotated_sleeping == 'h0002);	// bit 2 is cleared (index - head = 2)
		assert(ldq_forwarded == 'h0008);	// bit 3 is set
		assert(ldq_forward_stq_index[3] == 'h7);	// verify the index is stored

		// no more firing loads
		load_fired = 0;
		load_fired_index = 0;
		load_fired_sleep = 0;
		load_fired_sleep_rob_tag = 0;
		load_fired_forward = 0;
		load_fired_forward_index = 0;
		// now we need to verify that the sleeping load wakes if it's
		// ROB tag is seen on the CDB
		cdb_active = 1;
		cdb_tag = 30;
		# 10
		assert(ldq_sleeping == 'h0000);
		assert(ldq_rotated_sleeping == 'h0000);

		cdb_active = 0;
		cdb_tag = 0;

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
