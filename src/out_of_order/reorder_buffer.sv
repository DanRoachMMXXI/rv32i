/*
 * TODO: be mentally prepared to handle flushing mispredicts
 * it might not be too bad if done simply: flush all instructions when the
 * branch result commits.  that would be very inefficient tho, because we want
 * to flush and start fetching new instructions as soon as we know the branch
 * was incorrect.  We can't use the pc value to determine if an instruciton
 * was executed on a misprediction.  We need to leverage the ordering of
 * instructions in the buffer.  So for all elements after the mispredicted
 * branch (and before the read_from index), they need to be flushed.
 * [ valid, write_to, empty, empty, read_from, valid, mispredicted, valid ]
 *     0       1        2      3        4        5         6          7
 * in this example, indices 7 and 0 would need to be flushed when we find out
 * that the branch prediction was wrong.  reminder that 1 is not yet occupied.
 * we can guarantee that a mispredicted instruciton is between read_from and
 * write_to, but I don't know if that guarantee is useful in implementing the
 * logic.
 *
 * we can not guarantee that mispredicted != write_to.  they are equal if the
 * buffer is full and the mispredicted branch is the first in the buffer, and
 * every other instruction in the buffer is flushed.
 *
 * the instructions to flush are the instructions between the index of the
 * mispredicted index and the write_to index, not inclusive.
 * 
 * The textbook DOES say that the buffer flushing is done when the
 * mispredicted branch commits.  I think my assessment is still correct, but
 * it may be a good idea to implement the simple and suboptimal solution
 * quickly to get it done, then fuck about with more complicated
 * optimizations.
 * The textbook then ALSO does say in practice processors do what I described
 * above.  Plan is probably still valid: do easy thing, then hard thing.
 *
 * It may become easier to offload the flushing of the buffer to another
 * component, and take in the signals to flush specific entries of the buffer.
 */
interface reorder_buffer_entry #(parameter XLEN);
	logic valid;

	// the ROB needs to know if a store's address is ready (as well as the
	// data) in order to commit it.  this will be determined by reading
	// the agu_address bus and setting this bit when this entry's ROB
	// index appears on the bus when the bus is active.
	logic address_ready;
	logic [1:0] instruction_type;
	logic [XLEN-1:0] destination;
	logic [XLEN-1:0] value;
	logic ready;
	// eventually I'll need exceptions
endinterface

module reorder_buffer #(
		parameter XLEN=32,
		// For now, keep TAG_WIDTH as a parameter for syntesizability
		// but keep it set to log2(BUF_SIZE)
		parameter TAG_WIDTH=8,
		parameter BUF_SIZE=64) (
	// Synchronous input signals
	input logic clk,
	input logic reset,	// active low

	// input signals for the instruciton to store in the buffer
	// TODO
	input logic input_en,	// enable to read the values on the below signals
	input logic [1:0] instruction_type_in,
	input logic [XLEN-1:0] destination_in,
	// I'm unsure any instructions will actually store a value straight
	// into the ROB.  Maybe there's an argument for LUI and/or AUIPC.
	// Since they're issued in order, nothing will be waiting for them
	//
	// Stores also may have the value immediately ready, but need to have
	// their address calculated and read from the memory address bus.
	input logic [XLEN-1:0] value_in,
	input logic ready_in,
	
	// common data bus signals
	input logic cdb_active,
	input logic [XLEN-1:0] cdb_data,
	input logic [TAG_WIDTH-1:0] cdb_tag,

	// memory address bus - a separate bus where the address FU sends
	// addresses to the ROB for STORES ONLY
	input logic memory_addr_bus_active,
	input logic [XLEN-1:0] memory_addr_bus_data,	// the address
	input logic [XLEN-1:0] memory_addr_bus_tag,

	// the buffer itself
	// assuming this will be an output since a few things will need to be
	// read from this:
	// - load buffer needs to see if any ROB entries have stores for
	// a load
	// - when instructions are issued, the ROB needs to be referenced to
	// get the value or the tag/index that it will be broadcast to the CDB
	// with
	output reorder_buffer_entry [BUF_SIZE-1:0] buffer
	);

	integer i;	// used to reset all buffer entries

	// circular buffer pointers
	logic [TAG_WIDTH-1:0] read_from;
	logic [TAG_WIDTH-1:0] write_to;

	always @ (posedge clk) begin
		if (!reset) begin
			read_from <= 0;
			write_to <= 0;

			// reset buffer contents
			// I think the only thing that matters is valid = 0
			for (i = 0; i < BUF_SIZE; i = i + 1) begin
				buffer[i].valid <= 0;
				buffer[i].instruction_type <= 0;
				buffer[i].destination <= 0;
				buffer[i].value <= 0;
				buffer[i].ready <= 0;
				// TODO reset exceptions
			end
		end else begin
			// TODO: need to figure out how to know that both the value AND
			// address are ready for stores, it can't just be on the event of the
			// CDB or the memory address bus alone as they can probably come in
			// either order.

			// store a new instruction in the buffer
			if (input_en) begin
				buffer[write_to].valid <= 1;
				buffer[write_to].instruction_type <= instruction_type_in;
				buffer[write_to].destination <= destination_in;
				buffer[write_to].value <= value_in;
				buffer[write_to].ready <= ready_in;
			end

			// read a value off the CDB
			if (cdb_active) begin
				buffer[cdb_tag].value <= cdb_data;
				buffer[cdb_tag].ready <= 1;
			end

			// read an address off the memory address bus
			if (memory_addr_bus_active) begin
				// TODO: can't just have an "active" like the CDB, it needs to be
				// targeted for the ROB OR only update store instructions.  Load
				// instructions use the destination field of the ROB entry for the
				// target register, so we don't want to overwrite that with the
				// address to be loaded - that's stored in the load buffer.
				buffer[memory_addr_bus_tag].destination <= memory_addr_bus_data;
			end

			// instruction commit
			if (buffer[read_from].ready) begin
				// TODO commit logic
				read_from <= read_from + 1;
			end
		end
	end
endmodule
