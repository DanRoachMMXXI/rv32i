module test_load_store_unit;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH=32;
	localparam LDQ_SIZE=16;
	localparam STQ_SIZE=16;

	logic clk = 0;
	logic reset = 0;

	logic				alloc_ldq_entry;
	logic				alloc_stq_entry;
	logic [ROB_TAG_WIDTH-1:0]	rob_tag_in;
	logic [XLEN-1:0]		store_data;
	logic				store_data_valid;
	logic				agu_address_valid;
	logic [XLEN-1:0]		agu_address_data;
	logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag;
	logic				rob_commit;
	logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag;
	logic				load_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	load_succeeded_rob_tag;
	logic				store_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	store_succeeded_rob_tag;
	logic				cdb_active;
	logic [XLEN-1:0]		cdb_data;
	logic [ROB_TAG_WIDTH-1:0]	cdb_tag;

	logic [LDQ_SIZE-1:0]				ldq_valid;
	logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address;
	logic [LDQ_SIZE-1:0]				ldq_address_valid;
	logic [LDQ_SIZE-1:0]				ldq_sleeping;
	logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_sleep_rob_tag;
	logic [LDQ_SIZE-1:0]				ldq_executed;
	logic [LDQ_SIZE-1:0]				ldq_succeeded;
	logic [LDQ_SIZE-1:0]				ldq_committed;
	logic [LDQ_SIZE-1:0]				ldq_order_fail;
	logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask;
	logic [LDQ_SIZE-1:0]				ldq_forwarded;
	logic [LDQ_SIZE-1:0][$clog2(STQ_SIZE)-1:0]	ldq_forward_stq_index;
	logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag;

	logic [LDQ_SIZE-1:0]				ldq_rotated_valid;
	logic [LDQ_SIZE-1:0]				ldq_rotated_address_valid;
	logic [LDQ_SIZE-1:0]				ldq_rotated_sleeping;
	logic [LDQ_SIZE-1:0]				ldq_rotated_executed;

	logic [STQ_SIZE-1:0] stq_valid;
	logic [STQ_SIZE-1:0] [XLEN-1:0] stq_address;
	logic [STQ_SIZE-1:0] stq_address_valid;
	logic [STQ_SIZE-1:0] [XLEN-1:0] stq_data;
	logic [STQ_SIZE-1:0] stq_data_valid;
	logic [STQ_SIZE-1:0] stq_committed;
	logic [STQ_SIZE-1:0] stq_executed;
	logic [STQ_SIZE-1:0] stq_succeeded;
	logic [STQ_SIZE-1:0] [ROB_TAG_WIDTH-1:0] stq_rob_tag;

	logic [STQ_SIZE-1:0] stq_rotated_valid;
	logic [STQ_SIZE-1:0] stq_rotated_address_valid;
	logic [STQ_SIZE-1:0] stq_rotated_data_valid;
	logic [STQ_SIZE-1:0] stq_rotated_committed;
	logic [STQ_SIZE-1:0] stq_rotated_executed;
	logic [STQ_SIZE-1:0] stq_rotated_succeeded;

	logic [$clog2(LDQ_SIZE)-1:0] ldq_head;
	logic [$clog2(STQ_SIZE)-1:0] stq_head;

	logic				kill_mem_req;
	logic				fire_memory_op;
	logic				memory_op_type;
	logic [XLEN-1:0]		memory_address;
	logic [XLEN-1:0]		memory_data;

	load_store_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) lsu (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(alloc_ldq_entry),
		.alloc_stq_entry(alloc_stq_entry),
		.rob_tag_in(rob_tag_in),
		.store_data(store_data),
		.store_data_valid(store_data_valid),
		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),
		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),
		.load_succeeded(load_succeeded),
		.load_succeeded_rob_tag(load_succeeded_rob_tag),
		.store_succeeded(store_succeeded),
		.store_succeeded_rob_tag(store_succeeded_rob_tag),
		.cdb_active(cdb_active),
		.cdb_data(cdb_data),
		.cdb_tag(cdb_tag),

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
		.stq_valid(stq_valid),
		.stq_address(stq_address),
		.stq_address_valid(stq_address_valid),
		.stq_data(stq_data),
		.stq_data_valid(stq_data_valid),
		.stq_committed(stq_committed),
		.stq_executed(stq_executed),
		.stq_succeeded(stq_succeeded),
		.stq_rob_tag(stq_rob_tag),
		.stq_rotated_valid(stq_rotated_valid),
		.stq_rotated_address_valid(stq_rotated_address_valid),
		.stq_rotated_data_valid(stq_rotated_data_valid),
		.stq_rotated_committed(stq_rotated_committed),
		.stq_rotated_executed(stq_rotated_executed),
		.stq_rotated_succeeded(stq_rotated_succeeded),
		.ldq_head(ldq_head),
		.stq_head(stq_head),
		.kill_mem_req(kill_mem_req),
		.fire_memory_op(fire_memory_op),
		.memory_op_type(memory_op_type),
		.memory_address(memory_address),
		.memory_data(memory_data)
	);

	initial begin
		#10 reset = 1;
	end

	always begin
		#5 clk = ~clk;
	end

	initial begin
		// test logic
		# 10	// wait for reset

		// put an individual load through the load_store_unit
		alloc_ldq_entry = 1;
		rob_tag_in = 1;
		# 10
		// assert the entry was allocated in the load queue
		// not going to assert every signal here, just enough to be
		// convinced the components are working together as intended.
		assert(ldq_valid == 'h0001);

		alloc_ldq_entry = 0;
		rob_tag_in = 0;
		// now we need to provide the address for the load
		agu_address_valid = 1;
		agu_address_data = 'h6666_6666;
		agu_address_rob_tag = 1;
		# 10
		assert(ldq_address_valid == 'h0001);
		// now the load should be fired
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'h6666_6666);

		agu_address_valid = 0;
		agu_address_data = 0;
		agu_address_rob_tag = 0;
		# 10
		assert(ldq_executed == 'h0001);
		// after another clock cycle, we need to verify the load has
		// not been fired again
		assert(fire_memory_op == 0);
		assert(memory_op_type == 0);
		assert(memory_address == 'h0000_0000);

		// now we'll mock the response from our memory interface that
		// the load succeeded
		load_succeeded = 1;
		load_succeeded_rob_tag = 1;
		# 10
		assert(ldq_succeeded == 'h0001);

		load_succeeded = 0;
		load_succeeded_rob_tag = 0;

		// now we have to commit the load so the queue can know to
		// free it
		rob_commit = 1;
		rob_commit_tag = 1;
		# 10
		assert(ldq_committed == 'h0001);

		rob_commit = 0;
		rob_commit_tag = 0;
		# 10
		// currently, the load queue is designed so that it clears the
		// entry after the commit is stored.  maybe this needs to get
		// changed later on, in which case this comment should explain
		// why this assertion is failing.
		assert(ldq_valid == 'h0000);
		assert(ldq_head == 1);

		// TODO: do the same for a single store

		// TODO: populate like 4-5 loads and stores each, then
		// gradually provide the addresses and data (for stores) and
		// verify that they're issued correctly.  try to make sure
		// some get put to sleep, and at the end, force an order
		// failure from one of the stores by waiting to give it its
		// address until the load executes.

		$display("All assertions passed.");
		$finish();
	end
endmodule
