// TODO: need to figure out how we are going to get operand values that are
// stored in the reorder buffer.  A problem for another day though.
module reservation_station #(parameter XLEN=32, parameter TAG_WIDTH=32) (
	input logic clk,
	input logic reset,	// I think this will be used to flush the
				// reservation station on mispredicts
	input logic enable,	// enable will case the station to store a new instruction,
				// it will NOT stop from reading the value on the CDB

	input logic [TAG_WIDTH-1:0] reorder_buffer_tag_in,
	input logic [2:0] alu_op_in,
	input logic [TAG_WIDTH-1:0] op1_tag_in,
	input logic [XLEN-1:0] op1_data_in,
	input logic [TAG_WIDTH-1:0] op2_tag_in,
	input logic [XLEN-1:0] op2_data_in,

	input logic cdb_enable,		// just guessing that this signal will exist
	input logic [TAG_WIDTH-1:0] cdb_tag,
	input logic [XLEN-1:0] cdb_data,

	output logic busy_out,

	output logic ready_out,

	output logic [TAG_WIDTH-1:0] reorder_buffer_tag_out,
	output logic [2:0] alu_op_out,
	output logic [XLEN-1:0] op1_data_out,
	output logic [XLEN-1:0] op2_data_out
	);

	logic ready;

	// signals that determine whether we need to store the value on the
	// cdb in op1 and/or op2
	logic read_cdb_data_op1;
	logic read_cdb_data_op2;

	// registers for all the data the reservation station stores
	reg [TAG_WIDTH-1:0] reorder_buffer_tag;
	reg [2:0] alu_op;
	reg [TAG_WIDTH-1:0] op1_tag;
	reg [XLEN-1:0] op1_data;
	reg [TAG_WIDTH-1:0] op2_tag;
	reg [XLEN-1:0] op2_data;
	reg busy;

	// if enable is set, we're gonna be reading the value on opN_tag_in
	// and see if that tag is on the CDB.  else, we're just comparing
	// against what's already in opN_tag
	assign read_cdb_data_op1 = ((enable ? op1_tag_in : op1_tag) == cdb_tag) && cdb_enable;
	assign read_cdb_data_op2 = ((enable ? op2_tag_in : op2_tag) == cdb_tag) && cdb_enable;

	always @(posedge clk) begin
		// clear/flush the contents of the buffer if active low reset
		// signal or if the previously stored instruction has been
		// issued via the ready signal
		if (!reset || ready) begin
			reorder_buffer_tag = 0;
			alu_op = 0;
			op1_tag = 0;
			op1_data = 0;
			op2_tag = 0;
			op2_data = 0;
			busy = 0;

		// enable is the signal that tells us to load the instruction
		// at the station's inputs
		end else begin
			// store 0 if the tag matched the cdb tag, else store
			// input if enable, else retain previous tag
			op1_tag = (read_cdb_data_op1) ? 'b0 : (enable) ? op1_tag_in : op1_tag;
			// store cdb data if the tag matches, else store input
			// if enable, else retain previous data value
			op1_data = (read_cdb_data_op1) ? cdb_data : (enable) ? op1_data_in : op1_data;

			// same logic as above for op2
			op2_tag = (read_cdb_data_op2) ? 'b0 : (enable) ? op2_tag_in : op2_tag;
			op2_data = (read_cdb_data_op2) ? cdb_data : (enable) ? op2_data_in : op2_data;

			// only update the rest of the signals if enable is set
			if (enable) begin
				// TODO: some of these signals that aren't updated
				// could just be put in a register from register.sv
				// looks like render_buffer_tag and alu_op
				reorder_buffer_tag = reorder_buffer_tag_in;
				alu_op = alu_op_in;
				busy = 1;
			end
		end
	end

	// Instruction is ready if both tags are 0 and busy is set, meaning
	// the station is currently storing an instruction.
	// ready_out is just the output pin for the ready signal.  The only
	// reason I did this is because the ready signal is reused internally
	// to flush the contents of the station once an instruction has been
	// issued
	assign ready = (op1_tag == 0) & (op2_tag == 0) & busy;

	assign reorder_buffer_tag_out = reorder_buffer_tag;
	assign alu_op_out = alu_op;
	assign op1_data_out = op1_data;
	assign op2_data_out = op2_data;
	assign ready_out = ready;
endmodule
