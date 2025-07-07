module single_cycle #(parameter XLEN=32) (
	input logic clk,
	input logic reset
);
	logic [31:0] instruction;

	logic [4:0] rs1_index;
	logic [4:0] rs2_index;
	logic [4:0] rd_index;

	logic [XLEN-1:0] rs1;
	logic [XLEN-1:0] rs2;
	logic [XLEN-1:0] rd;

	logic [XLEN-1:0] immediate;

	logic [1:0] alu_op1_src;
	logic alu_op2_src;
	logic [1:0] rd_select;

	logic branch;
	logic branch_if_zero;
	logic jump;
	logic branch_taken;
	logic branch_mispredicted;

	logic rf_write_en;
	logic mem_write_en;

	logic [XLEN-1:0] alu_op1;
	logic [XLEN-1:0] alu_op2;
	logic [2:0] alu_operation;
	logic alu_sign;
	logic [XLEN-1:0] alu_result;
	logic alu_zero;

	logic [XLEN-1:0] memory_data_out;

	logic [XLEN-1:0] pc;
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] branch_target;
	logic [XLEN-1:0] evaluated_branch_result;
	logic [XLEN-1:0] pc_next;

	memory #(.XLEN(XLEN), .MEM_FILE("program.hex")) instruction_memory (
		.clk(clk),
		.reset(reset),
		.address(pc_next),
		.write_en(1'b0),
		.data_in({XLEN{1'b0}}),
		.data_out(instruction));

	instruction_decode instruction_decode(
		.instruction(instruction),
		.rs1(rs1_index),
		.rs2(rs2_index),
		.rd(rd_index),
		.immediate(immediate),
		.op1_src(alu_op1_src),
		.op2_src(alu_op2_src),
		.rd_select(rd_select),
		.alu_op(alu_operation),
		.sign(alu_sign),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.jump(jump),
		.rf_write_en(rf_write_en),
		.mem_write_en(mem_write_en));

	rf_wb_select rf_wb_select(
		.alu_result(alu_result),
		.memory_data_out(memory_data_out),
		.pc_plus_four(pc_plus_four),
		.select(rd_select),
		.rd(rd));

	register_file rf(
		.clk(clk),
		.reset(reset),
		.rs1_index(rs1_index),
		.rs2_index(rs2_index),
		.rd_index(rd_index),
		.rd(rd),
		.write_en(rf_write_en),
		.rs1(),
		.rs2());

	assign pc_plus_four = pc + 4;
	assign branch_target = pc_plus_four + immediate;

	alu_operand_select alu_operand_select(
		.rs1(rs1),
		.rs2(rs2),
		.immediate(immediate),
		.pc(pc),
		.alu_op1_src(alu_op1_src),
		.alu_op2_src(alu_op2_src),
		.alu_op1(alu_op1),
		.alu_op2(alu_op2));

	alu alu(
		.a(alu_op1),
		.b(alu_op2),
		.op(alu_operation),
		.sign(alu_sign),
		.result(alu_result),
		.zero(alu_zero));

	memory data_memory(
		.clk(clk),
		.reset(reset),
		.address(alu_result),
		.write_en(mem_write_en),
		.data_in(rs2),
		.data_out(memory_data_out));

	branch_evaluator branch_evaluator(
		.pc_plus_four(pc_plus_four),
		.branch_target(branch_target),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.zero(alu_zero),
		.branch_prediction(1'b0),
		.next_instruction(evaluated_branch_result),
		.branch_mispredicted(branch_mispredicted));

	pc_select pc_select(
		.pc_plus_four(pc_plus_four),
		.evaluated_branch_result(evaluated_branch_result),
		.predicted_branch_target(32'b0),
		.evaluated_branch_mispredicted(branch_mispredicted),
		.predicted_branch_taken(1'b0),	// no prediction in single cycle
		.pc_next(pc_next));

	register #(.N_BITS(32)) pc_register(
		.clk(clk),
		.reset(reset),
		.d(pc_next),
		.q(pc));
endmodule
