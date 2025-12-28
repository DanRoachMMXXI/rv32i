module test_store_queue;
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

	logic [STQ_SIZE-1:0] stq_valid;		// is the ENTRY valid
	logic [STQ_SIZE-1:0] [XLEN-1:0] stq_address;
	logic [STQ_SIZE-1:0] stq_address_valid;
	logic [STQ_SIZE-1:0] [XLEN-1:0] stq_data;
	logic [STQ_SIZE-1:0] stq_data_valid;	// is the data for the store present in the entry?
	logic [STQ_SIZE-1:0] stq_committed;
	logic [STQ_SIZE-1:0] stq_succeeded;
	logic [STQ_SIZE-1:0] [ROB_TAG_WIDTH-1:0] stq_rob_tag;

	logic [$clog2(STQ_SIZE)-1:0]		head;
	logic [$clog2(STQ_SIZE)-1:0]		tail;
	logic					full;

	store_queue #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .STQ_SIZE(STQ_SIZE)) stq (
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

		.stq_valid(stq_valid),
		.stq_address(stq_address),
		.stq_address_valid(stq_address_valid),
		.stq_data(stq_data),
		.stq_data_valid(stq_data_valid),
		.stq_committed(stq_committed),
		.stq_succeeded(stq_succeeded),
		.stq_rob_tag(stq_rob_tag),

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
		assert(stq_valid[0] == 0);

		// allocate a store queue entry that doesn't have data ready
		alloc_stq_entry = 1;
		rob_tag_in = 19;
		# 10
		assert(stq_valid[0] == 1);
		assert(stq_rob_tag[0] == 19);
		assert(stq_data_valid[0] == 0);
		assert(stq_address_valid[0] == 0);
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
		assert(stq_valid[1] == 1);
		assert(stq_rob_tag[1] == 21);
		assert(stq_data_valid[1] == 1);
		assert(stq_data[1] == 'h11262025);
		assert(stq_address_valid[1] == 0);
		// validate address for index 0 was stored
		assert(stq_address_valid[0] == 1);
		assert(stq_address[0] == 'hBA5EDCA7);
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
		assert(stq_address_valid[1] == 1);
		assert(stq_address[1] == 'hDEADBEEF);

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
		assert(stq_data_valid[0] == 1);
		assert(stq_data[0] == 'h01234567);

		cdb_active = 0;
		cdb_data = 0;
		cdb_tag = 0;

		// now both entries are ready to commit.
		rob_commit = 1;
		rob_commit_tag = 19;
		# 10
		assert(stq_committed[0] == 1);
		assert(stq_committed[1] == 0);

		rob_commit_tag = 21;
		# 10
		assert(stq_committed[1] == 1);

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
		assert(stq_succeeded[0] == 1);
		assert(stq_succeeded[1] == 0);

		store_succeeded_rob_tag = 21;
		# 10
		// First entry should be cleared
		assert(stq_valid[0] == 0);
		assert(head == 1);
		// the second entry should have its succeeded bit set.
		assert(stq_succeeded[1] == 1);

		store_succeeded = 0;
		store_succeeded_rob_tag = 0;
		# 10
		// now the second entry should be cleared and the head pointer
		// should have incremented
		assert(stq_valid[1] == 0);
		assert(head == 2);

		$display("All assertions passed.");
		$finish();
	end
endmodule
