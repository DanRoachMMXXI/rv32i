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

	// debug output
	logic [LDQ_SIZE-1:0]	fwd_index_older_than_stq_commit_index;

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
		.order_failures(order_failures),
		.fwd_index_older_than_stq_commit_index(fwd_index_older_than_stq_commit_index)
	);

	// test logic
	initial begin
		stq_commit = 1;
		stq_commit_index = 12;
		stq_head = 7;
		stq_address[stq_commit_index] = 'hDEADBEEF;

		// in this setup there are five matching loads
		// index 5:
		// succeeded = 0, store_mask[12] = 0
		// index 7:
		// succeeded = 1, store_mask[12] = 0
		// index 9:
		// succeeded = 1, store_mask[12] = 1, forward = 0
		// index 12:
		// succeeded = 1, store_mask[12] = 1, forward = 1
		// forward_stq_index = old (9)
		// index 13:
		// succeeded = 1, store_mask[12] = 1, forward = 1
		// forward_stq_index = correct (12)

		// note the load at index 5 is kinda unrealistic, it would
		// have succeeded if it wasn't dependent on this load,
		// otherwise it's already an ordering failure that would have
		// been detected before this clock cycle
		ldq_valid = 'h3FF8;	// head at index 3
		// populate the addresses
		ldq_address[3] = 'h33333333;
		ldq_address[4] = 'h44444444;
		ldq_address[5] = 'hDEADBEEF;	// matching address
		ldq_address[6] = 'h66666666;
		ldq_address[7] = 'hDEADBEEF;	// matching address
		ldq_address[8] = 'h88888888;
		ldq_address[9] = 'hDEADBEEF;	// matching address
		ldq_address[10] = 'hAAAAAAAA;
		ldq_address[11] = 'hBBBBBBBB;
		ldq_address[12] = 'hDEADBEEF;	// matching address
		ldq_address[13] = 'hDEADBEEF;	// matching address
		ldq_succeeded = 'h33C8;
		// set the store mask bit of the dependent stores, making
		// loads 9, 12, and 13 dependent on store 12
		ldq_store_mask[5][stq_commit_index] = 0;
		ldq_store_mask[7][stq_commit_index] = 0;
		ldq_store_mask[9][stq_commit_index] = 1;
		ldq_store_mask[12][stq_commit_index] = 1;
		ldq_store_mask[13][stq_commit_index] = 1;

		ldq_forwarded = 'h3000;
		ldq_forward_stq_index[12] = 9;	// forwarded from an older store
		ldq_forward_stq_index[13] = stq_commit_index;	// forwarded from the currently committing store

		# 10

		$display("order_failures: 0x%0h", order_failures);
		$display("fwd_index_older_than_stq_commit_index: 0x%0h", fwd_index_older_than_stq_commit_index);
		$display("ldq_forward_stq_index[12]: %d", ldq_forward_stq_index[12]);
		$display("stq_commit_index: %d", stq_commit_index);

		$display("ldq_valid[12]: %d", ldq_valid[12]);
		$display("ldq_succeeded[12]: %d", ldq_succeeded[12]);
		$display("ldq_store_mask[12][stq_commit_index]: %d", ldq_store_mask[12][stq_commit_index]);
		$display("ldq_address[12]: 0x%0h", ldq_address[12]);
		$display("stq_address[stq_commit_index]: 0x%0h", stq_address[stq_commit_index]);
		$display("fwd_index_older_than_stq_commit_index[12]: %d", fwd_index_older_than_stq_commit_index[12]);

		assert(order_failures == 'h1200);

		$display("All assertions passed.");
		$finish();
	end
endmodule
