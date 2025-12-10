module load_store_unit #(parameter XLEN=32, parameter ROB_TAG_WIDTH, parameter LDQ_SIZE, parameter STQ_SIZE) (
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
	);

	load_queue_entry [0:LDQ_SIZE-1] load_queue_entries;
	store_queue_entry [0:STQ_SIZE-1] store_queue_entries;

	// I am pretty sure the searcher needs to update every store_mask
	// every cycle, because one store completing can affect multiple
	// loads' store masks
	// there are LDQ_SIZE packed STQ_SIZE-bit signals
	// ex: [n_bytes-1:0][7:0] n_byte_packed_array;
	logic [LDQ_SIZE-1:0][STQ_SIZE-1:0] store_masks;

	load_queue #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE)) load_queue (
		.clk(clk),
		.reset(reset),

		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),

		// TODO: AGU signals

		.store_masks(store_masks),

		.rob_commit(rob_commit),
		.rob_commit_type(rob_commit_type),

		.load_queue_entries(load_queue_entries)
		);

	store_queue #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .STQ_SIZE(STQ_SIZE)) store_queue (
		.clk(clk),
		.reset(reset),

		.alloc_stq_entry(alloc_stq_entry),
		.rob_tag_in(rob_tag_in),

		.rob_commit(rob_commit),
		.rob_commit_type(rob_commit_type),

		.store_queue_entries(store_queue_entries)
		);

	searcher #(.XLEN(XLEN), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) searcher (
		// assuming no clk or reset
		.load_queue_entries(load_queue_entries),
		.store_queue_entries(store_queue_entries)

		.store_masks(store_masks),
		);
endmodule
