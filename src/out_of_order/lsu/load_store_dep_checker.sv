/*
 * Load store-dependence checker
 * This is a part of the "searcher" from the BOOM LSU.
 * For the load specified by ldq_mem_stage_index, it reads the address and
 * store_mask from that load queue entry and compares it against all the
 * addresses of the store queue entries specified by the store_mask.  If there
 * are any matches, it kills the memory request and checks the youngest
 * matching store to see if the data is ready for forwarding.  If so, the
 * signals to forward the data are set, otherwise the load is just killed and
 * put to sleep.
 */
module load_store_dep_checker #(parameter XLEN=32, parameter LDQ_SIZE=32, parameter STQ_SIZE=32) (
	input logic [LDQ_SIZE-1:0][XLEN-1:0]		ldq_address,
	input logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]	ldq_store_mask,

	input logic [STQ_SIZE-1:0] stq_valid,		// is the ENTRY valid
	input logic [STQ_SIZE-1:0] [XLEN-1:0] stq_address,
	input logic [STQ_SIZE-1:0] stq_address_valid,
	input logic [STQ_SIZE-1:0] stq_data_valid,	// is the data for the store present in the entry?

	// putting these here as I think we are going to need these to
	// compare the age of different stores by computing how far
	// away they are from the head.
	input logic [$clog2(STQ_SIZE)-1:0] stq_head,

	input logic [$clog2(LDQ_SIZE)-1:0] ldq_mem_stage_index,
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
				ldq_store_mask[ldq_mem_stage_index][i]	// this store is older than the load
				&& stq_valid[i]	// this store is valid
				&& stq_address_valid[i]	// store has a valid address
				// and addresses match
				&& stq_address[i] == ldq_address[ldq_mem_stage_index]
			);
		end

		// youngest_entry_select module selects the youngest matching
		// store from address_matches, and sets kill_mem_req if any of
		// the bits of address_matches were 1 (in other words, the
		// bitwise or of address_matches).

		// youngest_matching_store_index is only valid if any of the
		// addresses match, represented by kill_mem_req
		if (kill_mem_req && stq_data_valid[youngest_matching_store_index]) begin
			forward = 1;
			stq_forward_index = youngest_matching_store_index;
		end else begin
			forward = 0;
			stq_forward_index = 0;
		end
	end
endmodule
