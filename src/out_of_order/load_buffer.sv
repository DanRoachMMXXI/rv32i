/*
 * ugh
 * ChatGPT says the load buffer tracks loads from issue to completion/commit,
 * making this a lot more complicated than I thought
 */
interface load_buffer_entry #(parameter XLEN);
endinterface
/*
 * Tracks pending load operations and issues them to the memory when the
 * address is computed and the memory unit is available.
 * TODO: this must NOT issue a load if there is a store in the ROB OR if
 * forwarding is implemented from that store instruction (pg 217)
 */
module load_buffer #(parameter XLEN=32, parameter TAG_WIDTH=32, parameter BUF_SIZE=16) (
	input logic clk,
	input logic reset,

	// I dislike "store load"
	// it means store (a load instruction) IN THE BUFFER
	input logic store_load_instr,
	input logic [XLEN-1:0] address_in,
	input logic [TAG_WIDTH-1:0] reorder_buffer_tag_in,

	input logic issue_load,

	output logic [XLEN-1:0] address_out,

	// clearly when a load is performed, it needs to be broadcast to the
	// CDB with the corresponding ROB tag.
	output logic [TAG_WIDTH-1:0] reorder_buffer_tag_out
	);

	logic [$clog2(BUF_SIZE)-1:0] read_from;
	logic [$clog2(BUF_SIZE)-1:0] write_to;

	always_ff @ (posedge clk) begin
		if (!reset) begin
			read_from <= 0;
			write_to <= 0;
		end else begin
			// place a new load instruction in the load buffer
			if (store_load_instr) begin

			end
		end
	end
endmodule
