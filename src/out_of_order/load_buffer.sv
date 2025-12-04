/*
 * using the data fields shown in the BOOM LSU
 * complete list here:
 * https://github.com/riscv-boom/riscv-boom/blob/master/src/main/scala/v4/lsu/lsu.scala#L174-L194
 * but many are not needed for my implementation
 */
interface load_buffer_entry #(parameter XLEN, parameter STQ_BUF_SIZE, parameter ROB_TAG_WIDTH);
	logic valid;
	logic [XLEN-1:0] address;
	logic address_valid;
	logic executed;
	logic succeeded;

	// not sure what these two do
	logic order_fail;
	logic observed;

	// bitmask that holds 1s for each entry in the store queue that this
	// load depends on.  If the data is present in the store queue, it is
	// to be forwarded.
	logic [STQ_BUF_SIZE-1:0] store_mask;
	logic forward_stq_data;		// BOOLEAN to indicate if we are forwarding
	logic [$clog2(STQ_BUF_SIZE)-1:0] forward_stq_index;

	// now here's the stuff that isn't in BOOM
	// if the store queue is going to broadcast to the CDB, it needs to
	// store the ROB index
	logic [ROB_TAG_WIDTH-1:0] rob_tag;
endinterface
/*
 * Tracks in flight load operations
 * so wtf does this thing need to do:
 * - allocate entries new load instructions (DONE)
 *   - set valid bit (DONE)
 *   - probably store ROB tag as an identifier? (DONE)
 * - store addresses from AGU
 *   - update entry with address and set address_valid (DONE)
 *   - fire load as soon as address arrives
 * - compare against store addresses once address arrives
 *   - store bitmask
 *   - if there's a match
 *	- cancel the fired load operation
 *	- forward the data if it's available in the store buffer
 *	- sleep until the data is available if it isn't already available
 * - broadcast loaded data to the CDB
 */
module load_buffer #(parameter XLEN=32, parameter ROB_TAG_WIDTH=32, parameter LDQ_BUF_SIZE=16) (
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
	input logic alloc_buffer_entry,
	input logic [ROB_TAG_WIDTH-1:0] rob_tag_in,

	// signals to store addresses from an AGU
	input logic agu_address_valid,
	input logic [XLEN-1:0] agu_address_data,
	input logic [ROB_TAG_WIDTH-1:0] agu_address_rob_tag,	// use to identify which

	output logic [0:LDQ_BUF_SIZE-1] load_queue
	);

	// circular buffer pointers
	logic [$clog2(LDQ_BUF_SIZE)-1:0] head;
	logic [$clog2(LDQ_BUF_SIZE)-1:0] tail;

	integer i;

	always_ff @ (posedge clk) begin
		if (!reset) begin
			head <= 0;
			tail <= 0;
		end else begin
			// place a new load instruction in the load buffer
			if (alloc_buffer_entry) begin
				load_queue[tail].valid <= 1;
				load_queue[tail].rob_tag <= rob_tag_in;
				tail <= tail + 1;
			end

			// read address from the agu
			for (i = 0; i < LDQ_BUF_SIZE; i = i + 1) begin	// each entry in the buffer makes this comparison
				if (agu_address_valid) begin		// if the address from the AGU is to be read
					if (agu_address_rob_tag == load_queue[i].rob_tag) begin		// check for a ROB tag match
						// if match, update address and declare it to be valid
						load_queue[i].address <= agu_address_data;
						load_queue[i].address_valid <= 1;
					end
				end
			end

			// TODO: if there are any valid && address_valid entries
			// that are not fired, try to fire one
		end
	end
endmodule
