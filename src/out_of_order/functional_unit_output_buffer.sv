module functional_unit_output_buffer #(parameter XLEN=32, TAG_WIDTH=32) (
	input clk,
	input reset,

	input logic [XLEN-1:0]		value,
	input logic [TAG_WIDTH-1:0]	tag,
	input logic			exception,
	input logic			redirect_mispredicted,	// just wire this to 0 if it's not connected to a redirect FU
	input logic			write_en,

	output logic not_empty,	// signals to the data bus arbiter that this buffer needs
				// to write to the data_bus.  simply valid[read_from]

	// signals for the data bus that this functional unit is publishing
	// data to.  this is the CDB for the ALU FU.  the memory address FU
	// publishes to an address bus that only goes to the reorder buffer.
	input logic data_bus_permit,	// permit access to write to the data bus,
					// probably use to increment counter
	output wire [XLEN-1:0] data_bus_data,
	output wire [TAG_WIDTH-1:0] data_bus_tag,
	output wire data_bus_exception,
	output wire data_bus_redirect_mispredicted,	// leave this port unconnected if not buffering redirects

	// only have these set as outputs for debugging, after more extensive
	// testing I'll remove them from the port list and uncomment the
	// internal signals.  < TODO
	output logic [1:0] read_from,
	output logic [1:0] write_to
	);

	logic [3:0][XLEN-1:0]		values;
	logic [3:0][TAG_WIDTH-1:0]	tags;
	logic [3:0]			exceptions;
	logic [3:0]			redirect_mispredicted_buf;
	logic [3:0]			valid;

	// logic [1:0] read_from;
	// logic [1:0] write_to;

	assign not_empty = valid[read_from];

	/*
	 * signal from the data bus arbiter immediately puts the value on the CDB,
	 * and data_bus_permit then changes the valid bit of the entry that was
	 * broadcast to 0 on the next clock cycle.
	 */
	assign data_bus_data = data_bus_permit ? values[read_from] : {XLEN{1'bZ}};
	assign data_bus_tag = data_bus_permit ? tags[read_from] : {TAG_WIDTH{1'bZ}};
	assign data_bus_exception = data_bus_permit ? exceptions[read_from] : 1'bZ;
	assign data_bus_redirect_mispredicted = data_bus_permit ? redirect_mispredicted_buf[read_from] : 1'bZ;

	always_ff @ (posedge clk) begin
		if (!reset) begin
			read_from <= 0;
			write_to <= 0;

			for (int i = 0; i < 4; i = i + 1) begin
				values[i] <= 0;
				tags[i] <= 0;
				valid[i] <= 0;
				exceptions[i] <= 0;
				redirect_mispredicted_buf[i] <= 0;
			end
		end else begin
			/*
			 * I don't think I need to check for overflow here.
			 * The buffer is four entries for a FU with a depth of
			 * 1 and only attached to 1 reservation station.
			 * If I ever do something where the number of
			 * reservation stations is greater than the FU
			 * pipeline depth or the output buffer size, then
			 * overflow may become possible.
			 */
			if (write_en) begin
				values[write_to] <= value;
				tags[write_to] <= tag;
				exceptions[write_to] <= exception;
				redirect_mispredicted_buf[write_to] <= redirect_mispredicted;
				valid[write_to] <= 1;

				write_to <= write_to + 1;
			end

			if (data_bus_permit) begin
				valid[read_from] <= 0;	// data is written, so entry in the buffer is no longer valid
				read_from <= read_from + 1;
			end
		end
	end
endmodule
