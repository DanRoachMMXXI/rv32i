module test_order_failure_detector;
	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH=32;
	localparam LDQ_SIZE=16;
	localparam STQ_SIZE=16;

	// load queue signals
	logic [LDQ_SIZE-1:0]				ldq_valid;
	logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address;
	logic [LDQ_SIZE-1:0]				ldq_succeeded;
	logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask;
	logic [LDQ_SIZE-1:0]				ldq_forwarded;
	logic [LDQ_SIZE-1:0][$clog2(STQ_SIZE)-1:0]	ldq_forward_stq_index;

	// store queue signals
	logic [STQ_SIZE-1:0][XLEN-1:0]			stq_address;
	logic [$clog2(STQ_SIZE)-1:0]			stq_head;

	// control logic (?) signals
	logic						stq_commit;
	logic [$clog2(STQ_SIZE)-1:0]			stq_commit_index;

	// output
	logic [LDQ_SIZE-1:0]				order_failures;

	order_failure_detector #(.XLEN(XLEN), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) ofd (
		.ldq_valid(ldq_valid),
		.ldq_address(ldq_address),
		.ldq_succeeded(ldq_succeeded),
		.ldq_store_mask(ldq_store_mask),
		.ldq_forwarded(ldq_forwarded),
		.ldq_forward_stq_index(ldq_forward_stq_index),
		.stq_address(stq_address),
		.stq_head(stq_head),
		.stq_commit(stq_commit),
		.stq_commit_index(stq_commit_index),
		.order_failures(order_failures)
	);

	// test logic
	initial begin
		// TODO write test logic for order_failure_detector
		// just leaving this as the setup to do so for now
	end
endmodule
