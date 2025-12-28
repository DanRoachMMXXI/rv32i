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
	input logic [LDQ_SIZE-1:0]				ldq_valid,
	// input logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address,
	input logic [LDQ_SIZE-1:0]				ldq_address_valid,
	input logic [LDQ_SIZE-1:0]				ldq_executed,
	// input logic [LDQ_SIZE-1:0]				ldq_succeeded,
	// input logic [LDQ_SIZE-1:0]				ldq_committed,
	// input logic [LDQ_SIZE-1:0]				ldq_order_fail,
	// input logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask,
	// input logic [LDQ_SIZE-1:0]				ldq_forward_stq_data,
	// input logic [LDQ_SIZE-1:0][$clog2(STQ_SIZE)-1:0]	ldq_forward_stq_index,
	// input logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag,

	// uncomment them as you need them
	input logic [STQ_SIZE-1:0] stq_valid,		// is the ENTRY valid
	// input logic [STQ_SIZE-1:0] [XLEN-1:0] stq_address,
	// input logic [STQ_SIZE-1:0] stq_address_valid,
	// input logic [STQ_SIZE-1:0] [XLEN-1:0] stq_data,
	// input logic [STQ_SIZE-1:0] stq_data_valid,	// is the data for the store present in the entry?
	input logic [STQ_SIZE-1:0] stq_committed,
	// input logic [STQ_SIZE-1:0] stq_succeeded,
	// input logic [STQ_SIZE-1:0] [ROB_TAG_WIDTH-1:0] stq_rob_tag,

	input logic [$clog2(LDQ_SIZE)-1:0] ldq_head,
	input logic [$clog2(STQ_SIZE)-1:0] stq_head,

	input logic stq_full,

	// fire_memory_op: bool enabling issuing of memory operations
	// with the memory_op_type, memory_address, and memory_data
	// memory_op_type: 0 = load, 1 = store
	// memory_address: address to be sent to memory, routed from
	// the load queue or store queue
	// memory_data: data to be sent to memory for stores
	output logic fire_memory_op,
	output logic memory_op_type,
	output logic [XLEN-1:0] memory_address,
	output logic [XLEN-1:0] memory_data,

	// load_executed: bool stating whether a load is being
	// executed this clock cycle.  if this is set, the load queue
	// will set the executed bit of that entry, and the searcher
	// will compare this entry to the entries in the store queue
	// for forwarding.
	output logic load_executed,
	// ldq_mem_stage_index: the index of the executed load if
	// load_executed is set.  this should be the closest entry to
	// ldq_head with valid and address_valid set, and executed
	// cleared, and is not sleeping.
	// TODO: might just rename this globally to load_executed_index
	output logic [$clog2(LDQ_SIZE)-1:0] ldq_mem_stage_index
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

	// practically how do we find this?
	// do we rotate all the entries?  that seems like a ton of hardware.
	// assume we do.
	// rotate all the entries in the load and store queue based on their
	// heads
	// search through to find the first entry that meets the selection
	// criteria for each queue, use a LSB priority encoder to select it?
	// then use the algorithm above to actually determine what's executed

	// in order to select the load queue and store queue entries that are
	// nearest to the head, we need to rotate them by ldq_head and
	// stq_head bits respectively.
	logic [LDQ_SIZE-1:0] ldq_rotated_valid;
	logic [LDQ_SIZE-1:0] ldq_rotated_address_valid;
	logic [LDQ_SIZE-1:0] ldq_rotated_executed;
	logic [LDQ_SIZE-1:0] ldq_rotated_sleeping;

	logic [STQ_SIZE-1:0] stq_rotated_valid;
	logic [STQ_SIZE-1:0] stq_rotated_committed;

	always_comb begin
	end
	
	// function logic ldq_entry_ready(load_queue_entry ldq_entry);
	// 	return ldq_entry.valid
	// 		&& ldq_entry.address_valid
	// 		&& !ldq_entry.executed;
	// 	// TODO: what else might we need here?
	// 	// - not sleeping?
	// 	//   - important for not re-executing loads that are waiting
	// 	//   on a store
	// endfunction

	// function logic stq_entry_ready(store_queue_entry stq_entry);
	// 	return stq_entry.valid
	// 		&& stq_entry.committed;
	// 	// TODO: what else might we need here?
	// endfunction
endmodule
