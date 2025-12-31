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
		// I think this comes from control logic
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
		// TODO write test logic for load_store_dep_checker
		// just leaving this as the setup to do so for now
	end
endmodule
