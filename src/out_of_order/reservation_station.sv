module reservation_station #(parameter XLEN=32, parameter TAG_WIDTH=32) (
	input logic clk,
	input logic reset,

	input logic enable,
	input logic dispatched_in,	// response from FU that instruction has begun execution

	/*
	 * using terminology from Hennessy & Patterson book
	 * q = tag, v = value
	 */
	input logic [TAG_WIDTH-1:0] q1_in,
	input logic [XLEN-1:0] v1_in,
	input logic [TAG_WIDTH-1:0] q2_in,
	input logic [XLEN-1:0] v2_in,
	input logic [2:0] alu_op_in,
	input logic alu_sign_in,

	input logic [TAG_WIDTH-1:0] reorder_buffer_tag_in,

	input logic cdb_active,
	input wire [TAG_WIDTH-1:0] cdb_tag,
	input wire [XLEN-1:0] cdb_data,

	output logic [TAG_WIDTH-1:0] q1_out,
	output logic [XLEN-1:0] v1_out,
	output logic [TAG_WIDTH-1:0] q2_out,
	output logic [XLEN-1:0] v2_out,
	output logic [2:0] alu_op_out,
	output logic alu_sign_out,

	output logic [TAG_WIDTH-1:0] reorder_buffer_tag_out,

	output logic busy,
	output logic ready_to_execute
	);

	logic dispatched;	// FF to track that the instruction has been accepted by the FU

	// signals that determine whether we need to store the value on the
	// cdb in v1 and/or v2
	logic read_cdb_data_op1;
	logic read_cdb_data_op2;

	// if enable is set, we're gonna be reading the value on qN_in
	// and see if that tag is on the CDB.  else, we're just comparing
	// cdb_tag against what's already in qN_out
	assign read_cdb_data_op1 = ((enable ? q1_in : q1_out) == cdb_tag) && cdb_active;
	assign read_cdb_data_op2 = ((enable ? q2_in : q2_out) == cdb_tag) && cdb_active;

	assign ready_to_execute = busy && !dispatched && q1_out == 0 && q2_out == 0;

	always @(posedge clk) begin
		// reset if signal is set or the stored ROB tag is seen on the CDB
		if (!reset || (cdb_active && cdb_tag == reorder_buffer_tag_out)) begin
			q1_out <= 0;
			v1_out <= 0;
			q2_out <= 0;
			v2_out <= 0;
			alu_op_out <= 0;
			alu_sign_out <= 0;
			reorder_buffer_tag_out <= 0;
			busy <= 0;
			dispatched <= 0;
		end else begin
			// store 0 if the tag matched the cdb tag, else store
			// input if enable, else retain previous tag
			q1_out <= (read_cdb_data_op1) ? 'b0 : (enable) ? q1_in : q1_out;
			// store cdb data if the tag matches, else store input
			// if enable, else retain previous data value
			v1_out <= (read_cdb_data_op1) ? cdb_data : (enable) ? v1_in : v1_out;

			// same logic as above for the second operand
			q2_out <= (read_cdb_data_op2) ? 'b0 : (enable) ? q2_in : q2_out;
			v2_out <= (read_cdb_data_op2) ? cdb_data : (enable) ? v2_in : v2_out;

			dispatched <= dispatched_in;

			// only update the rest of the signals if enable is set, meaning an
			// instruction is being stored in the reservation stations
			if (enable) begin
				reorder_buffer_tag_out <= reorder_buffer_tag_in;
				alu_op_out <= alu_op_in;
				alu_sign_out <= alu_sign_in;
				busy <= 1;	// busy because it has read in an instruction!
			end
		end
	end
endmodule
