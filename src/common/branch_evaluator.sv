/*
* terminology:
* branch_target: the destination of the branch IF TAKEN
* next_instruction: the result of the branch, or in other words, the
*                   instruction that will be fetched after the branch
* predicted: prefix denoting that the value corresponds to what was computed
*            in the branch prediction stage
* evaluted: prefix denoting that the value corresponds to the computation of
*           the branch using the REAL values, in other words NOT SPECULATED
*/
module branch_evaluator #(parameter XLEN=32) (
	input logic [XLEN-1:0] pc_plus_four,
	input logic [XLEN-1:0] predicted_next_instruction,
	input logic [XLEN-1:0] evaluated_branch_target,	// result from ALU

	input logic jump,	// used to make sure we only say a jump is mispredicted if the values mismatch
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

	logic branch_taken;
	assign branch_taken = jump || (branch && (branch_if_zero == zero));

	// target jump address is already computed in decode stage
	// to be used for prediction, so we'll just pass that through
	// the pipeline and use this signal to select it
	always_comb
		if (branch_taken)
			next_instruction = evaluated_branch_target;
		else
			next_instruction = pc_plus_four;

	/*
	 * branches only compute targets of pc + immediate, so a branch is
	 * only mispredicted if we mispredict whether it's taken.
	 * jumps are always taken, but we may need to speculate the
	 * destination if it comes from a register, so a jump is mispredicted
	 * if the targets don't match.  we compare the "next_instruction"
	 * cause that's the only thing that really matters.
	 */
	assign branch_mispredicted = (branch_taken != branch_prediction)
			|| (jump && (next_instruction != predicted_next_instruction));
endmodule
