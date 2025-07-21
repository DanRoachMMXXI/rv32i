interface branch_predictor_if #(parameter XLEN=32) ();
	// inputs
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] immedaite;
	logic jump;
	logic branch;

	// outputs
	logic [XLEN-1:0] branch_target;
	logic branch_taken;
endinterface
