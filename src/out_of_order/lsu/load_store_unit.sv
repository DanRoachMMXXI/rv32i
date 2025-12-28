module load_store_unit #(parameter XLEN=32, parameter ROB_TAG_WIDTH=32, parameter LDQ_SIZE=32, parameter STQ_SIZE=32) (
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

	// these signals are what I AM ASSUMING come from memory to indicate
	// a load succeeded.  something needs to tell the load queue that
	// the load has succeeded so it can remove the entry from the queue.
	input logic load_succeeded,
	input logic [ROB_TAG_WIDTH-1:0] load_succeeded_rob_tag,

	// these signals are what I AM ASSUMING come from memory to indicate
	// a store succeeded.  something needs to tell the store queue that
	// the store has succeeded so it can remove the entry from the queue.
	input logic store_succeeded,
	input logic [ROB_TAG_WIDTH-1:0] store_succeeded_rob_tag,

	input logic cdb_active,
	input logic [XLEN-1:0] cdb_data,
	input logic [ROB_TAG_WIDTH-1:0] cdb_tag,

	// I don't think an address needs to be associated with this, it's
	// just whatever memory request is being put out to the L1 cache this
	// clock cycle
	output logic kill_mem_req
	);

	// load queue buffer signals
	logic [LDQ_SIZE-1:0]				ldq_valid;
	logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address;
	logic [LDQ_SIZE-1:0]				ldq_address_valid;
	logic [LDQ_SIZE-1:0]				ldq_executed;
	logic [LDQ_SIZE-1:0]				ldq_succeeded;
	logic [LDQ_SIZE-1:0]				ldq_committed;
	logic [LDQ_SIZE-1:0]				ldq_order_fail;
	logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask;
	logic [LDQ_SIZE-1:0]				ldq_forward_stq_data;
	logic [LDQ_SIZE-1:0][$clog2(STQ_SIZE)-1:0]	ldq_forward_stq_index;
	logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag;

	// store queue buffer signals
	logic [STQ_SIZE-1:0] stq_valid;		// is the ENTRY valid
	logic [STQ_SIZE-1:0] [XLEN-1:0] stq_address;
	logic [STQ_SIZE-1:0] stq_address_valid;
	logic [STQ_SIZE-1:0] [XLEN-1:0] stq_data;
	logic [STQ_SIZE-1:0] stq_data_valid;	// is the data for the store present in the entry?
	logic [STQ_SIZE-1:0] stq_committed;
	logic [STQ_SIZE-1:0] stq_succeeded;
	logic [STQ_SIZE-1:0] [ROB_TAG_WIDTH-1:0] stq_rob_tag;

	logic [$clog2(LDQ_SIZE)-1:0] ldq_head;
	logic [$clog2(STQ_SIZE)-1:0] stq_head;

	// ldq_full - is the load queue full?
	// produced by: load_queue
	// consumed by: output
	logic ldq_full;

	// stq_full - is the store queue full?
	// produced by: store_queue
	// consumed by: lsu_control, output
	logic stq_full;

	// load_executed - is a load entering execution this clock cycle?
	// produced by: lsu_control
	// consumed by: load_queue
	logic load_executed;

	// ldq_mem_stage_index - LDQ index of the load being executed this cycle
	// produced by: lsu_control
	// consumed by: load_queue, load_store_dep_checker
	logic [$clog2(LDQ_SIZE)-1:0] ldq_mem_stage_index;

	// order_failures - bitmask of load queue entries that have
	// experienced an ordering failure with respect to the store that
	// committed (TODO when?)
	// produced by: order_failure_detector
	// consumed by: load_queue
	// TODO: this will need to store an exception in the ROB
	logic [LDQ_SIZE-1:0] order_failures;

	// forward - is the data for the currently executing load being
	// forwarded from the store queue?
	// produced by: load_store_dep_checker
	// consumed by: load_queue
	logic forward;
	logic [$clog2(STQ_SIZE)-1:0] stq_forward_index;

	// stq_entry_fired - did the store queue just fire a store to memory?
	// needed to clear bits in the store mask
	// produced by: TODO ???
	// consumed by: load_queue
	logic stq_entry_fired;
	logic [$clog2(STQ_SIZE)-1:0] stq_entry_fired_index;

	load_queue #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) ldq (
		.clk(clk),
		.reset(reset),

		.alloc_ldq_entry(alloc_ldq_entry),
		.rob_tag_in(rob_tag_in),
		.store_mask(stq_valid),

		.agu_address_valid(agu_address_valid),
		.agu_address_data(agu_address_data),
		.agu_address_rob_tag(agu_address_rob_tag),

		.load_executed(load_executed),
		.load_executed_index(ldq_mem_stage_index),

		.load_succeeded(load_succeeded),
		.load_succeeded_rob_tag(load_succeeded_rob_tag),

		.rob_commit(rob_commit),
		.rob_commit_tag(rob_commit_tag),

		.order_failures(order_failures),

		.stq_entry_fired(stq_entry_fired),
		.stq_entry_fired_index(stq_entry_fired_index),

		.ldq_valid(ldq_valid),
		.ldq_address(ldq_address),
		.ldq_address_valid(ldq_address_valid),
		.ldq_executed(ldq_executed),
		.ldq_succeeded(ldq_succeeded),
		.ldq_committed(ldq_committed),
		.ldq_order_fail(ldq_order_fail),
		.ldq_store_mask(ldq_store_mask),
		.ldq_forward_stq_data(ldq_forward_stq_data),
		.ldq_forward_stq_index(ldq_forward_stq_index),
		.ldq_rob_tag(ldq_rob_tag),

		.head(ldq_head),
		.tail(),
		.full(ldq_full)
	);

	store_queue #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .STQ_SIZE(STQ_SIZE)) stq (
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

		.head(stq_head),
		.tail(),
		.full(stq_full)
	);

	// combinational component
	load_store_dep_checker #(.XLEN(XLEN), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) lsdc (
		.ldq_address(ldq_address),
		.ldq_store_mask(ldq_store_mask),
		.stq_valid(stq_valid),
		.stq_address(stq_address),
		.stq_address_valid(stq_address_valid),
		.stq_data_valid(stq_data_valid),

		.stq_head(stq_head),
		// I think this comes from control logic
		.ldq_mem_stage_index(ldq_mem_stage_index),

		// outputs
		.kill_mem_req(kill_mem_req),
		.forward(forward),
		.stq_forward_index(stq_forward_index)
	);

	// combinational component
	order_failure_detector #(.XLEN(XLEN), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) ofd (
		// load queue signals
		.ldq_valid(ldq_valid),
		.ldq_address(ldq_address),
		.ldq_succeeded(ldq_succeeded),
		.ldq_store_mask(ldq_store_mask),
		.ldq_forward_stq_data(ldq_forward_stq_data),
		.ldq_forward_stq_index(ldq_forward_stq_index),

		// store queue signals
		.stq_address(stq_address),

		.stq_head(stq_head),
		// comes from control logic, finds the index of the most
		// recently committed store (should just be head?)
		.stq_commit(),
		.stq_commit_index(),

		// output
		.order_failures(order_failures)
	);

	lsu_control #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) control (
		// load queue signals
		.ldq_valid(ldq_valid),
		.ldq_address_valid(ldq_address_valid),
		.ldq_executed(ldq_executed),

		// store queue signals
		.stq_valid(stq_valid),
		.stq_committed(stq_committed),

		// buffer pointers
		.ldq_head(ldq_head),
		.stq_head(stq_head),

		.stq_full(stq_full),

		// outputs
		.fire_memory_op(),
		.memory_op_type(),
		.memory_address(),
		.memory_data(),

		.load_executed(load_executed),
		.ldq_mem_stage_index(ldq_mem_stage_index)
	);
endmodule
