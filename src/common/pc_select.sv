module pc_select #(parameter XLEN=32) (
	input logic [XLEN-1:0] pc_plus_four,
	input logic [XLEN-1:0] evaluated_next_instruction,
	input logic [XLEN-1:0] predicted_next_instruction,
	
	input logic evaluated_branch_mispredicted,
	input logic predicted_branch_predicted_taken,

	output logic [XLEN-1:0] pc_next
	);

	always_comb
		// if the branch was mispredicted, we need to set pc to the
		// correct next instruction
		if (evaluated_branch_mispredicted)
			pc_next = evaluated_next_instruction;

		// if we are predicting a branch taken, select the new branch
		// target
		else if (predicted_branch_predicted_taken)
			pc_next = predicted_next_instruction;

		// evaluated branch was not mispredicted, nor are we
		// predicting a branch, or this is just a normal instruction
		else
			pc_next = pc_plus_four;
endmodule
