/*
* let's try to keep track of all the things this module needs to do, and MIGHT
* need to do.
*
* for sure:
* - track which load it executes and update the LDQ entry
* - track if the next entry in the STQ has committed and publish its index in
*   the STQ
* - decide whether it's going to execute a load or commit a store this cycle
*   (which affects the first two points)
*
* might need to:
* - handle flushing and reset the tail pointers on flushes
*/
module lsu_control
	import lsu_pkg::*;
	(
		input load_queue_entry [LDQ_SIZE-1:0] load_queue_entries,
		input store_queue_entry [STQ_SIZE-1:0] store_queue_entries,

		input logic [$clog2(LDQ_SIZE)-1:0] ldq_head,
		input logic [$clog2(STQ_SIZE)-1:0] stq_head,

		output logic load_executed,
		// ldq_mem_stage_index is the index of the LDQ entry to be
		// executed, this will have ldq[index].executed set and the
		// searcher will compare this entry for forwarding.
		// this should be the closest entry to ldq_head with
		// address_valid set.
		// TODO: might just rename this globally to
		// load_executed_index
		output logic [$clog2(LDQ_SIZE)-1:0] ldq_mem_stage_index,

		output logic store_executed,
		output logic [$clog2(STQ_SIZE)-1:0] store_executed_index
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
	
	function logic ldq_entry_ready(load_queue_entry ldq_entry);
		return ldq_entry.valid
			&& ldq_entry.address_valid
			&& !ldq_entry.executed;
		// TODO: what else might we need here?
		// - not sleeping?
		//   - important for not re-executing loads that are waiting
		//   on a store
	endfunction

	function logic stq_entry_ready(store_queue_entry stq_entry);
		return stq_entry.valid
			&& stq_entry.committed;
		// TODO: what else might we need here?
	endfunction
endmodule
