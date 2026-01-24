module pc_mux #(parameter XLEN=32) (
	input logic [XLEN-1:0]	pc,
	input logic [XLEN-1:0]	predicted_next_instruction,
	input logic [XLEN-1:0]	exception_next_instruction,

	input logic		instruction_length,

	input logic		prediction,
	input logic		exception,

	output logic [XLEN-1:0]	pc_next
);
	always_comb begin
		if (exception)
			pc_next = exception_next_instruction;
		else if (prediction)
			pc_next = predicted_next_instruction;
		else
			pc_next = pc + (instruction_length ? XLEN'(4) : XLEN'(2));
	end
endmodule
