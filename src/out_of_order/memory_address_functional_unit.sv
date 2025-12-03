module memory_address_functional_unit #(parameter XLEN=32) (
	// address inputs and outputs
	input logic [XLEN-1:0] base,
	input logic [XLEN-1:0] offset,
	output logic [XLEN-1:0] result,

	// reservation station signals
	input logic ready_to_execute,
	output logic accept,

	output logic write_to_buffer
	);

	assign accept = ready_to_execute;
	assign result = base + offset;
	assign write_to_buffer = ready_to_execute;
endmodule
