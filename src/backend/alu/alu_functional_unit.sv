module alu_functional_unit #(parameter XLEN=32, parameter ROB_TAG_WIDTH) (
	// ALU signals
	input logic [XLEN-1:0]			a,
	input logic [XLEN-1:0]			b,
	input logic [ROB_TAG_WIDTH-1:0]		rob_tag_in,
	input logic [2:0]			funct3,
	input logic				sign,
	output logic [XLEN-1:0]			result,
	output logic [ROB_TAG_WIDTH-1:0]	rob_tag_out,
	// I don't think the zero field is useful here

	// reservation stations signals
	input logic				ready_to_execute,
	output logic				accept,

	output logic				write_to_buffer	// might need a rename here
	);

	// no complicated logic as this FU is combinational and only attached
	// to one reservation station.  If this were connected to more
	// reservation stations (if it were pipelined for example), it would
	// need to pick which reservation station it was accepting inputs from
	assign accept = ready_to_execute;

	alu #(.XLEN(XLEN)) alu(
		.a(a),
		.b(b),
		.funct3(funct3),
		.sign(sign),
		.result(result),
		.zero());

	// passthrough for now, but if this FU is pipelined it will need to
	// propagate with the instruction being executed
	assign rob_tag_out = rob_tag_in;

	// again no complicated logic as this is combinational.  were this FU
	// pipelined, it would need to carry this forward until the result was
	// ready
	assign write_to_buffer = ready_to_execute;
endmodule
