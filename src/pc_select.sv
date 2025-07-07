module pc_select #(parameter XLEN=32) (
	input logic [XLEN-1:0] pc_plus_four,
	input logic [XLEN-1:0] evaluated_branch_result,
	input logic [XLEN-1:0] predicted_branch_target,
	
	input logic evaluated_branch_mispredicted,
	input logic predicted_branch_taken,

	output logic [XLEN-1:0] pc_next
	);

	always_comb
		// if the branch was mispredictedd, we need to set pc to the
		// correct next instruction
		if (evaluated_branch_mispredicted)
			pc_next = evaluated_branch_result;

		// if we are predicting a branch taken, select the new branch
		// target
		else if (predicted_branch_taken)
			pc_next = predicted_branch_target;

		// evaluated branch was not mispredicted, nor are we
		// predicting a branch, or this is just a normal instruction
		else
			pc_next = pc_plus_four;
endmodule
