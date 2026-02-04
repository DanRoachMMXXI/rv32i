// TODO: flushing misspeculated instructions
// Each FU result has its tag stored along with it.  This tag must be used to
// determine whether or not the instruction needs to be flushed.
// This probably looks something like this:
// - read in rob_head and rob_flush_start_index
// - subtract rob_head from the tags[i] and rob_flush_start_index (effectively
// rotating the index alone)
// - compare these "rotated" indices to find out if the instruction is younger
// - flush if younger
// - alternatively, could look into using a phase bit for these age
// comparisons
//
// TODO: not just todo here but noting it quick
// Need to treat architectural exceptions and microarchitectural exceptions
// differently.  microarchitectural exceptions (ordering failures) need to be
// retried.  Architectural exceptions (address misalignment) are VALID and
// need to be committed, just like a branch misprediction.  However, unlike
// branch misprediction, they need to trap into a handler, the implementation
// of which is a later task.
module functional_unit_output_buffer #(parameter XLEN=32, parameter ROB_SIZE, parameter ROB_TAG_WIDTH) (
	input clk,
	input reset,

	input logic [XLEN-1:0]		value,
	input logic [ROB_TAG_WIDTH-1:0]	tag,
	input logic			exception,
	input logic			redirect_mispredicted,	// just wire this to 0 if it's not connected to a redirect FU
	input logic			write_en,

	// signals for the data bus that this functional unit is publishing
	// data to.  this is the CDB for the ALU FU.  the memory address FU
	// publishes to an address bus that only goes to the reorder buffer.
	input logic data_bus_permit,	// permit access to write to the data bus,
					// probably use to increment counter

	output wire [XLEN-1:0] data_bus_data,
	output wire [ROB_TAG_WIDTH-1:0] data_bus_tag,
	output wire data_bus_exception,
	output wire data_bus_redirect_mispredicted,	// leave this port unconnected if not buffering redirects

	output logic not_empty,	// signals to the data bus arbiter that this buffer needs
				// to write to the data_bus.  simply valid[read_from]
	output logic full	// could use this to give priority to allowing this buffer to broadcast
				// TODO: would also be cool to use this to
				// stall the FU so that it holds the result if
				// the buffer is full instead of it just
				// disappearing
	);

	logic [3:0][XLEN-1:0]		values;
	logic [3:0][ROB_TAG_WIDTH-1:0]	tags;
	logic [3:0]			exceptions;
	logic [3:0]			redirect_mispredicted_buf;
	logic [3:0]			valid;

	logic [3:0]			rotated_valid;

	// last_broadcast_index to facilitate round-robin style broadcasting
	// the cdb arbiter will permit the buffer to broadcast, but the buffer
	// will determine which entry is broadcast when it's permitted to
	// broadcast to the CDB
	logic [1:0]	last_broadcast_index;
	logic [1:0]	rotated_next_broadcast_index;
	logic [1:0]	next_broadcast_index;

	logic [3:0]	write_select;

	assign not_empty = |valid;
	assign full = &valid;

	/*
	 * signal from the data bus arbiter immediately puts the value on the CDB,
	 * and data_bus_permit then changes the valid bit of the entry that was
	 * broadcast to 0 on the next clock cycle.
	 */
	assign data_bus_data = data_bus_permit ? values[next_broadcast_index] : {XLEN{1'bZ}};
	assign data_bus_tag = data_bus_permit ? tags[next_broadcast_index] : {ROB_TAG_WIDTH{1'bZ}};
	assign data_bus_exception = data_bus_permit ? exceptions[next_broadcast_index] : 1'bZ;
	assign data_bus_redirect_mispredicted = data_bus_permit ? redirect_mispredicted_buf[next_broadcast_index] : 1'bZ;

	// use a LSB priority select to decide where to write
	lsb_fixed_priority_arbiter #(.N(4)) lsb_prio (
		.in(~valid),
		.out(write_select)
	);

	// select the next element to broadcast (which will only be broadcast
	// if permitted)
	assign rotated_valid = (valid >> last_broadcast_index) | (valid << (4 - last_broadcast_index));
	// use a LSB priority encoder to decide what to broadcast
	lsb_priority_encoder #(.N(4)) broadcast_select (
		.in(rotated_valid),
		.out(rotated_next_broadcast_index),
		.valid()	// redundant with not_empty, which goes to cdb_arbiter to determine if this value is used
	);
	assign next_broadcast_index = rotated_next_broadcast_index + last_broadcast_index;

	// buffer state update logic
	always_ff @(posedge clk) begin
		if (!reset) begin
			last_broadcast_index <= 0;

			for (int i = 0; i < 4; i = i + 1) begin
				valid[i] <= 0;
			end
		end else begin
			for (int i = 0; i < 4; i = i + 1) begin
				if (write_en && write_select[i] /* TODO: && not flushing the instruction being written */) begin
					values[i] <= value;
					tags[i] <= tag;
					exceptions[i] <= exception;
					redirect_mispredicted_buf[i] <= redirect_mispredicted;
					valid[i] <= 1;
				end
			end

			if (data_bus_permit) begin
				valid[next_broadcast_index] <= 0;
				last_broadcast_index <= next_broadcast_index;
			end
		end
	end
endmodule
