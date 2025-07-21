interface pc_select #(parameter XLEN=32) ();
	// inputs
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] evaluated_branch_result;
	logic [XLEN-1:0] predicted_branch_target;
	logic evaluated_branch_mispredicted;
	logic predicted_branch_taken;

	// outputs
	logic [XLEN-1:0] pc_next;
endinterface
