interface branch_predictor_if #(parameter XLEN=32) ();
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] branch_target;
	logic jump;
	logic branch;
	logic branch_predicted_taken;
endinterface
