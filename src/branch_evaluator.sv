module branch_evaluator #(parameter XLEN=32) (
	input logic jump,
	input logic branch,
	input logic branch_if_zero,
	input logic zero,

	output logic branch_taken
	);

	// target jump address is already computed in decode stage
	// to be used for prediction, so we'll just pass that through
	// the pipeline and use this signal to select it
	assign branch_taken = jump || (branch && (branch_if_zero == zero)); 
endmodule
