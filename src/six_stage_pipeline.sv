/*
 * signal naming convention:
 * signals start with two letters to designate which stage of the pipeline they
 * belong to.  the stages are as follows:
 * IF - Instruction Fetch
 * ID - Instruction Decode
 * RF - Register File
 * EX - Execute Instruction
 * DM - Data Memory
 * WB - Writeback
 */
module six_stage_pipeline #(parameter XLEN=32, parameter PROGRAM="") (
	input logic clk,
	input logic reset,

	// set these signals as output for verification purposes
	output logic [31:0] instruction,

	output logic [XLEN-1:0] WB_rd
);
	// need to pipeline PC up to EX stage for AUIPC
	// argument might be made to subtract 4 from pc+4 lmao,
	// might be less hardware than 4*XLEN DFFs
	// also might take longer to do the XLEN bit subtraction, esp if it's
	// a giant carry chain
	logic [XLEN-1:0] IF_pc;
	logic [XLEN-1:0] ID_pc;
	logic [XLEN-1:0] RF_pc;
	logic [XLEN-1:0] EX_pc;

	control_signal_bus ID_control_signals;
	control_signal_bus RF_control_signals;
	control_signal_bus EX_control_signals;
	control_signal_bus DM_control_signals;
	control_signal_bus WB_control_signals;

	logic [XLEN-1:0] RF_rs1;
	logic [XLEN-1:0] RF_rs2;

	logic [XLEN-1:0] EX_rs1;
	logic [XLEN-1:0] EX_rs2;

	logic [XLEN-1:0] ID_immediate;
	logic [XLEN-1:0] RF_immediate;
	logic [XLEN-1:0] EX_immediate;

	logic [XLEN-1:0] EX_alu_op1;
	logic [XLEN-1:0] EX_alu_op2;
	logic [XLEN-1:0] EX_alu_result;
	logic [XLEN-1:0] DM_alu_result;
	logic [XLEN-1:0] WB_alu_result;
	logic alu_zero;

	branch_signal_bus RF_branch_signals;
	branch_signal_bus EX_branch_signals;
	branch_signal_bus DM_branch_signals;

	logic [XLEN-1:0] DM_memory_data_out;
	logic [XLEN-1:0] WB_memory_data_out;

	logic [XLEN-1:0] IF_pc_plus_four;
	logic [XLEN-1:0] ID_pc_plus_four;
	logic [XLEN-1:0] RF_pc_plus_four;
	logic [XLEN-1:0] EX_pc_plus_four;
	logic [XLEN-1:0] DM_pc_plus_four;
	logic [XLEN-1:0] WB_pc_plus_four;

	logic [XLEN-1:0] RF_branch_target;	// where it gets computed
	logic [XLEN-1:0] EX_branch_target;
	logic [XLEN-1:0] DM_branch_target;	// where the branch is actually evaluated

	logic [XLEN-1:0] DM_evaluated_next_instruction;
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
		.write_byte_en({4{mem_write_en}}),
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
		.branch_predicted_taken(branch_signals.branch_predicted_taken));

	// Does nothing in a single cycle implementation beyond being provided
	// to the evaluator to determine whether it was mispredicted to send
	// to the pc_select to select the evaluated next instruction or the
	// predicted next instruction.  silly in a single cycle, but will
	// represent the logic used in a pipelined processor.
	logic [XLEN-1:0] predicted_next_instruction;
	assign predicted_next_instruction = branch_signals.branch_predicted_taken ? branch_target : pc_plus_four;

	branch_evaluator #(.XLEN(XLEN)) branch_evaluator(
		// inputs
		.pc_plus_four(pc_plus_four),
		.predicted_next_instruction(predicted_next_instruction),
		.evaluated_branch_target(branch_target),
		.jump(control_signals.jump),
		.branch(control_signals.branch),
		.branch_if_zero(control_signals.branch_if_zero),
		.zero(alu_zero),
		.branch_prediction(branch_signals.branch_predicted_taken),
		// outputs
		.next_instruction(evaluated_next_instruction),
		.branch_mispredicted(branch_signals.branch_mispredicted));

	pc_select #(.XLEN(XLEN)) pc_select(
		.pc_plus_four(pc_plus_four),
		.evaluated_next_instruction(evaluated_next_instruction),
		.predicted_next_instruction(predicted_next_instruction),
		.evaluated_branch_mispredicted(branch_signals.branch_mispredicted),
		.predicted_branch_predicted_taken(branch_signals.branch_predicted_taken),
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
