module single_cycle #(parameter XLEN=32, parameter PROGRAM="") (
	input logic clk,
	input logic reset,

	// set these signals as output for verification purposes
	output logic [31:0] instruction,

	output logic [4:0] rs1_index,
	output logic [4:0] rs2_index,
	output logic [4:0] rd_index,

	output logic [XLEN-1:0] rs1,
	output logic [XLEN-1:0] rs2,
	output logic [XLEN-1:0] rd,

	output logic [XLEN-1:0] immediate,

	output logic [1:0] alu_op1_src,
	output logic alu_op2_src,
	output logic [1:0] rd_select,

	output logic branch,
	output logic branch_if_zero,
	output logic jump,
	output logic branch_base,
	output logic branch_predicted_taken,	// this is the prediction
	output logic branch_mispredicted,	// this overwrites a misprediction

	output logic rf_write_en,
	output logic mem_write_en,

	output logic [XLEN-1:0] alu_op1,
	output logic [XLEN-1:0] alu_op2,
	output logic [2:0] alu_operation,
	output logic alu_sign,
	output logic [XLEN-1:0] alu_result,
	output logic alu_zero,

	output logic [XLEN-1:0] memory_data_out,

	output logic [XLEN-1:0] pc,
	output logic [XLEN-1:0] pc_plus_four,
	output logic [XLEN-1:0] branch_target,
	output logic [XLEN-1:0] evaluated_next_instruction,
	output logic [XLEN-1:0] pc_next
);
	instruction_memory #(.MEM_FILE(PROGRAM)) instruction_memory (
		.clk(clk),
		.reset(reset),
		.address(pc),
		.data_in({XLEN{1'b0}}),
		.read_byte_en(4'b1111),	// always loading 32-bit instruction
		.write_byte_en(4'b0000),	// not writing to imem
		.data_out(instruction));

	instruction_decode #(.XLEN(XLEN)) instruction_decode(
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
		.branch_base(branch_base),
		.rf_write_en(rf_write_en),
		.mem_write_en(mem_write_en));

	rf_wb_select #(.XLEN(XLEN)) rf_wb_select(
		.alu_result(alu_result),
		.memory_data_out(memory_data_out),
		.pc_plus_four(pc_plus_four),
		.select(rd_select),
		.rd(rd));

	register_file #(.XLEN(XLEN)) rf(
		.clk(clk),
		.reset(reset),
		.rs1_index(rs1_index),
		.rs2_index(rs2_index),
		.rd_index(rd_index),
		.rd(rd),
		.write_en(rf_write_en),
		.rs1(rs1),
		.rs2(rs2));

	assign pc_plus_four = pc + 4;

	alu_operand_select #(.XLEN(XLEN)) alu_operand_select(
		.rs1(rs1),
		.rs2(rs2),
		.immediate(immediate),
		.pc(pc),
		.alu_op1_src(alu_op1_src),
		.alu_op2_src(alu_op2_src),
		.alu_op1(alu_op1),
		.alu_op2(alu_op2));

	alu #(.XLEN(XLEN)) alu(
		.a(alu_op1),
		.b(alu_op2),
		.op(alu_operation),
		.sign(alu_sign),
		.result(alu_result),
		.zero(alu_zero));

	data_memory data_memory(
		.clk(clk),
		.reset(reset),
		.address(alu_result),
		.data_in(rs2),

		// no byte-addressing for now
		.read_byte_en(4'b1111),
		.write_byte_en({4{mem_write_en}}),
		.data_out(memory_data_out));

	assign branch_target = (branch_base ? rs1 : pc_plus_four) + immediate;

	// obviously the concept of branch prediction in a single cycle
	// microarchitecture is silly, but this is where the logic that
	// identifies branch on unconditional jumps will be in a pipelined
	// microarchitecture.  Since I want to utilize the exact same building
	// blocks for the microarchitectures as much as I can, I'm using this.
	// If it's mispredicted, it just never jumps to the predicted address,
	// because the evaluator knows it's mispredicted and the pc_select
	// will pick the evaluated branch target.
	branch_predictor #(.XLEN(XLEN)) branch_predictor(
		// inputs
		.pc_plus_four(pc_plus_four),
		.branch_target(branch_target),
		.jump(jump),
		.branch(branch),
		// outputs
		.branch_predicted_taken(branch_predicted_taken));

	// Does nothing in a single cycle implementation beyond being provided
	// to the evaluator to determine whether it was mispredicted to send
	// to the pc_select to select the evaluated next instruction or the
	// predicted next instruction.  silly in a single cycle, but will
	// represent the logic used in a pipelined processor.
	logic [XLEN-1:0] predicted_next_instruction;
	assign predicted_next_instruction = branch_predicted_taken ? branch_target : pc_plus_four;

	branch_evaluator #(.XLEN(XLEN)) branch_evaluator(
		// inputs
		.pc_plus_four(pc_plus_four),
		.predicted_next_instruction(predicted_next_instruction),
		.evaluated_branch_target(branch_target),
		.jump(jump),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.zero(alu_zero),
		.branch_prediction(branch_predicted_taken),
		// outputs
		.next_instruction(evaluated_next_instruction),
		.branch_mispredicted(branch_mispredicted));

	pc_select #(.XLEN(XLEN)) pc_select(
		.pc_plus_four(pc_plus_four),
		.evaluated_next_instruction(evaluated_next_instruction),
		.predicted_next_instruction(predicted_next_instruction),
		.evaluated_branch_mispredicted(branch_mispredicted),
		.predicted_branch_predicted_taken(branch_predicted_taken),
		.pc_next(pc_next));

	register #(.N_BITS(32)) pc_register(
		.clk(clk),
		.reset(reset),
		.d(pc_next),
		.q(pc));
endmodule
