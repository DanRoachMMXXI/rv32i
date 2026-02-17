module test_load_store_unit;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH=32;
	localparam LDQ_SIZE=16;
	localparam LDQ_TAG_WIDTH=$clog2(LDQ_SIZE)+2;
	localparam STQ_SIZE=16;
	localparam STQ_TAG_WIDTH=$clog2(STQ_SIZE)+2;

	logic clk = 0;
	logic reset = 0;

	logic				alloc_ldq_entry;
	logic				alloc_stq_entry;
	logic [ROB_TAG_WIDTH-1:0]	rob_tag_in;
	logic [XLEN-1:0]		store_data;
	logic				store_data_valid;
	logic [ROB_TAG_WIDTH-1:0]	data_producer_rob_tag_in;
	logic				agu_address_valid;
	logic [XLEN-1:0]		agu_address_data;
	logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag;
	logic				rob_commit;
	logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag;
	logic				flush;
	logic [ROB_TAG_WIDTH-1:0]	flush_rob_tag;
	logic [LDQ_TAG_WIDTH-1:0]	ldq_new_tail;
	logic [STQ_TAG_WIDTH-1:0]	stq_new_tail;
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
	logic [LDQ_SIZE-1:0][STQ_TAG_WIDTH-1:0]		ldq_forward_stq_tag;
	logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag;

	logic [LDQ_SIZE-1:0]				ldq_rotated_valid;
	logic [LDQ_SIZE-1:0]				ldq_rotated_address_valid;
	logic [LDQ_SIZE-1:0]				ldq_rotated_sleeping;
	logic [LDQ_SIZE-1:0]				ldq_rotated_executed;

	logic [STQ_SIZE-1:0]				stq_valid;
	logic [STQ_SIZE-1:0] [XLEN-1:0]			stq_address;
	logic [STQ_SIZE-1:0]				stq_address_valid;
	logic [STQ_SIZE-1:0] [XLEN-1:0]			stq_data;
	logic [STQ_SIZE-1:0]				stq_data_valid;
	logic [STQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		stq_data_producer_rob_tag;
	logic [STQ_SIZE-1:0]				stq_committed;
	logic [STQ_SIZE-1:0]				stq_executed;
	logic [STQ_SIZE-1:0]				stq_succeeded;
	logic [STQ_SIZE-1:0] [ROB_TAG_WIDTH-1:0]	stq_rob_tag;

	logic [STQ_SIZE-1:0] stq_rotated_valid;
	logic [STQ_SIZE-1:0] stq_rotated_address_valid;
	logic [STQ_SIZE-1:0] stq_rotated_data_valid;
	logic [STQ_SIZE-1:0] stq_rotated_committed;
	logic [STQ_SIZE-1:0] stq_rotated_executed;
	logic [STQ_SIZE-1:0] stq_rotated_succeeded;

	logic [LDQ_TAG_WIDTH-1:0] ldq_head;
	logic [STQ_TAG_WIDTH-1:0] stq_head;
	logic [LDQ_TAG_WIDTH-1:0] ldq_tail;
	logic [STQ_TAG_WIDTH-1:0] stq_tail;

	logic				load_fired;
	logic [LDQ_TAG_WIDTH-1:0]	load_fired_ldq_tag;
	logic				load_fired_sleep;
	logic [ROB_TAG_WIDTH-1:0]	load_fired_sleep_rob_tag;
	logic				forward;
	logic [STQ_TAG_WIDTH-1:0]	stq_forward_tag;

	logic [LDQ_SIZE-1:0] order_failures;

	logic				kill_mem_req;
	logic				fire_memory_op;
	logic				memory_op_type;
	logic [XLEN-1:0]		memory_address;
	logic [XLEN-1:0]		memory_data;

	load_store_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .LDQ_TAG_WIDTH(LDQ_TAG_WIDTH), .STQ_SIZE(STQ_SIZE), .STQ_TAG_WIDTH(STQ_TAG_WIDTH)) lsu (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(alloc_ldq_entry),
		.alloc_stq_entry(alloc_stq_entry),
		.rob_tag_in(rob_tag_in),
		.store_data(store_data),
		.store_data_valid(store_data_valid),
		.data_producer_rob_tag_in(data_producer_rob_tag_in),
		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),
		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),
		.flush(flush),
		.flush_rob_tag(flush_rob_tag),
		.ldq_new_tail(ldq_new_tail),
		.stq_new_tail(stq_new_tail),
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
		.ldq_forward_stq_tag(ldq_forward_stq_tag),
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
		.stq_data_producer_rob_tag(stq_data_producer_rob_tag),
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
		.ldq_tail(ldq_tail),
		.stq_tail(stq_tail),
		.load_fired(load_fired),
		.load_fired_ldq_tag(load_fired_ldq_tag),
		.load_fired_sleep(load_fired_sleep),
		.load_fired_sleep_rob_tag(load_fired_sleep_rob_tag),
		.forward(forward),
		.stq_forward_tag(stq_forward_tag),
		.order_failures(order_failures),
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
		alloc_stq_entry = 1;
		rob_tag_in = 2;
		# 10
		assert(stq_valid == 'h0001);

		alloc_stq_entry = 0;
		rob_tag_in = 0;

		// first we'll populate the address
		agu_address_valid = 1;
		agu_address_data = 'h0123_4567;
		agu_address_rob_tag = 2;
		# 10
		assert(stq_address_valid == 'h0001);
		assert(fire_memory_op == 0);

		agu_address_valid = 0;
		agu_address_data = 0;
		agu_address_rob_tag = 0;

		// now we'll put the data on the CDB
		cdb_active = 1;
		cdb_data = 'h89AB_CDEF;
		cdb_tag = 2;
		# 10
		// the data should now be stored in the store queue
		// TODO: this is failing because I changed the store queue to read a producer tag
		// off the CDB, not its own tag.  This is the correct behavior, so the test needs to
		// be updated to provide a producer ROB tag and provide that on the CDB.
		assert(stq_data_valid == 'h0001);
		assert(stq_data[0] == 'h89AB_CDEF);
		assert(fire_memory_op == 0);

		cdb_active = 0;
		cdb_data = 0;
		cdb_tag = 0;

		// now we need to commit the store
		rob_commit = 1;
		rob_commit_tag = 2;
		# 10
		// since the store has committed and there is no other load,
		// the store should be fired
		assert(stq_committed == 'h0001);
		assert(fire_memory_op == 1);
		assert(memory_op_type == 1);
		assert(memory_address == 'h0123_4567);
		assert(memory_data == 'h89AB_CDEF);

		rob_commit = 0;
		rob_commit_tag = 0;
		# 10
		assert(stq_executed == 'h0001);

		// now memory tells the LSU that the store succeeded
		store_succeeded = 1;
		store_succeeded_rob_tag = 2;
		# 10
		assert(stq_succeeded == 'h0001);

		// much like how the load queue clears an entry the cycle
		// after it commits, the store queue clears the entry the
		// cycle after it succeeds, so we need to validate that the
		// entry is no longer valid and that the head pointer has
		// incremented.
		store_succeeded = 0;
		store_succeeded_rob_tag = 0;
		# 10
		assert(stq_valid == 'h0000);
		assert(stq_head == 1);

		// TODO: populate like 4-5 loads and stores each, then
		// gradually provide the addresses and data (for stores) and
		// verify that they're issued correctly.  try to make sure
		// some get put to sleep, and at the end, force an order
		// failure from one of the stores by waiting to give it its
		// address until the load executes.
		// also make sure at least one store has its data provided
		// when it's allocated (with store_data and store_data_valid)

		// allocate a store queue entry without providing data
		alloc_stq_entry = 1;
		rob_tag_in = 3;
		# 10
		alloc_stq_entry = 0;
		rob_tag_in = 0;

		// provide an address to the store queue entry and allocate
		// a load queue entry (this will depend on the store queue
		// entry)
		agu_address_valid = 1;
		agu_address_data = 'h4534_2312;
		agu_address_rob_tag = 3;

		alloc_ldq_entry = 1;
		rob_tag_in = 4;
		# 10
		// verify the load queue entry has the correct store mask
		// since there's a valid entry in the store queue
		assert(ldq_store_mask[1] == 'h0002);

		alloc_ldq_entry = 0;
		rob_tag_in = 0;

		// provide the same address to the load queue entry
		// the other signals are already asserted
		agu_address_rob_tag = 4;
		# 10
		// the store queue entry has not received its data, so it's
		// not ready to fire.  so the lsu_control should select the
		// load since its address is valid.  then, the searcher must
		// identify the dependence on the store.  since the data is
		// not valid, the searcher must put this load to sleep.
		assert(fire_memory_op == 1);
		assert(kill_mem_req == 1);

		// the next cycle, the fact that the load has been put to
		// sleep should be updated in the load queue
		# 10
		assert(ldq_sleeping == 'h0002);
		assert(ldq_executed == 'h0000);

		// now that we have a pending store and a dependent sleeping
		// load, we'll add a store with data and a dependent load that
		// will have its data forwarded
		alloc_stq_entry = 1;
		rob_tag_in = 5;
		store_data_valid = 1;
		store_data = 'h7777_7777;
		# 10
		alloc_stq_entry = 0;
		rob_tag_in = 0;
		store_data_valid = 0;
		store_data = 0;
		// provide the address to the store
		agu_address_valid = 1;
		agu_address_data = 'h6666_6666;
		agu_address_rob_tag = 5;
		# 10
		agu_address_valid = 0;
		agu_address_rob_tag = 0;
		// the store should not be fired as it isn't committed yet
		assert(fire_memory_op == 0);

		// allocate the load queue entry
		alloc_ldq_entry = 1;
		rob_tag_in = 6;
		# 10
		alloc_ldq_entry = 0;
		rob_tag_in = 0;
		// provide the address to the store
		agu_address_valid = 1;
		agu_address_rob_tag = 6;
		# 10
		agu_address_valid = 0;
		agu_address_data = 0;
		agu_address_rob_tag = 0;

		// the load should be fired, but the memory request should be
		// killed as the data is to be forwarded from the store.
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'h6666_6666);
		assert(kill_mem_req == 1);
		assert(forward == 1);
		assert(stq_forward_tag == 2);
		# 10
		// the next cycle, the status bits in the load queue should
		// update.
		assert(ldq_forwarded == 'h0004);
		assert(ldq_forward_stq_tag[2] == 2);

		// now we're gonna provide the data for the first store at
		// index 1 and verify it wakes the sleeping load at ldq index
		// 1
		cdb_active = 1;
		cdb_tag = 3;
		cdb_data = 'h5656_7878;
		# 10
		cdb_active = 0;
		cdb_tag = 0;
		cdb_data = 0;

		assert(stq_data_valid == 'h0006);
		assert(ldq_sleeping == 'h0000);	// the ldq should be watching the cdb for this store
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'h4534_2312);
		assert(kill_mem_req == 1);
		assert(forward == 1);
		assert(stq_forward_tag == 1);

		// lets commit the first store and verify that the bits of the
		// store_masks of ldq indices 1 and 2 are cleared
		// first assert they are set
		assert(ldq_store_mask[1][1] == 1);
		assert(ldq_store_mask[1][2] == 0);	// ldq index 1 was allocated before stq index 2
		assert(ldq_store_mask[2][1] == 1);
		assert(ldq_store_mask[2][2] == 1);

		rob_commit = 1;
		rob_commit_tag = 3;
		# 10
		rob_commit = 0;
		rob_commit_tag = 0;
		// now the store is gonna be fired this cycle, so this signal
		// will reach the load queue this cycle and be updated on the
		// next clock edge
		assert(fire_memory_op == 1);
		assert(memory_op_type == 1);
		assert(memory_address == 'h4534_2312);
		assert(memory_data == 'h5656_7878);
		# 10
		// now the store_mask bits should be cleared
		assert(ldq_store_mask[1][1] == 0);
		assert(ldq_store_mask[1][2] == 0);
		assert(ldq_store_mask[2][1] == 0);
		assert(ldq_store_mask[2][2] == 1);

		// to make this somewhat match real conditions, we'll commit
		// ROB index 4 before 5, meaning we'll commit the load at
		// index 1
		rob_commit = 1;
		rob_commit_tag = 4;
		# 10
		assert(ldq_committed == 'h0002);
		rob_commit_tag = 5;
		# 10
		assert(stq_committed == 'h0006);
		// store should be fired this cycle, which will update the
		// store_masks the next cycle
		rob_commit = 0;
		rob_commit_tag = 0;
		# 10
		assert(ldq_store_mask[2][2] == 0);

		// commit the load
		rob_commit = 1;
		rob_commit_tag = 6;
		# 10
		rob_commit_tag = 0;

		// now succeed the stores so they're cleared
		store_succeeded = 1;
		store_succeeded_rob_tag = 3;
		# 10
		store_succeeded_rob_tag = 5;
		# 10
		store_succeeded = 0;
		store_succeeded_rob_tag = 0;
		# 10
		assert(ldq_valid == 'h0000);
		assert(stq_valid == 'h0000);
		
		// now we're going to force an order failure by allocating
		// a store and then a load.  the load will be provided its
		// address and execute.  After the load succeeds, we'll
		// provide the same address to the store, execute it, and
		// commit it.
		// I think I'll also force an order failure with a load that
		// forwarded from an earlier store.
		alloc_stq_entry = 1;
		rob_tag_in = 7;
		store_data_valid = 1;
		store_data = 'hAAAA_AAAA;
		# 10
		alloc_stq_entry = 0;
		alloc_ldq_entry = 1;
		rob_tag_in = 8;
		store_data_valid = 0;
		store_data = 0;
		# 10
		alloc_ldq_entry = 0;
		rob_tag_in = 0;
		agu_address_valid = 1;
		agu_address_data = 'hABCD_DCBA;
		agu_address_rob_tag = 8;	// for the load
		# 10
		agu_address_valid = 0;
		agu_address_data = 0;
		agu_address_rob_tag = 0;
		// just verify the load is fired
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'hABCD_DCBA);
		# 10
		assert(ldq_executed == 'h0008);
		load_succeeded = 1;
		load_succeeded_rob_tag = 8;
		# 10
		assert(ldq_succeeded == 'h0008);
		load_succeeded = 0;
		load_succeeded_rob_tag = 0;

		// now we can give the stq the address
		agu_address_valid = 1;
		agu_address_data = 'hABCD_DCBA;
		agu_address_rob_tag = 7;	// for the store
		# 10
		agu_address_valid = 0;
		agu_address_data = 0;
		agu_address_rob_tag = 0;
		// now we can commit the store, which will fire it
		rob_commit = 1;
		rob_commit_tag = 7;
		# 10
		rob_commit = 0;
		rob_commit_tag = 0;
		// I think in BOOM, the order failures happen on commit.
		// In my design, they are checked when the store is fired,
		// which is a flaw of my design since it could be detected
		// sooner.  Anyways, we check when it's fired for now.

		// verify the store is fired
		assert(fire_memory_op == 1);
		assert(memory_op_type == 1);
		// there's an internal signal in the load_store_unit that has
		// all load failures for the fired store, but I can just wait
		// a clock cycle to see it get stored in the load queue
		# 10
		// verify order failure
		assert(ldq_order_fail == 'h0008);

		reset = 0;
		# 10
		reset = 1;

		// so here we'll allocate two store queue entries.  the first
		// will receive its address from the AGU, but the second will
		// not until a dependent load has had its data forwarded from
		// the first store.
		alloc_stq_entry = 1;
		rob_tag_in = 10;
		store_data_valid = 1;
		store_data = 'h6543_3456;
		# 10
		rob_tag_in = 11;
		store_data = 'h3456_6543;
		# 10
		alloc_stq_entry = 0;
		rob_tag_in = 0;
		store_data_valid = 0;
		store_data = 0;

		alloc_ldq_entry = 1;
		rob_tag_in = 12;
		# 10
		alloc_ldq_entry = 0;
		rob_tag_in = 0;

		agu_address_valid = 1;
		agu_address_data = 'h1231_2312;
		agu_address_rob_tag = 10;
		# 10
		agu_address_rob_tag = 12;
		# 10
		agu_address_valid = 0;
		agu_address_rob_tag = 0;
		# 10
		assert(ldq_executed == 'h0001);
		load_succeeded = 1;
		load_succeeded_rob_tag = 12;
		# 10
		load_succeeded = 0;
		load_succeeded_rob_tag = 0;
		assert(ldq_succeeded == 'h0001);
		// commit the first store, finally provide the address for the
		// second store
		rob_commit = 1;
		rob_commit_tag = 10;
		agu_address_valid = 1;
		agu_address_rob_tag = 11;
		# 10
		agu_address_valid = 0;
		agu_address_data = 0;
		agu_address_rob_tag = 0;

		rob_commit_tag = 11;
		# 10
		rob_commit = 0;
		rob_commit_tag = 0;
		// store fires here
		assert(order_failures == 'h0001);
		# 10
		assert(ldq_order_fail == 'h0001);

		// TODO: populate load and store queues, then set flush with
		// a flush_rob_tag that causes some of the entries in both
		// queues to be flushed.  verify the tail pointers are updated
		// and the valid arrays are updated correctly.
		reset = 0;
		# 10
		reset = 1;
		alloc_ldq_entry = 1;
		rob_tag_in = 4;
		# 10
		alloc_ldq_entry = 0;
		alloc_stq_entry = 1;
		rob_tag_in = 5;
		# 10
		alloc_stq_entry = 0;
		alloc_ldq_entry = 1;
		rob_tag_in = 6;
		# 10;
		alloc_ldq_entry = 0;
		alloc_stq_entry = 1;
		rob_tag_in = 7;
		# 10
		alloc_stq_entry = 0;
		alloc_ldq_entry = 1;
		rob_tag_in = 8;
		# 10;
		alloc_ldq_entry = 0;

		assert(ldq_valid == 'h0007);
		assert(stq_valid == 'h0003);
		assert(ldq_rob_tag[0] == 4);
		assert(ldq_rob_tag[1] == 6);
		assert(ldq_rob_tag[2] == 8);
		assert(stq_rob_tag[0] == 5);
		assert(stq_rob_tag[1] == 7);
		assert(ldq_tail == 3);
		assert(stq_tail == 2);
		// now the LDQ has 3 entries with rob tags 4, 6, and 8, and
		// the STQ has 2 entries with rob tags 5 and 7.
		// flushing entry 6 seems appropriate
		flush = 1;
		flush_rob_tag = 6;
		ldq_new_tail = 1;	// index 1 is being flushed
		stq_new_tail = 1;
		# 10
		assert(ldq_valid == 'h0001);
		assert(stq_valid == 'h0001);
		assert(ldq_rob_tag[0] == 4);
		assert(stq_rob_tag[0] == 5);
		assert(ldq_tail == 1);
		assert(stq_tail == 1);
		$display("All assertions passed.");
		$finish();
	end

	function void print_ldq_entry(integer index);
		$display("ldq_valid[%d]: %d", index, ldq_valid[index]);
		$display("ldq_address[%d]: 0x%0h", index, ldq_address[index]);
		$display("ldq_address_valid[%d]: %d", index, ldq_address_valid[index]);
		$display("ldq_sleeping[%d]: %d", index, ldq_sleeping[index]);
		$display("ldq_sleep_rob_tag[%d]: %d", index, ldq_sleep_rob_tag[index]);
		$display("ldq_executed[%d]: %d", index, ldq_executed[index]);
		$display("ldq_succeeded[%d]: %d", index, ldq_succeeded[index]);
		$display("ldq_committed[%d]: %d", index, ldq_committed[index]);
		$display("ldq_order_fail[%d]: 0x%0h", index, ldq_order_fail[index]);
		$display("ldq_store_mask[%d]: 0x%0h", index, ldq_store_mask[index]);
		$display("ldq_forwarded[%d]: %d", index, ldq_forwarded[index]);
		$display("ldq_forward_stq_index[%d]: %d", index, ldq_forward_stq_tag[index]);
		$display("ldq_rob_tag[%d]: %d", index, ldq_rob_tag[index]);
	endfunction
endmodule
