module functional_unit_output_buffer #(parameter XLEN=32, TAG_WIDTH=32) (
	input clk,
	input reset,

	input logic [XLEN-1:0] value,
	input logic [TAG_WIDTH-1:0] tag,
	input logic write_en,

	output logic not_empty,	// signals to the cdb_arbiter that this buffer needs
				// to write to the cdb.  simply valid[read_from]

	input logic cdb_permit,	// permit access to write to the cdb,
				// probably use to increment counter
	output wire [XLEN-1:0] cdb_data,
	output wire [TAG_WIDTH-1:0] cdb_tag,

	// only have these set as outputs for debugging, after more extensive
	// testing I'll remove them from the port list and uncomment the
	// internal signals.  < TODO
	output logic [1:0] read_from,
	output logic [1:0] write_to
	);

	logic [XLEN-1:0] values [0:3];
	logic [XLEN-1:0] tags [0:3];
	logic valid [0:3];

	// logic [1:0] read_from;
	// logic [1:0] write_to;

	assign not_empty = valid[read_from];

	/*
	 * I THINK this is right: signal from the cdb_arbiter immediately puts
	 * the value on the CDB, and cdb_permit then changes the valid bit of
	 * the entry that was broadcast to 0 on the next clock cycle.
	 * I need to figure out if the cdb_arbiter is a combinational unit...
	 * I think it is.
	 */
	assign cdb_data = cdb_permit ? values[read_from] : 'bZ;
	assign cdb_tag = cdb_permit ? tags[read_from] : 'bZ;

	always_ff @ (posedge clk) begin
		if (!reset) begin
			read_from <= 0;
			write_to <= 0;

			for (int i = 0; i < 4; i = i + 1) begin
				values[i] <= 0;
				tags[i] <= 0;
				valid[i] <= 0;
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
				valid[write_to] <= 1;
				write_to <= write_to + 1;
			end

			if (cdb_permit) begin
				valid[read_from] <= 0;	// data is written, so entry in the buffer is no longer valid
				read_from <= read_from + 1;
			end
		end
	end
endmodule
