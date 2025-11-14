/*
 * This is going to need to be implemented as a circular buffer
 * In hardware, this is probably going to look like BUF_SIZE
 * registers with two log2(BUF_SIZE) bits counters.
 * The read_from counter will go into an output mux that commits
 * the instruction, and increments when an instruction commits.
 * The write_to counter will increment whenever an instruction
 * is stored in the buffer.
 *
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
 *
 * TODO: go back and make sure you understand how stores are done with reorder
 * buffers
 * ^ done, written in Obsidian Vault, but effectively the address is computed
 * by (what seems to be) a dedicated address calculation functional unit (as
 * in the diagram on pg 210), then the value to be stored may be available or
 * is otherwise read from the CDB.
 */

module reorder_buffer #(
		parameter XLEN=32,
		// For now, keep TAG_WIDTH as a parameter for syntesizability
		// but keep it set to log2(BUF_SIZE)
		parameter TAG_WIDTH=4,
		parameter BUF_SIZE=16) (
	// Synchronous input signals
	input logic clk,
	input logic reset,	// active low

	// input signals for the instruciton to store in the buffer
	// TODO: better names for these when brain is working better than it
	// is at 7am.
	input logic [4:0] rd_index_in,
	input logic input_en,

	// CDB inputs
	input logic cdb_enable,
	input logic [TAG_WIDTH-1:0] cdb_tag,
	input logic [XLEN-1:0] cdb_data,

	// Data forwarding outputs
	// These signals are the buffer
	output reg [XLEN-1:0] [0:BUF_SIZE-1] rd_values,	// need the values to forward them
	output reg [4:0] [0:BUF_SIZE-1] rd_indices,	// need the indices to know if the values need to be forwarded
	output reg [0:BUF_SIZE-1] ready,	// need to know if data is ready
	output reg [0:BUF_SIZE-1] valid,	// need to know if entry is valid

	// Instruction commit outputs
	// This is basically the value, index, and ready & valid of the
	// instruction pointed to by read_from
	// Imagine this as the outputs from the multiplexer selected by
	// read_from
	output logic [XLEN-1:0] instruction_commit_value,
	output logic [4:0] instruction_commit_index,
	output logic commit,	// ready[read_from] && valid[read_from]
				// controls the actual committing of the
				// instruction

	output logic full	// just & all the valid bits
	);

	// CIRCULAR BUFFER POINTERS
	reg [TAG_WIDTH-1:0] read_from;
	reg [TAG_WIDTH-1:0] write_to;

	// I think I could just check valid[write_to], if the entry that would
	// be written already has something, it's full
	assign full = &valid;

	assign instruction_commit_value = rd_values[read_from];
	assign instruction_commit_index = rd_indices[read_from];
	assign commit = ready[read_from] && valid[read_from];	// the and with valid may be useless, but doesn't hurt

	always @ (posedge clk) begin
		if (!reset) begin
			// reset counters
			read_from = 0;
			write_to = 0;

			// reset buffer contents
			for (int i = 0; i < BUF_SIZE; i = i + 1) begin
				rd_values[i] = 0;
				rd_indices[i] = 0;
				ready[i] = 0;
				valid[i] = 0;	// this is the important one
			end
		end else begin
			// synchronous logic
			// it might be wise to check for overflows and make
			// assertions during simulation

			// if an instruction is to be stored in the buffer
			if (input_en) begin
				// store input index in write_to
				rd_indices[write_to] = rd_index_in;
				ready[write_to] = 0;
				valid[write_to] = 1;

				// increment write_to to point to next buffer
				// entry
				write_to = write_to + 1;
			end

			// if committing the instruction at buf[read_from]
			if (commit) begin
				// clear the buffer entry at index read_from
				// pretty sure only valid needs to be cleared
				// but clearing the other stuff for easier
				// visibility while testing
				rd_values[read_from] = 0;
				rd_indices[read_from] = 0;
				ready[read_from] = 0;
				valid[read_from] = 0;

				read_from = read_from + 1;
			end

			if (cdb_enable) begin
				// pretty stupid logic here but I don't see
				// why it needs to be more complex yet
				// TODO: maybe some sanity check assertions?
				// check the valid bit, etc
				rd_values[cdb_tag] = cdb_data;
				ready[cdb_tag] = 1;
				// in the case of an invalid tag, this could
				// set the ready bit on an entry that has
				// valid = 0
			end
		end
	end
endmodule
