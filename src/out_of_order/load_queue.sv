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
module load_queue #(parameter XLEN=32, parameter ROB_TAG_WIDTH=32, parameter LDQ_SIZE=16) (
	input logic clk,
	input logic reset,

	// signals to allocate a new load instruction
	// tentatively planning to use the ROB tag to track incoming updates
	// to this load. i.e. address from the AGU, any other things?
	// for the above use case, I could use the index but that would mean
	// it needs to be tracked in the AGU.  either way, I'm comparing
	// against a tag/value of some sort, so it might not save me anything
	// to use the load buffer index anyways.
	// also thinking I need the ROB tag to broadcast to the CDB
	input logic alloc_ldq_entry,
	input logic [ROB_TAG_WIDTH-1:0] rob_tag_in,

	// signals to store addresses from an AGU
	input logic agu_address_valid,
	input logic [XLEN-1:0] agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0] agu_address_rob_tag,	// use to identify which

	// signals from the memory interface to designate a completed load
	// the load_completed_rob_tag is tracked by cache miss registers in
	// the caches
	input logic load_completed,				// bool to say if a load completed
	input logic [ROB_TAG_WIDTH-1:0] load_completed_rob_tag,	// ROB tag of the completed load

	input logic [LDQ_SIZE-1:0][STQ_SIZE-1:0] store_masks,

	output load_queue_entry [0:LDQ_SIZE-1] load_queue_entries
	);

	// circular buffer pointers
	logic [$clog2(LDQ_SIZE)-1:0] head;
	logic [$clog2(LDQ_SIZE)-1:0] tail;

	integer i;

	always_ff @ (posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;
		end else begin
			// place a new load instruction in the load buffer
			if (alloc_ldq_entry) begin
				load_queue_entries[tail].valid <= 1;
				load_queue_entries[tail].rob_tag <= rob_tag_in;
				tail <= tail + 1;
			end

			// loop to do operations on every entry
			for (i = 0; i < LDQ_BUF_SIZE; i = i + 1) begin	// each entry in the buffer makes this comparison
				// READ ADDRESS FROM THE AGU
				// if the address from the AGU is to be read and the ROB tag matches
				if (agu_address_valid && agu_address_rob_tag == load_queue_entries[i].rob_tag) begin
					// if match, update address and declare it to be valid
					load_queue_entries[i].address <= agu_address_data;
					load_queue_entries[i].address_valid <= 1;
				end

				if (load_completed && load_completed_rob_tag == load_queue_entries[i].rob_tag) begin
					load_queue_entries[i].completed <= 1;
				end
			end

			// TODO: if there are any valid && address_valid entries
			// that are not fired, try to fire the oldest one
			// gonna do this with a separate component I think
		end
	end
endmodule
