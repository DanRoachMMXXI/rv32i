module single_cycle #(parameter XLEN=32, parameter PROGRAM="") (
	input logic clk,
	input logic reset,

	// set these signals as output for verification purposes
	output logic [XLEN-1:0] pc,
	output logic [31:0] instruction,

	output logic [XLEN-1:0] rd,

	output logic rf_write_en,
	output logic mem_write_en
);
	control_signal_bus control_signals;
	logic [XLEN-1:0] rs1;
	logic [XLEN-1:0] rs2;

	logic [XLEN-1:0] immediate;

	logic [XLEN-1:0] alu_op1;
	logic [XLEN-1:0] alu_op2;
	logic [2:0] alu_operation;
	logic alu_sign;
	logic [XLEN-1:0] alu_result;
	logic alu_zero;

	logic branch_predicted_taken;
	logic branch_mispredicted;

	logic [XLEN-1:0] memory_data_out;
	logic [XLEN-1:0] pc_plus_four;
	logic [XLEN-1:0] branch_target;
	logic [XLEN-1:0] evaluated_next_instruction;
	logic [XLEN-1:0] pc_next;

	// instruction memory
	read_only_async_memory #(.MEM_SIZE(128), .MEM_FILE(PROGRAM)) instruction_memory (
		.clk(clk),
		.reset(reset),
		.address(pc[$clog2(128)-1:0]),
		.read_byte_en(4'b1111),	// always loading 32-bit instruction
		.data_out(instruction));

	instruction_decode #(.XLEN(XLEN)) instruction_decode(
		.instruction(instruction),
		.immediate(immediate),
		.control_signals(control_signals));

	rf_wb_select #(.XLEN(XLEN)) rf_wb_select(
		.alu_result(alu_result),
		.memory_data_out(memory_data_out),
		.pc_plus_four(pc_plus_four),
		.select(control_signals.rd_select),
		.rd(rd));

	register_file #(.XLEN(XLEN)) rf(
		.clk(clk),
		.reset(reset),
		.rs1_index(control_signals.rs1_index),
		.rs2_index(control_signals.rs2_index),
		.rd_index(control_signals.rd_index),
		.rd(rd),
		.write_en(control_signals.rf_write_en),
		.rs1(rs1),
		.rs2(rs2));

	assign pc_plus_four = pc + 4;

	alu_operand_select #(.XLEN(XLEN)) alu_operand_select(
		.rs1(rs1),
		.rs2(rs2),
		.immediate(immediate),
		.pc(pc),
		.alu_op1_src(control_signals.alu_op1_src),
		.alu_op2_src(control_signals.alu_op2_src),
		.alu_op1(alu_op1),
		.alu_op2(alu_op2));

	alu #(.XLEN(XLEN)) alu(
		.a(alu_op1),
		.b(alu_op2),
		.op(control_signals.alu_operation),
		.sign(control_signals.sign),
		.result(alu_result),
		.zero(alu_zero));

	// data memory
	read_write_async_memory #(.MEM_SIZE(128)) data_memory(
		.clk(clk),
		.reset(reset),
		.address(alu_result[$clog2(128)-1:0]),
		.data_in(rs2),

		// no byte-addressing for now
		.read_byte_en(4'b1111),
		.write_byte_en({4{control_signals.mem_write_en}}),
		.data_out(memory_data_out));

	assign branch_target = (control_signals.branch_base ? rs1 : pc_plus_four) + immediate;

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
		.jump(control_signals.jump),
		.branch(control_signals.branch),
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
		.jump(control_signals.jump),
		.branch(control_signals.branch),
		.branch_if_zero(control_signals.branch_if_zero),
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

	register #(.N_BITS(XLEN)) pc_register(
		.clk(clk),
		.reset(reset),
		.d(pc_next),
		.q(pc));

	// just assign these signals to the output ports for verification
	assign rf_write_en = control_signals.rf_write_en;
	assign mem_write_en = control_signals.mem_write_en;
endmodule
