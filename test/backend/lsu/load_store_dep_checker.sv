module test_load_store_dep_checker;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH=32;
	localparam LDQ_SIZE=16;
	localparam STQ_SIZE=16;

	// load queue buffer signals
	logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address;
	logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask;

	// store queue buffer signals
	logic [STQ_SIZE-1:0]				stq_valid;	// is the ENTRY valid
	logic [STQ_SIZE-1:0] [XLEN-1:0]			stq_address;
	logic [STQ_SIZE-1:0]				stq_address_valid;
	logic [STQ_SIZE-1:0]				stq_data_valid;	// is the data for the store present in the entry?
	logic [STQ_SIZE-1:0] [ROB_TAG_WIDTH-1:0]	stq_rob_tag;

	logic [$clog2(STQ_SIZE)-1:0]			stq_head;

	logic						load_fired;
	logic [$clog2(LDQ_SIZE)-1:0]			load_fired_ldq_index;

	logic				kill_mem_req;
	logic				load_fired_sleep;
	logic [ROB_TAG_WIDTH-1:0]	load_fired_sleep_rob_tag;
	logic				forward;
	logic [$clog2(STQ_SIZE)-1:0]	stq_forward_index;

	load_store_dep_checker #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) lsdc (
		.ldq_address(ldq_address),
		.ldq_store_mask(ldq_store_mask),
		.stq_valid(stq_valid),
		.stq_address(stq_address),
		.stq_address_valid(stq_address_valid),
		.stq_data_valid(stq_data_valid),
		.stq_rob_tag(stq_rob_tag),

		.stq_head(stq_head),
		.load_fired(load_fired),
		.load_fired_ldq_index(load_fired_ldq_index),

		// outputs
		.kill_mem_req(kill_mem_req),
		.sleep(load_fired_sleep),
		.sleep_rob_tag(load_fired_sleep_rob_tag),
		.forward(forward),
		.stq_forward_index(stq_forward_index)
	);

	// test logic
	initial begin
		load_fired = 1;
		load_fired_ldq_index = 12;
		ldq_address[load_fired_ldq_index] = 'hDEADBEEF;
		ldq_store_mask[load_fired_ldq_index] = 'hFFFF;

		# 10
		// validate signals on an empty store queue
		assert(kill_mem_req == 0);
		assert(load_fired_sleep == 0);
		assert(load_fired_sleep_rob_tag == 0);
		assert(forward == 0);
		assert(stq_forward_index == 0);

		// populate the store queue
		stq_valid = 'h0FF0;
		stq_head = 4;
		// populate the addresses of the store queue
		stq_address[4] = 'hFFFFFFFF;
		stq_address[5] = 'hDEADBEEF;	// dependent store
		stq_address[6] = 'h01234567;
		stq_address[7] = 'hDEADBEEF;	// dependent store
		stq_address[8] = 'h00C0FFEE;
		stq_address[9] = 'hFEDCBA98;
		stq_address[10] = 'hDEADBEEF;	// dependent store
		stq_address[11] = 'h00000000;
		stq_address_valid = 'h07F0;	// the youngest store has not got its address yet
		stq_data_valid = 'h0190;

		// populate the ROB tags of the dependent stores
		stq_rob_tag[5] = 13;
		stq_rob_tag[7] = 20;
		stq_rob_tag[10] = 34;

		# 10	// delay just allows signals to assert values on the output pins

		// we're expecting this load to sleep, since the youngest
		// dependent store (index 10) does not have its data yet.
		assert(kill_mem_req == 1);
		assert(load_fired_sleep == 1);
		assert(load_fired_sleep_rob_tag == 34);
		assert(forward == 0);
		assert(stq_forward_index == 0);	// value here isn't really important

		// let's add another valid store at the end of the queue that
		// has data ready to forward
		stq_valid[12] = 1;
		stq_address_valid[12] = 1;
		stq_address[12] = 'hDEADBEEF;
		stq_data_valid[12] = 1;
		stq_rob_tag[12] = 40;	// shouldn't be used anyways

		# 10

		// now we're expecting the dependency checker to forward the
		// data
		assert(kill_mem_req == 1);
		assert(load_fired_sleep == 0);
		assert(load_fired_sleep_rob_tag == 0);	// arbitrary, just the default value it's programmed to
		assert(forward == 1);
		assert(stq_forward_index == 12);

		$display("All assertions passed.");
		$finish();
	end
endmodule
