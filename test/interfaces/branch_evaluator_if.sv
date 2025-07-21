interface branch_evaluator #(parameter XLEN=32) ();
	// inputs
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] branch_target;
	logic branch;
	logic branch_if_zero;
	logic zero;
	logic branch_prediction;

	// outputs
	logic [XLEN-1:0] next_instruction;
	logic branch_mispredicted;
endinterface
