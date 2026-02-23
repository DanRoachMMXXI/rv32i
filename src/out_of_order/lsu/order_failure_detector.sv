/*
 * Order failure detector
 * This is a part of the "searcher" from the BOOM LSU.
 * When a store commits, its index shall be provided to the store_fired_index
 * input.  This module compares all the load queue entries to find all younger
 * loads.  If any of these loads have had data forwarded from an older store,
 * they are flagged for an order failure to flush the pipeline of all
 * subsequent instructions.
 * - "To discover ordering failures, when a store commits, it checks the entire
 *   LDQ for any address matches. If there is a match, the store checks to see
 *   if the load has executed, and if it got its data from memory or if the
 *   data was forwarded from an older store. In either case, a memory ordering
 *   failure has occurred."
 */
module order_failure_detector #(parameter XLEN=32, parameter LDQ_SIZE, parameter STQ_SIZE, parameter STQ_TAG_WIDTH) (
		input logic [LDQ_SIZE-1:0]				ldq_valid,
		input logic [LDQ_SIZE-1:0][XLEN-1:0]			ldq_address,
		input logic [LDQ_SIZE-1:0]				ldq_succeeded,
		input logic [LDQ_SIZE-1:0][STQ_SIZE-1:0]		ldq_store_mask,
		input logic [LDQ_SIZE-1:0]				ldq_forwarded,
		input logic [LDQ_SIZE-1:0][STQ_TAG_WIDTH-1:0]		ldq_forward_stq_tag,

		input logic [STQ_SIZE-1:0][XLEN-1:0] stq_address,

		// putting these here as I think we are going to need these to
		// compare the age of different stores by computing how far
		// away they are from the head.
		input logic [STQ_TAG_WIDTH-1:0] stq_head,

		// store_fired: boolean
		// 1: this store index actually committed
		// 0: the value is just junk (probably 0 by default)
		input logic store_fired,
		input logic [STQ_TAG_WIDTH-1:0] store_fired_tag,
		output logic [LDQ_SIZE-1:0] order_failures
	);

	localparam STQ_INDEX_WIDTH = $clog2(STQ_SIZE);
	logic [STQ_INDEX_WIDTH-1:0] store_fired_index;
	assign store_fired_index = store_fired_tag[STQ_INDEX_WIDTH-1:0];


	// order failure detection
	always_comb begin
		for (int i = 0; i < LDQ_SIZE; i = i + 1) begin
			// While it's not stated so in the BOOM documentation,
			// I assume we need to check the store mask to know if
			// a load is dependent on this store.
			order_failures[i] = (store_fired	// has this store index actually committed?
				&& ldq_valid[i]		// is the load valid?
				&& ldq_succeeded[i]	// has the load acquired and broadcast data?
				&& ldq_store_mask[i][store_fired_index]	// is the load younger than the committing store?
				// did the load acquire data from the same address?
				&& ldq_address[i] == stq_address[store_fired_index]
				// data was not forwarded OR was forwarded from an older store
				&& (!ldq_forwarded[i] || (
					ldq_forwarded[i] && $signed(ldq_forward_stq_tag[i] - store_fired_tag) < 0))
			);
		end
	end
endmodule
