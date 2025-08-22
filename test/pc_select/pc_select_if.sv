interface pc_select_if #(parameter XLEN=32) ();
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] evaluated_next_instruction;
	logic [XLEN-1:0] predicted_next_instruction;
	logic evaluated_branch_mispredicted;
	logic predicted_branch_predicted_taken;
	logic [XLEN-1:0] pc_next;
endinterface
