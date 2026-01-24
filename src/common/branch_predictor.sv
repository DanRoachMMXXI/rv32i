module branch_predictor #(parameter XLEN=32) (
	input logic [XLEN-1:0] pc,	// currently used to determine whether jump is forward or backward
						// will be used to reference branch history
	input logic [XLEN-1:0] branch_target,

	/*
	 * TODO: figure out how the complex branch prediction algorithms work.
	 * you might wind up moving the computation for branch_target outside
	 * of this module anyways just for things to be a bit more logically
	 * organized.
	 * it's also possible that branch prediction algoriths work based on
	 * the target address, which would then make branch_target an input to
	 * this module, but idk, that's why it's a TODO
	 */

	input logic jump,
	input logic branch,

	output logic branch_predicted_taken
	);

	always_comb begin
		if (jump)
			branch_predicted_taken = 1;
		else if (branch)
			// this is where we will need to predict branch
			// for now, we'll do static:
			// predict taken if immediate is negative, predict not
			// taken if immediate is positive
			if (branch_target < pc)
				branch_predicted_taken = 1;
			else
				branch_predicted_taken = 0;
		else
			branch_predicted_taken = 0;
	end

endmodule
