module test_lsu_control;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH=32;
	localparam LDQ_SIZE=16;
	localparam STQ_SIZE=16;

	logic [LDQ_SIZE-1:0][XLEN-1:0]	ldq_address;
	logic [LDQ_SIZE-1:0]		ldq_rotated_valid;
	logic [LDQ_SIZE-1:0]		ldq_rotated_address_valid;
	logic [LDQ_SIZE-1:0]		ldq_rotated_sleeping;
	logic [LDQ_SIZE-1:0]		ldq_rotated_executed;

	logic [STQ_SIZE-1:0][XLEN-1:0]	stq_address;
	logic [STQ_SIZE-1:0][XLEN-1:0]	stq_data;
	logic [STQ_SIZE-1:0]		stq_rotated_valid;		// is the ENTRY valid
	logic [STQ_SIZE-1:0]		stq_rotated_executed;
	logic [STQ_SIZE-1:0]		stq_rotated_committed;

	logic [$clog2(LDQ_SIZE)-1:0]	ldq_head;
	logic [$clog2(STQ_SIZE)-1:0]	stq_head;

	logic				stq_full;

	// outputs
	logic			fire_memory_op;
	logic			memory_op_type;
	logic [XLEN-1:0]	memory_address;
	logic [XLEN-1:0]	memory_data;

	logic				load_fired;
	logic [$clog2(LDQ_SIZE)-1:0]	load_fired_ldq_index;

	logic				store_fired;
	logic [$clog2(STQ_SIZE)-1:0]	store_fired_index;

	lsu_control #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) control (
		.ldq_address(ldq_address),
		.ldq_rotated_valid(ldq_rotated_valid),
		.ldq_rotated_address_valid(ldq_rotated_address_valid),
		.ldq_rotated_sleeping(ldq_rotated_sleeping),
		.ldq_rotated_executed(ldq_rotated_executed),
		.stq_address(stq_address),
		.stq_data(stq_data),
		.stq_rotated_valid(stq_rotated_valid),
		.stq_rotated_executed(stq_rotated_executed),
		.stq_rotated_committed(stq_rotated_committed),
		.ldq_head(ldq_head),
		.stq_head(stq_head),
		.stq_full(stq_full),
		.fire_memory_op(fire_memory_op),
		.memory_op_type(memory_op_type),
		.memory_address(memory_address),
		.memory_data(memory_data),
		.load_fired(load_fired),
		.load_fired_ldq_index(load_fired_ldq_index),
		.store_fired(store_fired),
		.store_fired_index(store_fired_index)
	);

	// test logic
	initial begin
		// gonna approach this by just adding loads and stores to the
		// queue and modifying them to evaluate how the control logic
		// changes which load/store it fires.

		// initial condition: both queues are empty
		# 10
		assert(fire_memory_op == 0);
		assert(memory_op_type == 0);	// not relevant since fire_memory_op is 0
		assert(memory_address == 0);	// not relevant since fire_memory_op is 0
		assert(memory_data == 0);	// not relevant since fire_memory_op is 0
		assert(load_fired == 0);
		assert(load_fired_ldq_index == 0);	// not relevant since fire_memory_op is 0
		assert(store_fired == 0);
		assert(store_fired_index == 0);	// not relevant since fire_memory_op is 0

		// start populating a store entry in the store queue
		// first it becomes valid, but it shouldn't be issued until
		// it's committed.
		stq_rotated_valid = 'h0001;
		stq_rotated_committed = 'h0000;
		stq_rotated_executed = 'h0000;
		# 10
		// only checking the control signals to keep this kinda
		// manageable
		assert(fire_memory_op == 0);
		assert(load_fired == 0);
		assert(store_fired == 0);

		// now we'll commit the store, it should be fired
		// also need to put an address here, which would have happened
		// before the store committed, but that alone won't change
		// anything in the lsu_control.
		stq_address[0] = 'h0123_4567;
		stq_data[0] = 'h89AB_CDEF;
		stq_rotated_committed = 'h0001;
		# 10
		// since the store is committed, it should be fired
		assert(fire_memory_op == 1);
		assert(memory_op_type == 1);
		assert(memory_address == 'h0123_4567);
		assert(memory_data == 'h89AB_CDEF);
		assert(load_fired == 0);
		assert(store_fired == 1);
		assert(store_fired_index == 0);	// this actually matters, we're firing the store at index 0

		// since the store was fired, the store queue will update the
		// executed bit, and the control should not fire the store
		// again
		stq_rotated_executed = 'h0001;
		# 10
		assert(fire_memory_op == 0);
		assert(load_fired == 0);
		assert(store_fired == 0);

		// going to clear the store queue and start mocking a load
		// entering the load queue
		stq_rotated_valid = 'h0000;
		stq_rotated_committed = 'h0000;
		stq_rotated_committed = 'h0000;
		stq_address[0] = 'h0000_0000;
		stq_data[0] = 'h0000_0000;

		ldq_rotated_valid = 'h0001;
		# 10
		// the load hasn't received its address yet, so it can't be
		// fired
		assert(fire_memory_op == 0);
		assert(load_fired == 0);
		assert(store_fired == 0);

		ldq_rotated_address_valid = 'h0001;
		ldq_address[0] = 'h4444_5555;
		# 10
		// now that the load has its address, has not been executed,
		// and has not been put to sleep, it should be fired
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'h4444_5555);
		assert(load_fired == 1);
		assert(load_fired_ldq_index == 0);
		assert(store_fired == 0);

		// now we'll put this load to sleep.  the
		// load_store_dep_checker will have done the actual comparison,
		// and the load_queue will ensure that if the sleeping bit is
		// set, the executed bit will be cleared
		ldq_rotated_sleeping = 'h0001;
		# 10
		// since the load is sleeping, it should not be fired
		assert(fire_memory_op == 0);
		assert(load_fired == 0);
		assert(store_fired == 0);

		// the load will be woken when the ROB tag of the dependent
		// store is seen on the CDB.  to do this, the load_queue just
		// clears the sleeping bit for that entry.
		ldq_rotated_sleeping = 'h0000;
		# 10
		// now that the load has woken and hasn't been executed, it
		// should be fired again
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'h4444_5555);
		assert(load_fired == 1);
		assert(load_fired_ldq_index == 0);
		assert(store_fired == 0);

		// if the load was fired without issue, the executed bit will
		// be set
		ldq_rotated_executed = 'h0001;
		# 10
		// since the load has already been executed, we don't want to
		// fire it again
		assert(fire_memory_op == 0);
		assert(load_fired == 0);
		assert(store_fired == 0);

		ldq_rotated_valid = 'h0000;
		ldq_rotated_sleeping = 'h0000;
		ldq_rotated_executed = 'h0000;

		// now we need to verify how the lsu_control handles multiple
		// entries in both the load and store queues

		// to start, just put one ready instruction in each queue
		ldq_head = 3;
		ldq_rotated_valid = 'h0001;
		ldq_rotated_address_valid = 'h0001;
		ldq_rotated_sleeping = 'h0000;
		ldq_rotated_executed = 'h0000;
		ldq_address[3] = 'h10AD_10AD;

		stq_head = 2;
		stq_rotated_valid = 'h0001;
		stq_rotated_committed = 'h0001;
		stq_rotated_executed = 'h0000;
		stq_address[2] = 'hABAB_CDCD;
		stq_data[2] = 'h1337_C0DE;

		# 10
		// verify that the lsu_control fired the load
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'h10AD_10AD);
		assert(memory_data == 'h1337_C0DE);
		assert(load_fired == 1);
		assert(load_fired_ldq_index == 3);
		assert(store_fired == 0);

		// if the store queue were full, we'd want to ensure that the
		// lsu_control fires the store
		stq_full = 1;
		# 10
		assert(fire_memory_op == 1);
		assert(memory_op_type == 1);
		assert(memory_address == 'hABAB_CDCD);
		assert(load_fired == 0);
		assert(store_fired == 1);
		assert(store_fired_index == 2);

		stq_full = 0;
		
		// now let's put a few more in and verify the indices that the
		// lsu_control decides to fire

		ldq_head = 3;
		ldq_rotated_valid = 'h001F;
		ldq_rotated_address_valid = 'h0007;
		ldq_rotated_sleeping = 'h0002;
		ldq_rotated_executed = 'h0001;
		ldq_address[3] = 'h0BAD_0BAD;
		ldq_address[4] = 'h0BAD_0BAD;
		ldq_address[5] = 'hCAFE_BABE;
		ldq_address[6] = 'h0BAD_0BAD;
		ldq_address[7] = 'h0BAD_0BAD;

		stq_head = 2;
		stq_rotated_valid = 'h0007;
		stq_rotated_committed = 'h0003;
		stq_rotated_executed = 'h0001;
		stq_address[2] = 'h0BAD_0BAD;
		stq_address[3] = 'hDEAD_BEEF;
		stq_address[4] = 'h0BAD_0BAD;
		stq_data[2] = 'h0BAD_0BAD;
		stq_data[3] = 'h1337_C0DE;
		stq_data[4] = 'h0BAD_0BAD;

		# 10
		// the load at index 5 is the only valid load to fire, and the
		// store at index 3 is the only valid store to fire.  since
		// the store queue isn't full, the load at index 5 should be
		// fired.
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'hCAFE_BABE);
		assert(load_fired == 1);
		assert(load_fired_ldq_index == 5);
		assert(store_fired == 0);

		// now I'll make the loads at indices 6 and 7 also valid, but
		// load 5 should still be fired
		ldq_rotated_address_valid = 'h001F;
		# 10
		assert(fire_memory_op == 1);
		assert(memory_op_type == 0);
		assert(memory_address == 'hCAFE_BABE);
		assert(load_fired == 1);
		assert(load_fired_ldq_index == 5);
		assert(store_fired == 0);

		// now to make the the lsu_control prioritize issuing a store
		// over a load, we'll set stq_full
		stq_full = 1;
		# 10
		// verify that the store at index 3 is fired
		assert(fire_memory_op == 1);
		assert(memory_op_type == 1);
		assert(memory_address == 'hDEAD_BEEF);
		assert(memory_data == 'h1337_C0DE);
		assert(load_fired == 0);
		assert(store_fired == 1);
		assert(store_fired_index == 3);

		// now we'll make the store at index 4 also valid, but still
		// ensure that the older load at index 3 is fired
		stq_rotated_committed = 'h0007;
		# 10
		assert(fire_memory_op == 1);
		assert(memory_op_type == 1);
		assert(memory_address == 'hDEAD_BEEF);
		assert(memory_data == 'h1337_C0DE);
		assert(load_fired == 0);
		assert(store_fired == 1);
		assert(store_fired_index == 3);

		$display("All assertions passed.");
		$finish();
	end
endmodule
