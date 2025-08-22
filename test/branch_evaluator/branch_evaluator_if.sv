interface branch_evaluator_if #(parameter XLEN=32) ();
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] predicted_next_instruction;
	logic [XLEN-1:0] evaluated_branch_target;
	logic jump;
	logic branch;
	logic branch_if_zero;
	logic zero;
	logic branch_prediction;
	logic [XLEN-1:0] next_instruction;
	logic branch_mispredicted;
endinterface
