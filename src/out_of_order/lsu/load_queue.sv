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
 */
module load_queue #(
	parameter XLEN=32,
	parameter ROB_TAG_WIDTH,
	parameter LDQ_SIZE,
	parameter LDQ_TAG_WIDTH,
	parameter STQ_SIZE,
	parameter STQ_TAG_WIDTH) (
	input logic clk,
	input logic reset,

	// signals to allocate a new load instruction
	input logic			alloc_ldq_entry,
	input logic [ROB_TAG_WIDTH-1:0]	rob_tag_in,
	input logic [STQ_SIZE-1:0]	store_mask,

	// signals to store addresses from an AGU
	input logic			agu_address_valid,
	input logic [XLEN-1:0]		agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0]	agu_address_rob_tag,	// use to identify which

	// CDB signals so we can identify when a sleeping load can be retried
	input logic			cdb_active,
	input wire [ROB_TAG_WIDTH-1:0]	cdb_tag,

	// signals for a load is going through the execute stage
	// load_fired: is a load being fired this cycle?
	// load_fired_tag: load queue index of the load being fired
	// load_fired_sleep: has the searcher determined that this load
	// needs to be put to sleep?  this will set the sleeping bit of that
	// entry AND ENSURE THAT THE EXECUTED BIT REMAINS CLEARED!!
	// load_fired_sleep_rob_tag: ROB tag of the store instruction that
	// caused this load to sleep.  when the ROB tag is seen on the CDB,
	// the load can be retried and forwarded.
	// load_fired_forward: has the searcher determined that the data
	// for this load can be forwarded from the store queue?
	// load_fired_forward_tag: the index of the store queue entry that
	// the data has been forwarded from if load_fired_forward is set.
	// NOTE: sleep and forward are expected to be MUTUALLY EXCLUSIVE
	// NOTE: in the load queue, ldq_executed[i] and ldq_sleeping[i] MUST
	// ALSO BE MUTUALLY EXCLUSIVE
	input logic			load_fired,
	input logic [LDQ_TAG_WIDTH-1:0]	load_fired_tag,
	input logic			load_fired_sleep,
	input logic [ROB_TAG_WIDTH-1:0]	load_fired_sleep_rob_tag,
	input logic			load_fired_forward,
	input logic [STQ_TAG_WIDTH-1:0]	load_fired_forward_tag,

	// signals from the memory interface to designate a succeeded load
	// the load_succeeded_rob_tag is tracked by cache miss registers in
	// the caches
	input logic			load_succeeded,		// bool to say if a load succeeded
	input logic [ROB_TAG_WIDTH-1:0]	load_succeeded_rob_tag,	// ROB tag of the succeeded load

	// rob signals to know when loads commit
	input logic			rob_commit,
	input logic [ROB_TAG_WIDTH-1:0]	rob_commit_tag,

	// signal from the ROB exception handler to flush some or all of the
	// LDQ.  flush_rob_tag is used to determine which instructions to
	// flush (anything not younger than flush_rob_tag).  ldq_new_tail,
	// which is taken from the ROB entry of the instruction that caused
	// the flush, is used to update the tail pointer.
	// This SHOULD result in the tail pointing to the first !valid ldq
	// entry.  This is not how I want to finalize the design, but how I'm
	// proceeding forward in the interim so I can get this thing working.
	// TODO: move away from maintaining a valid array.  This will require
	// me to use the stq_tail instead of the store_mask for load
	// dependence, as well as somehow using the pointers as well for
	// order failure checking.
	input logic			flush,
	input logic [ROB_TAG_WIDTH-1:0]	flush_rob_tag,	// flush all instructions equal to and younger than this tag
	input logic [LDQ_TAG_WIDTH-1:0]	ldq_new_tail,

	// each bit determines if that entry experienced an order failure
	// multiple loads may have their order failures set at once, if they
	// all loaded before the committing store
	input logic [LDQ_SIZE-1:0]		order_failures,

	// need to see when a STQ entry fires to memory so we can clear that
	// bit of all store_masks
	input logic				store_fired,
	input logic [$clog2(STQ_SIZE)-1:0]	store_fired_index,	// DELIBERATELY LEAVING THIS AS INDEX

	// load queue buffer contents
	//   vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
	// > IF YOU ADD AN ENTRY HERE, PLEASE REMEMBER TO CLEAR IT IN THE <
	// > clear_entry FUNCTION!!!                                      <
	//   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	output logic [LDQ_SIZE-1:0]				ldq_valid,
	output logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address,
	output logic [LDQ_SIZE-1:0]				ldq_address_valid,
	output logic [LDQ_SIZE-1:0]				ldq_sleeping,
	output logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_sleep_rob_tag,
	output logic [LDQ_SIZE-1:0]				ldq_executed,
	output logic [LDQ_SIZE-1:0]				ldq_succeeded,
	output logic [LDQ_SIZE-1:0]				ldq_committed,
	output logic [LDQ_SIZE-1:0]				ldq_order_fail,
	output logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask,
	output logic [LDQ_SIZE-1:0]				ldq_forwarded,
	output logic [LDQ_SIZE-1:0][STQ_TAG_WIDTH-1:0]		ldq_forward_stq_tag,
	output logic [LDQ_SIZE-1:0][ROB_TAG_WIDTH-1:0]		ldq_rob_tag,

	// status bits rotated such that the head is at index 0
	// useful for modules that select the youngest or oldest entries that
	// meet specific criteria using priority encoders
	output logic [LDQ_SIZE-1:0]				ldq_rotated_valid,
	output logic [LDQ_SIZE-1:0]				ldq_rotated_address_valid,
	output logic [LDQ_SIZE-1:0]				ldq_rotated_sleeping,
	output logic [LDQ_SIZE-1:0]				ldq_rotated_executed,

	// circular buffer pointers
	output logic [LDQ_TAG_WIDTH-1:0] head,
	output logic [LDQ_TAG_WIDTH-1:0] tail,

	output logic full
	// TODO flush signals
	);

	// just like the ROB, the tags may be extended, and thus wider than
	// necessary to index the load queue.  this reduces them to the
	// correct width for accessing the physical queue entry.
	localparam LDQ_INDEX_WIDTH = $clog2(LDQ_SIZE);
	logic [LDQ_INDEX_WIDTH-1:0] head_index;
	logic [LDQ_INDEX_WIDTH-1:0] tail_index;
	logic [LDQ_INDEX_WIDTH-1:0] load_fired_index;
	assign head_index = head[LDQ_INDEX_WIDTH-1:0];
	assign tail_index = tail[LDQ_INDEX_WIDTH-1:0];
	assign load_fired_index = load_fired_tag[LDQ_INDEX_WIDTH-1:0];

	always_ff @ (posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;

			for (int i = 0; i < LDQ_SIZE; i = i + 1) begin
				clear_entry(i[LDQ_INDEX_WIDTH-1:0]);
			end
		end else begin
			if (flush) begin
				tail <= ldq_new_tail;
			end
			// loop to do operations on every entry
			for (int i = 0; i < LDQ_SIZE; i = i + 1) begin	// each entry in the buffer makes this comparison
				if (flush && !($signed(ldq_rob_tag[i] - flush_rob_tag) < 0)) begin: flush_entry
					clear_entry(i[LDQ_INDEX_WIDTH-1:0]);
				end: flush_entry
				else begin: not_flush_entry
					// place a new load instruction in the load buffer
					if (alloc_ldq_entry && !flush && i[LDQ_INDEX_WIDTH-1:0] == tail_index) begin
						ldq_valid[i] <= 1;
						ldq_rob_tag[i] <= rob_tag_in;
						ldq_store_mask[i] <= store_mask;
						tail <= tail + 1;
					end

					// set the signals for the load fired this cycle (if
					// one was fired)
					if (ldq_valid[i] && load_fired && i[LDQ_INDEX_WIDTH-1:0] == load_fired_index) begin
						if (load_fired_sleep) begin
							ldq_executed[i] <= 0;
							ldq_sleeping[i] <= 1;
							ldq_sleep_rob_tag[i] <= load_fired_sleep_rob_tag;
							// forward should already be cleared
						end else begin
							ldq_executed[i] <= 1;
							ldq_sleeping[i] <= 0;	// should already be cleared?
							if (load_fired_forward) begin
								ldq_forwarded[i] <= 1;
								ldq_succeeded[i] <= 1;
								ldq_forward_stq_tag[i] <= load_fired_forward_tag;
							end
						end
					end

					// if the entry at the head is committed, free it and increment head
					if (ldq_valid[i] && i[LDQ_INDEX_WIDTH-1:0] == head_index && ldq_committed[i]) begin
						clear_entry(head_index);
						head <= head + 1;
					end

					// READ ADDRESS FROM THE AGU
					// if the address from the AGU is to be read and the ROB tag matches
					if (ldq_valid[i] && agu_address_valid && agu_address_rob_tag == ldq_rob_tag[i]) begin
						// if match, update address and declare it to be valid
						ldq_address[i] <= agu_address_data;
						ldq_address_valid[i] <= 1;
					end

					// if the load is sleeping and the store that caused
					// it to sleep is seen on the CDB, we can wake the
					// load so it can be retried
					if (ldq_valid[i] && ldq_sleeping[i]
							&& cdb_active && cdb_tag == ldq_sleep_rob_tag[i]) begin
						ldq_sleeping[i] <= 0;
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
					if (store_fired) begin
						ldq_store_mask[i][store_fired_index] <= 1'b0;
					end
				end: not_flush_entry
			end
		end
	end

	// Since the tail pointer points to the next available entry in the
	// buffer, if that entry has the valid bit set, there are no more
	// available entries and the buffer is full.
	assign full = ldq_valid[tail_index];

	assign ldq_rotated_valid = (ldq_valid >> head) | (ldq_valid << (LDQ_SIZE - head));
	assign ldq_rotated_address_valid = (ldq_address_valid >> head) | (ldq_address_valid << (LDQ_SIZE - head));
	assign ldq_rotated_sleeping = (ldq_sleeping >> head) | (ldq_sleeping << (LDQ_SIZE - head));
	assign ldq_rotated_executed = (ldq_executed >> head) | (ldq_executed << (LDQ_SIZE - head));

	function void clear_entry(logic[LDQ_INDEX_WIDTH-1:0] index);
		ldq_valid[index] <= 0;
		ldq_address[index] <= 0;
		ldq_address_valid[index] <= 0;
		ldq_sleeping[index] <= 0;
		ldq_sleep_rob_tag[index] <= 0;
		ldq_executed[index] <= 0;
		ldq_succeeded[index] <= 0;
		ldq_committed[index] <= 0;
		ldq_order_fail[index] <= 0;
		ldq_store_mask[index] <= 0;
		ldq_forwarded[index] <= 0;
		ldq_forward_stq_tag[index] <= 0;
		ldq_rob_tag[index] <= 0;
	endfunction
endmodule
