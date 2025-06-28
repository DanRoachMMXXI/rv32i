module instruction_decode_tb();
	logic [31:0] instruction;
	logic [4:0] rs1;
	logic [4:0] rs2;
	logic [4:0] rd;

	logic [31:0] immediate;
	logic [1:0] op1_src;
	logic op2_src;
	logic [2:0] alu_op;
	logic sign;
	logic branch;
	logic branch_if_zero;
	logic jump;
	logic rf_write_en;
	logic mem_write_en;

	instruction_decode dut(.instruction(instruction),
				.rs1(rs1),
				.rs2(rs2),
				.rd(rd),
				.immediate(immediate),
				.op1_src(op1_src),
				.op2_src(op2_src),
				.alu_op(alu_op),
				.sign(sign),
				.branch(branch),
				.branch_if_zero(branch_if_zero),
				.jump(jump),
				.rf_write_en(rf_write_en),
				.mem_write_en(mem_write_en));
endmodule
