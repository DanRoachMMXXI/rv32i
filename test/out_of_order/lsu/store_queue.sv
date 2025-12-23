module test_store_queue;
	import lsu_pkg::*;

	localparam XLEN = 32;
	localparam ROB_TAG_WIDTH=32;
	localparam LDQ_SIZE=16;
	localparam STQ_SIZE=16;

	logic clk = 0;
	logic reset = 0;

	logic	alloc_stq_entry;
	logic [ROB_TAG_WIDTH-1:0]	rob_tag_in;
	logic [XLEN-1:0]		store_data_in;
	logic				store_data_in_valid;

	logic				agu_address_valid;
	logic [XLEN-1:0]		agu_address_data;
	logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag;

	logic				rob_commit;
	logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag;

	logic				store_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	store_succeeded_rob_tag;

	logic				cdb_active;
	logic [XLEN-1:0]		cdb_data;
	logic [ROB_TAG_WIDTH-1:0]	cdb_tag;

	store_queue_entry [STQ_SIZE-1:0]	store_queue_entries;
	logic [$clog2(STQ_SIZE)-1:0]		head;
	logic [$clog2(STQ_SIZE)-1:0]		tail;
	logic					full;

	store_queue stq (
		.clk(clk),
		.reset(reset),
		.alloc_stq_entry(alloc_stq_entry),
		.rob_tag_in(rob_tag_in),
		.store_data_in(store_data_in),
		.store_data_in_valid(store_data_in_valid),

		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),

		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),

		.store_succeeded(store_succeeded),
		.store_succeeded_rob_tag(store_succeeded_rob_tag),

		.cdb_active(cdb_active),
		.cdb_data(cdb_data),
		.cdb_tag(cdb_tag),

		.store_queue_entries(store_queue_entries),
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
		assert(store_queue_entries[0].valid == 0);

		// allocate a store queue entry that doesn't have data ready
		alloc_stq_entry = 1;
		rob_tag_in = 19;
		# 10
		assert(store_queue_entries[0].valid == 1);
		assert(store_queue_entries[0].rob_tag == 19);
		assert(store_queue_entries[0].data_valid == 0);
		assert(store_queue_entries[0].address_valid == 0);
		// assert circular buffer pointers are correct
		assert(head == 0);
		assert(tail == 1);

		// allocate another entry, but with data provided initially
		// simultaneously, let the address for the first entry appear
		// on the AGU address bus
		rob_tag_in = 21;
		store_data_in = 'h11262025;
		store_data_in_valid = 1;
		agu_address_valid = 1;
		agu_address_data = 'hBA5EDCA7;
		agu_address_rob_tag = 19;
		# 10
		// validate new entry was allocated
		assert(store_queue_entries[1].valid == 1);
		assert(store_queue_entries[1].rob_tag == 21);
		assert(store_queue_entries[1].data_valid == 1);
		assert(store_queue_entries[1].data == 'h11262025);
		assert(store_queue_entries[1].address_valid == 0);
		// validate address for index 0 was stored
		assert(store_queue_entries[0].address_valid == 1);
		assert(store_queue_entries[0].address == 'hBA5EDCA7);
		// assert circular buffer pointers are correct
		assert(head == 0);
		assert(tail == 2);

		// reset entry allocation signals
		alloc_stq_entry = 0;
		rob_tag_in = 0;
		store_data_in_valid = 0;
		store_data_in = 0;
		// second address appears on AGU bus for index 1
		agu_address_data = 'hDEADBEEF;
		agu_address_rob_tag = 21;
		# 10
		assert(store_queue_entries[1].address_valid == 1);
		assert(store_queue_entries[1].address == 'hDEADBEEF);

		// reset AGU signals
		agu_address_valid = 0;
		agu_address_data = 0;
		agu_address_rob_tag = 0;

		// so now, index 1 is ready to fkn go, index 0 is still
		// waiting for data on the CDB
		cdb_active = 1;
		cdb_data = 'h01234567;
		cdb_tag = 19;
		# 10
		assert(store_queue_entries[0].data_valid == 1);
		assert(store_queue_entries[0].data == 'h01234567);

		cdb_active = 0;
		cdb_data = 0;
		cdb_tag = 0;

		// now both entries are ready to commit.
		rob_commit = 1;
		rob_commit_tag = 19;
		# 10
		assert(store_queue_entries[0].committed == 1);
		assert(store_queue_entries[1].committed == 0);

		rob_commit_tag = 21;
		# 10
		assert(store_queue_entries[1].committed == 1);

		rob_commit = 0;
		rob_commit_tag = 0;

		// now both entries are committed
		// some other component would route these to the store, the
		// store queue just needs to wait to see that the stores with
		// these ROB tags succeeded on the input ports

		store_succeeded = 1;
		store_succeeded_rob_tag = 19;
		# 10
		// The first cycle, the succeeded bit will be set.  The next
		// cycle, the store queue will see that the store is succeeded,
		// free the entry, and increment the head pointer.
		assert(store_queue_entries[0].succeeded == 1);
		assert(store_queue_entries[1].succeeded == 0);

		store_succeeded_rob_tag = 21;
		# 10
		// First entry should be cleared
		assert(store_queue_entries[0].valid == 0);
		assert(head == 1);
		// the second entry should have its succeeded bit set.
		assert(store_queue_entries[1].succeeded == 1);

		store_succeeded = 0;
		store_succeeded_rob_tag = 0;
		# 10
		// now the second entry should be cleared and the head pointer
		// should have incremented
		assert(store_queue_entries[1].valid == 0);
		assert(head == 2);

		$display("All assertions passed.");
		$finish();
	end
endmodule
