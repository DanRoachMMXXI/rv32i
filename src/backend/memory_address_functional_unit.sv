module memory_address_functional_unit #(parameter XLEN=32, parameter ROB_TAG_WIDTH) (
	// address inputs and outputs
	input logic [XLEN-1:0]			base,
	input logic [XLEN-1:0]			offset,
	input logic [ROB_TAG_WIDTH-1:0]		rob_tag_in,
	output logic [XLEN-1:0]			result,
	output logic [ROB_TAG_WIDTH-1:0]	rob_tag_out,

	// reservation station signals
	input logic				ready_to_execute,
	output logic				accept,

	output logic				write_to_buffer
	);

	assign accept = ready_to_execute;
	assign result = base + offset;
	assign rob_tag_out = rob_tag_in;
	assign write_to_buffer = ready_to_execute;
endmodule
