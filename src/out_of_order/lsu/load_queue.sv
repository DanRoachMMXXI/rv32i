/*
 * Tracks in flight load operations
 * so wtf does this thing need to do:
 * - allocate entries new load instructions (DONE)
 *   - set valid bit (DONE)
 *   - probably store ROB tag as an identifier? (DONE)
 * - store addresses from AGU
 *   - update entry with address and set address_valid (DONE)
 *   - fire load as soon as address arrives
 * - update load entries
 *   - mark loads as sent
 *   - cancel loads with dependent stores
 *   - update all the other signals in load_queue_entry
 * - compare against store addresses once address arrives
 *   - THIS IS ALL DONE WITH A SEPARATE COMPONENT
 *   - if there's a match
 *	- cancel the fired load operation
 *	- forward the data if it's available in the store buffer
 *	- sleep until the data is available if it isn't already available
 *
 * - TODO: clear bits of the store_mask when they are fired to memory and
 *   leave the STQ
 * - TODO: track when loads are sleeping and figure out how to wake them
 */
module load_queue #(parameter XLEN=32, parameter ROB_TAG_WIDTH=32, parameter LDQ_SIZE=32, parameter STQ_SIZE=32) (
	input logic clk,
	input logic reset,

	// signals to allocate a new load instruction
	// tentatively planning to use the ROB tag to track incoming updates
	// to this load.
	// - address from the AGU
	// - load completed from memory (tracked by caches)
	// also thinking I need the ROB tag to broadcast to the CDB, but
	// I need to figure out what component is responsible for broadcasting
	input logic alloc_ldq_entry,
	input logic [ROB_TAG_WIDTH-1:0] rob_tag_in,
	input logic [STQ_SIZE-1:0] store_mask,

	// signals to store addresses from an AGU
	input logic agu_address_valid,
	input logic [XLEN-1:0] agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0] agu_address_rob_tag,	// use to identify which

	// signals to indicate a load has been fired
	input logic load_executed,
	input logic [$clog2(LDQ_SIZE)-1:0] load_executed_index,

	// signals from the memory interface to designate a succeeded load
	// the load_succeeded_rob_tag is tracked by cache miss registers in
	// the caches
	input logic load_succeeded,				// bool to say if a load succeeded
	input logic [ROB_TAG_WIDTH-1:0] load_succeeded_rob_tag,	// ROB tag of the succeeded load

	// rob signals to know when loads commit
	input logic rob_commit,
	input logic [ROB_TAG_WIDTH-1:0] rob_commit_tag,

	// each bit determines if that entry experienced an order failure
	// multiple loads may have their order failures set at once, if they
	// all loaded before the committing store
	input logic [LDQ_SIZE-1:0] order_failures,

	// need to see when a STQ entry fires to memory so we can clear that
	// bit of all store_masks
	input logic stq_entry_fired,
	input logic [$clog2(STQ_SIZE)-1:0] stq_entry_fired_index,

	// output load_queue_entry [LDQ_SIZE-1:0] load_queue_entries,
	output logic [LDQ_SIZE-1:0]				ldq_valid,
	output logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address,
	output logic [LDQ_SIZE-1:0]				ldq_address_valid,
	output logic [LDQ_SIZE-1:0]				ldq_executed,
	output logic [LDQ_SIZE-1:0]				ldq_succeeded,
	output logic [LDQ_SIZE-1:0]				ldq_committed,
	output logic [LDQ_SIZE-1:0]				ldq_order_fail,
	output logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask,
	output logic [LDQ_SIZE-1:0]				ldq_forward_stq_data,
	output logic [LDQ_SIZE-1:0][$clog2(STQ_SIZE)-1:0]	ldq_forward_stq_index,
	output logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag,

	// circular buffer pointers
	output logic [$clog2(LDQ_SIZE)-1:0] head,
	output logic [$clog2(LDQ_SIZE)-1:0] tail,

	output logic full
	// TODO flush signals
	);

	// loop iterator
	integer i;

	always_ff @ (posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;

			for (i = 0; i < LDQ_SIZE; i = i + 1) begin
				clear_entry(i);
			end
		end else begin
			// place a new load instruction in the load buffer
			if (alloc_ldq_entry) begin
				ldq_valid[tail] <= 1;
				ldq_rob_tag[tail] <= rob_tag_in;
				ldq_store_mask[tail] <= store_mask;
				tail <= tail + 1;
			end

			if (ldq_valid[load_executed_index] && load_executed) begin
				ldq_executed[load_executed_index] <= 1;
			end

			// if the entry at the head is committed, free it and increment head
			if (ldq_committed[head]) begin
				clear_entry(int'(head));
				head <= head + 1;
			end

			// TODO:
			// - order_fail
			//	- "To discover ordering failures, when a store
			//	commits, it checks the entire LDQ for any
			//	address matches. If there is a match, the
			//	store checks to see if the load has executed,
			//	and if it got its data from memory or if the
			//	data was forwarded from an older store. In
			//	either case, a memory ordering failure has
			//	occurred."
			//	- needs to be able to update all or multiple
			//	entries in one cycle (DONE)
			// - forward_stq_data
			// - forward_stq_index

			// loop to do operations on every entry
			for (i = 0; i < LDQ_SIZE; i = i + 1) begin	// each entry in the buffer makes this comparison
				// READ ADDRESS FROM THE AGU
				// if the address from the AGU is to be read and the ROB tag matches
				if (ldq_valid[i] && agu_address_valid && agu_address_rob_tag == ldq_rob_tag[i]) begin
					// if match, update address and declare it to be valid
					ldq_address[i] <= agu_address_data;
					ldq_address_valid[i] <= 1;
				end

				if (ldq_valid[i] && load_succeeded && load_succeeded_rob_tag == ldq_rob_tag[i]) begin
					ldq_succeeded[i] <= 1;
				end

				/*
				* here is a potential flaw of my design: I track that this
				* load has been committed this cycle so that the queue entry
				* can be freed the next cycle at the earliest.  One could
				* assume that the commit coming from the ROB is guaranteed to
				* be the load at the head of the queue.  But since I haven't
				* defined hardware to check that, I'm not making that
				* assumption.  Instead, I'm just going to have the head check
				* that it's pointing to a committed entry before clearing the
				* entry and incrementing.
				*/
				if (ldq_valid[i] && rob_commit && rob_commit_tag == ldq_rob_tag[i]) begin
					ldq_committed[i] <= 1;
				end

				// set the order fail bit of this entry if it was detected by the searcher
				ldq_order_fail[i] <= ldq_order_fail[i] | order_failures[i];

				// if a store is being fired, we must clear
				// that bit in all store_masks
				if (stq_entry_fired) begin
					ldq_store_mask[i][stq_entry_fired_index] <= 1'b0;
				end
			end
		end
	end

	// Since the tail pointer points to the next available entry in the
	// buffer, if that entry has the valid bit set, there are no more
	// available entries and the buffer is full.
	assign full = ldq_valid[tail];

	function void clear_entry(integer index);
		ldq_valid[index] <= 0;
		ldq_address[index] <= 0;
		ldq_address_valid[index] <= 0;
		ldq_executed[index] <= 0;
		ldq_succeeded[index] <= 0;
		ldq_committed[index] <= 0;
		ldq_order_fail[index] <= 0;
		ldq_store_mask[index] <= 0;
		ldq_forward_stq_data[index] <= 0;
		ldq_forward_stq_index[index] <= 0;
		ldq_rob_tag[index] <= 0;
	endfunction
endmodule
