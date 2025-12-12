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
	logic				agu_address_valid;
	logic [XLEN-1:0]		agu_address_data;
	logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag;
	logic				load_executed;
	logic [ROB_TAG_WIDTH-1:0]	load_executed_rob_tag;
	logic				load_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	load_succeeded_rob_tag;
	logic				set_store_mask;
	logic [STQ_SIZE-1:0]		store_mask;
	logic [$clog2(LDQ_SIZE)-1:0]	store_mask_index;
	logic				rob_commit;
	logic				rob_commit_type;
	logic				set_order_fail;
	logic [$clog2(LDQ_SIZE)-1:0]	order_fail_index;

	load_queue_entry [15:0]		load_queue_entries;

	load_queue /* #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) */ ldq (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),
		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),
		.load_executed(load_executed),
		.load_executed_rob_tag(load_executed_rob_tag),
		.load_succeeded(load_succeeded),
		.load_succeeded_rob_tag(load_succeeded_rob_tag),
		.set_store_mask(set_store_mask),
		.store_mask(store_mask),
		.store_mask_index(store_mask_index),
		.rob_commit(rob_commit),
		.rob_commit_type(rob_commit_type),
		.set_order_fail(set_order_fail),
		.order_fail_index(order_fail_index),
		.load_queue_entries(load_queue_entries)
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
		$display("The queue has been reset, all entries should be empty.");
		display_signals(0);

		alloc_ldq_entry = 1;
		rob_tag_in = 19;
		# 10
		$display("The first LDQ entry has been allocated.");
		display_signals(0);

		alloc_ldq_entry = 0;
		rob_tag_in = 0;
		agu_address_valid = 1;
		agu_address_data = 42;
		# 10
		$display("An address is valid and active on the bus, but the ROB tag does not match");
		$display("the ROB tag stored in the first queue entry.  The address should not be");
		$display("updated.");
		display_signals(0);

		agu_address_rob_tag = 19;
		# 10
		$display("The address ROB tag now matches the ROB tag stored in the first queue entry.");
		$display("Verify the address is valid and the address is 42.");
		display_signals(0);

		/*
		 * this test is by no means comprehensive, nor even complete
		 * for one entry.  I just wanted to validate compilation and
		 * a handful of basic features.
		 * TODO: would love to finish this test
		 */
		$finish();
	end

	task display_signals(input integer ldq_index);
		$display("-------------------------------------------");
		$display("DISPLAYING LDQ ENTRY AT INDEX %d", ldq_index);
		$display("valid: %d", load_queue_entries[ldq_index].valid);
		$display("address: %d, address_valid: %d", load_queue_entries[ldq_index].address, load_queue_entries[ldq_index].address_valid);
		$display("executed: %d, succeeded: %d, order_fail: %d", load_queue_entries[ldq_index].executed, load_queue_entries[ldq_index].succeeded, load_queue_entries[ldq_index].order_fail);
		$display("store_mask: %d", load_queue_entries[ldq_index].store_mask);
		$display("forward_stq_data: %d, forward_stq_index: %d", load_queue_entries[ldq_index].forward_stq_data, load_queue_entries[ldq_index].forward_stq_index);
		$display("rob_tag: %d", load_queue_entries[ldq_index].rob_tag);
		$display("===========================================");
	endtask
endmodule
