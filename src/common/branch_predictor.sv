module branch_predictor #(parameter XLEN=32) (
	input logic [XLEN-1:0] pc_plus_four,	// currently used to determine whether jump is forward or backward
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

	/*
	 * TODO
	 * From pg 31 of the ISA: (in context of prediction for JALR)
	 * Return-address prediction stacks are a common feature of high-performance instruction-fetch units,
	 * but require accurate detection of instructions used for procedure calls and returns to be effective. For
	 * RISC-V, hints as to the instructions' usage are encoded implicitly via the register numbers used. A JAL
	 * instruction should push the return address onto a return-address stack (RAS) only when rd is 'x1' or x5.
	 * JALR instructions should push/pop a RAS as shown in Table 3.
	 *
	 * so basically branch prediction will have to have a separate thing
	 * for predicting the base address (which gets the immediate added to
	 * it) for JALR instructions.  this will be it's own subcomponent
	 * which will be the source of the base value, selected by the
	 * branch_base signal from instruction_decode, added to the immediate
	 * and provided into this subcomponent via the branch_target signal,
	 * as well as being forwarded through the pipeline for reference in
	 * the branch evaluator.
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
			if (branch_target < pc_plus_four)
				branch_predicted_taken = 1;
			else
				branch_predicted_taken = 0;
		else
			branch_predicted_taken = 0;
	end

endmodule
