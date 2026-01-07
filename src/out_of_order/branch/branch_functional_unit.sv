module branch_functional_unit #(parameter XLEN=32) (
	input logic [XLEN-1:0]	v1,	// rs1 or pc+4
	input logic [XLEN-1:0]	v2,	// immediate

	input logic [XLEN-1:0]	pc_plus_four,
	input logic [XLEN-1:0]	predicted_next_instruction,

	input logic		jump,
	input logic		branch,
	input logic		branch_if_zero,
	input logic		branch_prediction,

	output logic [XLEN-1:0]	next_instruction,
	output logic		branch_mispredicted,

	// reservation stations signals
	input logic		ready_to_execute,
	output logic		accept,

	output logic		write_to_buffer
	);

	// just computing these two signals instead of instantiating an ALU
	logic [XLEN-1:0] evaluated_branch_target;
	assign evaluated_branch_target = v1 + v2;
	logic zero;
	assign zero = evaluated_branch_target == 0;

	branch_evaluator #(.XLEN(XLEN)) branch_evaluator (
		// inputs
		.pc_plus_four(pc_plus_four),
		.predicted_next_instruction(predicted_next_instruction),
		.evaluated_branch_target(evaluated_branch_target),
		.jump(jump),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.zero(zero),
		.branch_prediction(branch_prediction),

		// outputs
		.next_instruction(next_instruction),
		.branch_mispredicted(branch_mispredicted)
	);

	// since FU is only attached to one RS, we accept when the operands
	// are ready
	assign accept = ready_to_execute;
	// since FU is combinational, we output the same cycle we accept the
	// instruction
	assign write_to_buffer = ready_to_execute;
endmodule
