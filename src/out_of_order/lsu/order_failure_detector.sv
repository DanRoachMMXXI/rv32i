/*
 * Order failure detector
 * This is a part of the "searcher" from the BOOM LSU.
 * When a store commits, its index shall be provided to the stq_commit_index
 * input.  This module compares all the load_queue_entries to find all younger
 * loads.  If any of these loads have had data forwarded from an older store,
 * they are flagged for an order failure to flush the pipeline of all
 * subsequent instructions.
 */
module order_failure_detector
	import lsu_pkg::*; (
		input load_queue_entry [LDQ_SIZE-1:0] load_queue_entries,
		input store_queue_entry [STQ_SIZE-1:0] store_queue_entries,

		// putting these here as I think we are going to need these to
		// compare the age of different stores by computing how far
		// away they are from the head.
		input logic [$clog2(STQ_SIZE)-1:0] stq_head,

		input logic [$clog2(STQ_SIZE)-1:0] stq_commit_index,
		output logic [LDQ_SIZE-1:0] order_failures
	);

	logic [LDQ_SIZE-1:0] fwd_index_older_than_stq_commit_index;	// LMAO
	integer i;

	genvar generate_iterator;
	generate
		for (generate_iterator = 0; generate_iterator < LDQ_SIZE; generate_iterator = generate_iterator + 1) begin
			// result = 0 if a is older than b,
			// result = 1 if a is younger than b
			// since we're using this output to determine if the
			// forwarded index is older than the committing index,
			// a must be the committing index and b must be the
			// forwarded index.
			age_comparator #(.N($clog2(STQ_SIZE))) age_comparator (
				.head(stq_head),
				.a(stq_commit_index),
				.b(load_queue_entries[generate_iterator].forward_stq_index),
				.result(fwd_index_older_than_stq_commit_index[generate_iterator])
			);
		end
	endgenerate

	// order failure detection
	always_comb begin
		for (i = 0; i < LDQ_SIZE; i = i + 1) begin
			// While it's not stated so in the BOOM documentation,
			// I assume we need to check the store mask to know if
			// a load is dependent on this store.
			order_failures[i] = (load_queue_entries[i].valid	// is the load valid?
				&& load_queue_entries[i].succeeded		// has the load acquired and broadcast data?
				&& load_queue_entries[i].store_mask[stq_commit_index]	// is the load younger than the committing store?
				// did the load acquire data from the same address?
				&& load_queue_entries[i].address == store_queue_entries[stq_commit_index].address
				// data was not forwarded OR was forwarded from an older store
				&& (!load_queue_entries[i].forward_stq_data || (
					load_queue_entries[i].forward_stq_data && fwd_index_older_than_stq_commit_index[i]))
			);
		end
	end
endmodule
