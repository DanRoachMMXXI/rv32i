module branch_evaluator #(parameter XLEN=32) (
	input logic [XLEN-1:0] pc_plus_four,
	input logic [XLEN-1:0] branch_target,

	input logic branch,
	input logic branch_if_zero,
	input logic zero,
	input logic branch_prediction,

	output logic [XLEN-1:0] next_instruction,
	// branch_mispredicted will be the signal that selects
	// next_instruction to be the value put into the program counter
	// branch_mispredicted will also be the signal used to flush
	// instructions following the misprediction
	output logic branch_mispredicted
	);

	logic branch_taken = (branch_if_zero == zero);

	// target jump address is already computed in decode stage
	// to be used for prediction, so we'll just pass that through
	// the pipeline and use this signal to select it
	always_comb
		if (branch_taken)
			next_instruction = branch_target;
		else
			next_instruction = pc_plus_four;

	assign branch_mispredicted = (branch && (branch_prediction != branch_taken)); 
endmodule
