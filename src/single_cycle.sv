module single_cycle #(parameter XLEN=32) ();
	logic [31:0] instruction;

	logic [4:0] rs1;
	logic [4:0] rs2;
	logic [4:0] rd;

	logic [XLEN-1:0] immediate;

	logic [1:0] alu_op1_src;
	logic alu_op2_src;

	logic branch;
	logic branch_if_zero;
	logic jump;

	logic [XLEN-1:0] branch_target;

	logic rf_write_en;
	logic mem_write_en;

	logic [XLEN-1:0] alu_op1;
	logic [XLEN-1:0] alu_op2;
	logic [2:0] alu_operation;
	logic alu_sign;
	logic [XLEN-1:0] alu_result;
	logic alu_zero;

	instruction_decode instruction_decode(
		.instruction(instruction),
		.rs1(rs1),
		.rs2(rs2),
		.rd(rd),
		.immediate(immediate),
		.op1_src(alu_op1_src),
		.op2_src(alu_op2_src),
		.alu_op(alu_operation),
		.sign(alu_sign),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.jump(jump),
		.rf_write_en(rf_write_en),
		.mem_write_en(mem_write_en));

	assign branch_target = pc_next + immediate;

	alu alu(
		.a(alu_op1),
		.b(alu_op2),
		.op(alu_operation),
		.sign(alu_sign),
		.result(alu_result),
		.zero(alu_zero));
endmodule
