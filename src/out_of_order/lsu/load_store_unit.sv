module load_store_unit
	import lsu_pkg::*;
	(
	input logic clk,
	input logic reset,

	// I assume these will be set on the same cycle that the AGU
	// reservation stations are reserved, so that it's guaranteed the
	// buffer entries are already allocated once the address is computed
	input logic alloc_ldq_entry,
	input logic alloc_stq_entry,
	// rob_tag_in is stored in the buffer entry
	// allocated by alloc_ldq_entry and alloc_stq_entry
	input logic [ROB_TAG_WIDTH-1:0] rob_tag_in,
	input logic [XLEN-1:0] store_data,	// data to be stored in the STQ if it's available
	input logic store_data_valid,	// determines if the data on store_data should be stored in the STQ
					// 1 = use store_data, 0 = wait for it on CDB
	
	// these are signals from the reorder buffer to manage entries in the
	// LDQ and STQ.  On commit, the LDQ frees the entry (I think), and the
	// STQ will attempt to write the value to memory.
	input logic rob_commit,		// boolean - are we committing
	input logic rob_commit_type,	// 0 to commit a load, 1 to commit a store, values given arbitrarily
	// input logic [XLEN-1:0] rob_commit_address,	// which address are we committing?
	// assuming the data is already in the STQ

	input logic cdb_active,
	input logic [XLEN-1:0] cdb_data,
	input logic [ROB_TAG_WIDTH-1:0] cdb_tag
	);

	load_queue_entry [0:LDQ_SIZE-1] load_queue_entries;
	store_queue_entry [0:STQ_SIZE-1] store_queue_entries;

	logic [STQ_SIZE-1:0] store_mask;

	load_queue ldq (
		.clk(clk),
		.reset(reset),

		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),

		.agu_address_valid(),
		.agu_address_data(),
		.agu_address_rob_tag(),

		.load_executed(),
		.load_executed_rob_tag(),

		.load_succeeded(),
		.load_succeeded_rob_tag(),

		.set_store_mask(),
		.store_mask(),
		.store_mask_index(),

		.rob_commit(rob_commit),
		.rob_commit_type(rob_commit_type),

		.set_order_fail(),
		.order_fail_index(),

		.load_queue_entries(load_queue_entries)
	);

	store_queue stq (
		.clk(clk),
		.reset(reset),

		.alloc_stq_entry(alloc_stq_entry),
		.rob_tag_in(rob_tag_in),

		.agu_address_valid(),
		.agu_address_data(),
		.agu_address_rob_tag(),

		.rob_commit(rob_commit),
		.rob_commit_type(rob_commit_type),

		.store_succeeded(),
		.store_succeeded_rob_tag(),

		.cdb_active(),
		.cdb_data(),
		.cdb_tag(),

		.store_queue_entries(store_queue_entries)
	);

	searcher searcher (
		// assuming no clk or reset
		.load_queue_entries(load_queue_entries),
		.store_queue_entries(store_queue_entries)
	);
endmodule
