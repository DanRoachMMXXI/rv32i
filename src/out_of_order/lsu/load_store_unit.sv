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
	input logic [ROB_TAG_WIDTH-1:0]	rob_tag_in,
	input logic [XLEN-1:0]		store_data,	// data to be stored in the STQ if it's available
	// store_data_valid determines if the data on store_data should
	// be stored in the STQ 1 = use store_data, 0 = wait for it on CDB
	input logic			store_data_valid,

	input logic			agu_address_valid,
	input logic [XLEN-1:0]		agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag,
	
	// these are signals from the reorder buffer to manage entries in the
	// LDQ and STQ.  On commit, the LDQ frees the entry (I think), and the
	// STQ will attempt to write the value to memory.
	input logic			rob_commit,	// boolean - are we committing
	input logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag,	// ROB tag of entry to commit
	// not taking the data from the ROB for stores cause I am
	// assuming the data is already in the store queue

	input logic cdb_active,
	input logic [XLEN-1:0] cdb_data,
	input logic [ROB_TAG_WIDTH-1:0] cdb_tag,

	// I don't think an address needs to be associated with this, it's
	// just whatever memory request is being put out to the L1 cache this
	// clock cycle
	output logic kill_mem_req
	);

	load_queue_entry [LDQ_SIZE-1:0] load_queue_entries;
	store_queue_entry [STQ_SIZE-1:0] store_queue_entries;

	logic [$clog2(LDQ_SIZE)-1:0] ldq_head;
	logic [$clog2(STQ_SIZE)-1:0] stq_head;

	logic ldq_full;
	logic stq_full;

	logic [STQ_SIZE-1:0] store_mask;

	logic [$clog2(LDQ_SIZE)-1:0] ldq_mem_stage_index;

	logic [LDQ_SIZE-1:0] order_failures;

	logic forward;
	logic [$clog2(STQ_SIZE)-1:0] stq_forward_index;

	load_queue ldq (
		.clk(clk),
		.reset(reset),

		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),
		.store_mask(store_mask),

		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),

		// I think this will come from the control logic inside the LSU
		.load_executed(),
		// TODO: get rid of this and use the ldq_mem_stage_index
		// selected by the control logic, that is the load being
		// executed.
		.load_executed_rob_tag(),

		// I think this will come from the memory unit outside the LSU
		.load_succeeded(),
		.load_succeeded_rob_tag(),

		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),

		.order_failures(order_failures),

		.load_queue_entries(load_queue_entries),
		.head(ldq_head),
		.tail(),
		.full(ldq_full)
	);

	store_queue stq (
		.clk(clk),
		.reset(reset),

		.alloc_stq_entry(alloc_stq_entry),
		.rob_tag_in(rob_tag_in),
		.store_data_in(store_data),
		.store_data_in_valid(store_data_valid),

		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),

		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),

		// I think this will come from the memory unit outside the LSU
		.store_succeeded(),
		.store_succeeded_rob_tag(),

		.cdb_active(cdb_active),
		.cdb_data(cdb_data),
		.cdb_tag(cdb_tag),

		.store_queue_entries(store_queue_entries),
		.head(stq_head),
		.tail(),
		.full(stq_full)
	);

	// combinational component
	load_store_dep_checker lsdc (
		.load_queue_entries(load_queue_entries),
		.store_queue_entries(store_queue_entries),
		.stq_head(stq_head),
		// I think this comes from control logic
		.ldq_mem_stage_index(ldq_mem_stage_index),

		// outputs
		.kill_mem_req(kill_mem_req),
		.forward(forward),
		.stq_forward_index(stq_forward_index)
	);

	// combinational component
	order_failure_detector ofd (
		.load_queue_entries(load_queue_entries),
		.store_queue_entries(store_queue_entries),
		.stq_head(stq_head),
		// comes from control logic, finds the index of the most
		// recently committed store (should just be head?)
		.stq_commit(),
		.stq_commit_index(),

		// output
		.order_failures(order_failures)
	);
endmodule
