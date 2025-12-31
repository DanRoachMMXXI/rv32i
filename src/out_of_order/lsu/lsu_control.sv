/*
* let's try to keep track of all the things this module needs to do, and MIGHT
* need to do.
*
* for sure:
* - track which load it executes and update the LDQ entry
* - track if the next entry in the STQ has committed and publish its index in
*   the STQ
*   - might this be done better as a pointer in the store queue that
*     increments when the value it's pointing to has committed set?
* - decide whether it's going to execute a load or commit a store this cycle
*   (which affects the first two points)
*
* might need to:
* - handle flushing and reset the tail pointers on flushes
*/
module lsu_control #(parameter XLEN=32, parameter ROB_TAG_WIDTH=32, parameter LDQ_SIZE=32, parameter STQ_SIZE=32) (
	input logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address,
	input logic [LDQ_SIZE-1:0]				ldq_rotated_valid,
	input logic [LDQ_SIZE-1:0]				ldq_rotated_address_valid,
	input logic [LDQ_SIZE-1:0]				ldq_rotated_sleeping,
	input logic [LDQ_SIZE-1:0]				ldq_rotated_executed,

	// uncomment them as you need them
	input logic [STQ_SIZE-1:0] [XLEN-1:0]	stq_address,
	input logic [STQ_SIZE-1:0]		stq_rotated_valid,		// is the ENTRY valid
	input logic [STQ_SIZE-1:0]		stq_rotated_executed,
	input logic [STQ_SIZE-1:0]		stq_rotated_committed,

	input logic [$clog2(LDQ_SIZE)-1:0]	ldq_head,
	input logic [$clog2(STQ_SIZE)-1:0]	stq_head,

	input logic stq_full,

	// fire_memory_op: bool enabling issuing of memory operations
	// with the memory_op_type, memory_address, and memory_data
	// memory_op_type: 0 = load, 1 = store
	// memory_address: address to be sent to memory, routed from
	// the load queue or store queue
	// memory_data: data to be sent to memory for stores
	output logic		fire_memory_op,
	output logic		memory_op_type,
	output logic [XLEN-1:0]	memory_address,
	output logic [XLEN-1:0]	memory_data,

	// load_fired: bool stating whether a load is being
	// fired this clock cycle.  if this is set, the load queue
	// will set the executed bit of that entry, and the searcher
	// will compare this entry to the entries in the store queue
	// for forwarding.
	output logic load_fired,
	// load_fired_ldq_index: the index of the executed load if
	// load_fired is set.  this should be the closest entry to
	// ldq_head with valid and address_valid set, and executed
	// cleared, and is not sleeping.
	output logic [$clog2(LDQ_SIZE)-1:0] load_fired_ldq_index,

	// these signals serve the same purpose as the load_fired signals
	// above
	output logic store_fired,
	output logic [$clog2(STQ_SIZE)-1:0] store_fired_index
	);

	// how do we pick whether to execute a load or a store?
	// - which queues have entries ready to execute?
	//   - if none, then nothing happens
	//   - if only one, then execute that one
	//   - if both, have to decide
	// - is the store queue full?  executing a store helps free the entry
	// sooner, executing a load does not
	// - executing a load has a more meaningful performance gain than
	// executing a store, so execute the load

	// search through to find the first entry that meets the selection
	// criteria for each queue, use a LSB priority encoder to select it,
	// then use the algorithm above to actually determine what's executed

	logic [LDQ_SIZE-1:0] ldq_ready_entries;
	assign ldq_ready_entries = ldq_rotated_valid & ldq_rotated_address_valid & ~ldq_rotated_executed & ~ldq_rotated_sleeping;
	logic can_fire_load;	// ;)

	logic [STQ_SIZE-1:0] stq_ready_entries;
	assign stq_ready_entries = stq_rotated_valid & stq_rotated_committed;	// TODO: what else might we need here?
	logic can_fire_store;

	logic [$clog2(LDQ_SIZE)-1:0] ldq_oldest_ready_index_rotated;
	logic [$clog2(STQ_SIZE)-1:0] stq_oldest_ready_index_rotated;
	logic [$clog2(LDQ_SIZE)-1:0] ldq_oldest_ready_index;
	logic [$clog2(STQ_SIZE)-1:0] stq_oldest_ready_index;

	lsb_priority_encoder #(.N(LDQ_SIZE)) ldq_ready_index_select (
		.in(ldq_ready_entries),
		.out(ldq_oldest_ready_index_rotated),
		.valid(can_fire_load)
	);

	lsb_priority_encoder #(.N(STQ_SIZE)) stq_ready_index_select (
		.in(stq_ready_entries),
		.out(stq_oldest_ready_index_rotated),
		.valid(can_fire_store)
	);

	// get the actual index of the ready buffer entries
	assign ldq_oldest_ready_index = ldq_oldest_ready_index_rotated + ldq_head;
	assign stq_oldest_ready_index = stq_oldest_ready_index_rotated + stq_head;

	assign fire_memory_op = can_fire_load | can_fire_store;

	// as per the algorithm I wrote, the only condition in which we want
	// to fire a store before a load is if the store queue is full.
	assign load_fired = can_fire_load && !stq_full;
	assign store_fired = !load_fired && can_fire_store;
	assign memory_op_type = ~load_fired;		// memory_op_type != store_fired

	assign memory_address = ({XLEN{~memory_op_type}} & ldq_address[ldq_oldest_ready_index])	// load address routing
		| ({XLEN{memory_op_type}} & stq_address[stq_oldest_ready_index]);	// store address routing
	assign memory_data = stq_address[stq_oldest_ready_index];
	// we can just assign load_fired_ldq_index and store_fired_index
	// as nothing SHOULD use them if load_fired and store_fired are not set
	assign load_fired_ldq_index = ldq_oldest_ready_index;
	assign store_fired_index = stq_oldest_ready_index;

endmodule
