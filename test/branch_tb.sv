// Combining the tests for the branch_predictor and branch_evaluator because
// they're going to be running on mostly the same stimuli
module branch_tb();
	logic [31:0] pc_next;
	logic [31:0] immediate;
	logic jump;
	logic branch;
	logic branch_if_zero;
	logic zero;
	logic [31:0] branch_target;
	logic branch_taken_predictor;
	logic branch_taken_evaluator;

	branch_predictor predictor(
		.pc_next(pc_next),
		.immediate(immediate),
		.jump(jump),
		.branch(branch),
		.branch_target(branch_target),
		.branch_taken(branch_taken_predictor));
	
	branch_evaluator evalutaor(
		.jump(jump),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.zero(zero),
		.branch_taken(branch_taken_evaluator));

	initial begin
		// Initial values for pc_next and immediate
		pc_next = 12;
		immediate = 20;
		
		branch = 0;
		branch_if_zero = 0;
		zero = 0;
		jump = 0;

		// expecting branch_target == 12, no branch signals
		#1
		print_results(0, 0);

		jump = 1;
		#1
		print_results(1, 1);

		jump = 0;
		branch = 1;
		branch_if_zero = 1;
		zero = 1;
		#1
		// expecting predict not taken because immediate is
		// non-negative
		print_results(0, 1);

		immediate = -4;
		#1
		print_results(1, 1);

		branch_if_zero = 0;
		#1
		// predicted taken because jump is negative, not taken because
		// branch_if_zero != zero, as if the ALU result determined
		// that the branch shouldn't be taken
		print_results(1, 0);
	end

	task print_results(
		input expected_predictor,
		input expected_evaluator);

		$display("branch: %d, branch_if_zero: %d, zero: %d, jump: %d", branch, branch_if_zero, zero, jump);
		$display("branch_taken_predictor: expected %d, actual %d", expected_predictor, branch_taken_predictor);
		$display("branch_taken_evaluator: expected %d, actual %d", expected_evaluator, branch_taken_evaluator);
		$display("");
	endtask
endmodule
