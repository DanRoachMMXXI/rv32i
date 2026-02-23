module functional_unit_output_buffer #(parameter XLEN=32, parameter ROB_SIZE, parameter ROB_TAG_WIDTH) (
	input clk,
	input reset,

	input logic [XLEN-1:0]		value_in,
	input logic [ROB_TAG_WIDTH-1:0]	tag_in,
	input logic			uarch_exception_in,
	input logic			arch_exception_in,
	input logic			redirect_mispredicted_in,	// just wire this to 0 if it's not connected to a redirect FU
	input logic			write_en,

	input logic			flush,
	input logic [ROB_TAG_WIDTH-1:0]	flush_start_tag,

	// signals for the data bus that this functional unit is publishing
	// data to.  this is the CDB for the ALU FU.  the memory address FU
	// publishes to an address bus that only goes to the reorder buffer.
	input logic data_bus_permit,	// permit access to write to the data bus,
					// probably use to increment counter

	output wire [XLEN-1:0]		data_bus_data,
	output wire [ROB_TAG_WIDTH-1:0]	data_bus_tag,
	output wire			data_bus_uarch_exception,
	output wire			data_bus_arch_exception,
	output wire			data_bus_redirect_mispredicted,	// leave this port unconnected if not buffering redirects

	output logic not_empty,	// signals to the data bus arbiter that this buffer needs
				// to write to the data_bus.  simply valid[read_from]
	output logic full,	// could use this to give priority to allowing this buffer to broadcast
				// TODO: would also be cool to use this to
				// stall the FU so that it holds the result if
				// the buffer is full instead of it just
				// disappearing

	// debug signals
	output logic [3:0]		valid
	);

	logic [3:0][XLEN-1:0]		values;
	logic [3:0][ROB_TAG_WIDTH-1:0]	tags;
	logic [3:0]			uarch_exceptions;
	logic [3:0]			arch_exceptions;
	logic [3:0]			redirect_mispredicted_buf;
	// logic [3:0]			valid;

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
	assign data_bus_uarch_exception = data_bus_permit ? uarch_exceptions[next_broadcast_index] : 1'bZ;
	assign data_bus_arch_exception = data_bus_permit ? arch_exceptions[next_broadcast_index] : 1'bZ;
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
			valid <= 'b0;
		end else begin
			for (int i = 0; i < 4; i = i + 1) begin
				if (flush && !($signed(tags[i] - flush_start_tag) < 0)) begin: flush_entry
					valid[i] <= 0;
				end: flush_entry
				else if (write_en
					&& write_select[i]
					&& !(flush && !($signed(tag_in - flush_start_tag) < 0)))	// if the instruction is NOT being flushed this cycle
				begin
					values[i] <= value_in;
					tags[i] <= tag_in;
					uarch_exceptions[i] <= uarch_exception_in;
					arch_exceptions[i] <= arch_exception_in;
					redirect_mispredicted_buf[i] <= redirect_mispredicted_in;
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
