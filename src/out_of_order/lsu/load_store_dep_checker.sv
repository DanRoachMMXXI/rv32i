/*
 * Load store-dependence checker
 * This is a part of the "searcher" from the BOOM LSU.
 * For the load specified by ldq_store_mask_index, it reads the address and
 * store_mask from that load_queue_entry and compares it against all the
 * addresses of the store_queue_entries specified by the store_mask.  If there
 * are any matches, it kills the memory request and checks the youngest
 * matching store to see if the data is ready for forwarding.  If so, the
 * signals to forward the data are set, otherwise the load is just killed and
 * put to sleep.
 */
module load_store_dep_checker
	import lsu_pkg::*; (
		input load_queue_entry [LDQ_SIZE-1:0] load_queue_entries,
		input store_queue_entry [STQ_SIZE-1:0] store_queue_entries,

		// putting these here as I think we are going to need these to
		// compare the age of different stores by computing how far
		// away they are from the head.
		input logic [$clog2(STQ_SIZE)-1:0] stq_head,

		input logic [$clog2(LDQ_SIZE)-1:0] ldq_store_mask_index,
		// kill_mem_req is blocking the request to the memory system (the L1
		// cache).  unlike what claude said, it WILL be set if data is being
		// forwarded, because we are not fetching the value that's stored in
		// memory.
		output logic kill_mem_req,
		output logic forward,	// bool, true if forwarding data
		output logic [$clog2(STQ_SIZE)-1:0] stq_forward_index	// index of forwarded data
	);

	logic [STQ_SIZE-1:0] address_matches;
	logic [$clog2(STQ_SIZE)-1:0] youngest_matching_store_index;
	integer i;

	// module used to select the youngest matching store for the given
	// load address as we evaluate dependent stores
	youngest_entry_select #(.QUEUE_SIZE(STQ_SIZE)) youngest_entry_select (
		.queue_valid_bits(address_matches),
		.head_index(stq_head),

		// if there's any address match, we kill the memory request
		// regardless of whether we can forward or not.
		.any_entry_valid(kill_mem_req),
		.youngest_index(youngest_matching_store_index)
		);
	
	// store dependence and forwarding
	always_comb begin
		for (i = 0; i < STQ_SIZE; i = i + 1) begin
			address_matches[i] = (
				load_queue_entries[ldq_store_mask_index].store_mask[i]	// this store is older than the load
				&& store_queue_entries[i].valid	// this store is valid
				&& store_queue_entries[i].address_valid	// store has a valid address
				// and addresses match
				&& store_queue_entries[i].address == load_queue_entries[ldq_store_mask_index].address
			);
		end

		// youngest_entry_select module selects the youngest matching
		// store from address_matches, and sets kill_mem_req if any of
		// the bits of address_matches were 1 (in other words, the
		// bitwise or of address_matches).

		// youngest_matching_store_index is only valid if any of the
		// addresses match, represented by kill_mem_req
		if (kill_mem_req && store_queue_entries[youngest_matching_store_index].data_valid) begin
			forward = 1;
			stq_forward_index = youngest_matching_store_index;
		end else begin
			forward = 0;
			stq_forward_index = 0;
		end
	end
endmodule
