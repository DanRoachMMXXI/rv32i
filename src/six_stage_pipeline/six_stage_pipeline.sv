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
 *
 * For a while I thought I didn't need a WB stage since the output of the data
 * memory could just be written straight to the RF instead of a pipeline
 * register.  However, I realized that once I interface this with
 * a synchronous memory element, there will need to be a WB stage to store the
 * loaded value since the it won't be available until the following clock
 * cycle.
 */
module six_stage_pipeline #(parameter XLEN=32, parameter PROGRAM="") (
	input logic clk,
	input logic reset,

	// set these signals as output for verification purposes
	output logic [XLEN-1:0] IF_pc,
	output logic [31:0] instruction,

	output logic [XLEN-1:0] WB_rd,

	output logic rf_write_en,
	output logic mem_write_en
);
	// need to pipeline PC up to EX stage for AUIPC
	// argument might be made to subtract 4 from pc+4 lmao,
	// might be less hardware than 4*XLEN DFFs
	// also might take longer to do the XLEN bit subtraction, esp if it's
	// a giant carry chain
	// logic [XLEN-1:0] IF_pc;
	logic [XLEN-1:0] ID_pc;
	logic [XLEN-1:0] RF_pc;
	logic [XLEN-1:0] EX_pc;

	logic [31:0] IF_instruction;
	logic [31:0] ID_instruction;

	control_signal_bus ID_control_signals;
	control_signal_bus RF_control_signals;
	control_signal_bus EX_control_signals;
	control_signal_bus DM_control_signals;
	control_signal_bus WB_control_signals;

	logic [XLEN-1:0] RF_register_file_rs1;	// the raw output of the register file
	logic [XLEN-1:0] RF_rs1;	// rs1 after data forwarding
	logic [XLEN-1:0] EX_rs1;

	logic [XLEN-1:0] RF_register_file_rs2;	// the raw output of the register file
	logic [XLEN-1:0] RF_rs2;	// rs2 after data forwarding
	logic [XLEN-1:0] EX_rs2;
	logic [XLEN-1:0] DM_rs2;	// goes into data memory

	logic [XLEN-1:0] ID_immediate;
	logic [XLEN-1:0] RF_immediate;
	logic [XLEN-1:0] EX_immediate;

	logic [XLEN-1:0] EX_alu_op1;
	logic [XLEN-1:0] EX_alu_op2;

	logic [XLEN-1:0] EX_alu_result;
	logic [XLEN-1:0] DM_alu_result;
	logic [XLEN-1:0] WB_alu_result;
	logic EX_alu_zero;
	logic DM_alu_zero;

	logic RF_branch_predicted_taken;
	logic EX_branch_predicted_taken;
	logic DM_branch_predicted_taken;
	logic DM_branch_mispredicted;

	logic [XLEN-1:0] RF_predicted_next_instruction;
	logic [XLEN-1:0] EX_predicted_next_instruction;
	logic [XLEN-1:0] DM_predicted_next_instruction;

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

	logic stall;

	always_ff @(posedge clk) begin: pc_register
		if (!reset)
			IF_pc <= 0;
		else if (!stall)
			IF_pc <= pc_next;
	end: pc_register

	always_ff @(posedge clk) begin: IF_ID_pipeline_register
		if (!reset || RF_branch_predicted_taken || DM_branch_mispredicted) begin
			ID_pc <= 0;
			ID_pc_plus_four <= 0;
			ID_instruction <= 0;
		end else if (!stall) begin
			ID_pc <= IF_pc;
			ID_pc_plus_four <= IF_pc_plus_four;
			ID_instruction <= IF_instruction;
		end
	end: IF_ID_pipeline_register

	always_ff @(posedge clk) begin: ID_RF_pipeline_register
		if (!reset || stall || RF_branch_predicted_taken || DM_branch_mispredicted) begin
			RF_pc <= 0;
			RF_pc_plus_four <= 0;
			RF_control_signals <= 0;
			RF_immediate <= 0;
		end else begin
			RF_pc <= ID_pc;
			RF_pc_plus_four <= ID_pc_plus_four;
			RF_control_signals <= ID_control_signals;
			RF_immediate <= ID_immediate;
		end
	end: ID_RF_pipeline_register

	always_ff @(posedge clk) begin: RF_EX_pipeline_register
		if (!reset || DM_branch_mispredicted) begin
			EX_pc <= 0;
			EX_pc_plus_four <= 0;
			EX_control_signals <= 0;
			EX_branch_predicted_taken <= 0;
			EX_branch_target <= 0;
			EX_predicted_next_instruction <= 0;
			EX_rs1 <= 0;
			EX_rs2 <= 0;
			EX_immediate <= 0;
		end else begin
			EX_pc <= RF_pc;
			EX_pc_plus_four <= RF_pc_plus_four;
			EX_control_signals <= RF_control_signals;
			EX_branch_predicted_taken <= RF_branch_predicted_taken;
			EX_branch_target <= RF_branch_target;
			EX_predicted_next_instruction <= RF_predicted_next_instruction;
			EX_rs1 <= RF_rs1;
			EX_rs2 <= RF_rs2;
			EX_immediate <= RF_immediate;
		end
	end: RF_EX_pipeline_register

	always_ff @(posedge clk) begin: EX_DM_pipeline_register
		if (!reset || DM_branch_mispredicted) begin
			DM_pc_plus_four <= 0;
			DM_control_signals <= 0;
			DM_branch_predicted_taken <= 0;
			DM_branch_target <= 0;
			DM_predicted_next_instruction <= 0;
			DM_rs2 <= 0;
			DM_alu_result <= 0;
			DM_alu_zero <= 0;
		end else begin
			DM_pc_plus_four <= EX_pc_plus_four;
			DM_control_signals <= EX_control_signals;
			DM_branch_predicted_taken <= EX_branch_predicted_taken;
			DM_branch_target <= EX_branch_target;
			DM_predicted_next_instruction <= EX_predicted_next_instruction;
			DM_rs2 <= EX_rs2;
			DM_alu_result <= EX_alu_result;
			DM_alu_zero <= EX_alu_zero;
		end
	end: EX_DM_pipeline_register

	always_ff @(posedge clk) begin: DM_WB_pipeline_register
		if (!reset) begin
			WB_pc_plus_four <= 0;
			WB_control_signals <= 0;
			WB_alu_result <= 0;
			WB_memory_data_out <= 0;
		end else begin
			WB_pc_plus_four <= DM_pc_plus_four;
			WB_control_signals <= DM_control_signals;
			WB_alu_result <= DM_alu_result;
			WB_memory_data_out <= DM_memory_data_out;
		end
	end: DM_WB_pipeline_register

	// instruction memory
	read_only_async_memory #(.MEM_SIZE(4096), .MEM_FILE(PROGRAM)) instruction_memory (
		.clk(clk),
		.reset(reset),
		.address(IF_pc[$clog2(4096)-1:0]),
		.read_byte_en(4'b1111),	// always loading 32-bit instruction
		.data_out(IF_instruction));

	instruction_decode #(.XLEN(XLEN)) instruction_decode(
		.instruction(ID_instruction),
		.immediate(ID_immediate),
		.control_signals(ID_control_signals));
	
	stall_generator #(.XLEN(XLEN)) stall_generator(
		.ID_rs1_index(ID_control_signals.rs1_index),
		.ID_rs2_index(ID_control_signals.rs2_index),
		.RF_rd_index(RF_control_signals.rd_index),
		.RF_rd_select(RF_control_signals.rd_select),
		.RF_rf_write_en(RF_control_signals.rf_write_en),
		.stall(stall));

	rf_wb_select #(.XLEN(XLEN)) rf_wb_select(
		.alu_result(WB_alu_result),
		.memory_data_out(WB_memory_data_out),
		.pc_plus_four(WB_pc_plus_four),
		.select(WB_control_signals.rd_select),
		.rd(WB_rd));

	register_file #(.XLEN(XLEN)) rf(
		.clk(clk),
		.reset(reset),
		.rs1_index(RF_control_signals.rs1_index),
		.rs2_index(RF_control_signals.rs2_index),
		.rd_index(WB_control_signals.rd_index),
		.rd(WB_rd),
		.write_en(WB_control_signals.rf_write_en),
		.rs1(RF_register_file_rs1),
		.rs2(RF_register_file_rs2));
	
	data_forwarding_unit #(.XLEN(XLEN)) rs1_data_forwarding_unit(
		.EX_alu_result(EX_alu_result),
		.EX_rd_select(EX_control_signals.rd_select),
		.EX_rd_index(EX_control_signals.rd_index),
		.EX_rf_write_en(EX_control_signals.rf_write_en),
		.DM_alu_result(DM_alu_result),
		.DM_memory_data_out(DM_memory_data_out),
		.DM_rd_select(DM_control_signals.rd_select),
		.DM_rd_index(DM_control_signals.rd_index),
		.DM_rf_write_en(DM_control_signals.rf_write_en),
		.WB_rd(WB_rd),
		.WB_rd_index(WB_control_signals.rd_index),
		.WB_rf_write_en(WB_control_signals.rf_write_en),
		.register_file_rs(RF_register_file_rs1),
		.register_file_rs_index(RF_control_signals.rs1_index),
		.rs(RF_rs1));

	data_forwarding_unit #(.XLEN(XLEN)) rs2_data_forwarding_unit(
		.EX_alu_result(EX_alu_result),
		.EX_rd_select(EX_control_signals.rd_select),
		.EX_rd_index(EX_control_signals.rd_index),
		.EX_rf_write_en(EX_control_signals.rf_write_en),
		.DM_alu_result(DM_alu_result),
		.DM_memory_data_out(DM_memory_data_out),
		.DM_rd_select(DM_control_signals.rd_select),
		.DM_rd_index(DM_control_signals.rd_index),
		.DM_rf_write_en(DM_control_signals.rf_write_en),
		.WB_rd(WB_rd),
		.WB_rd_index(WB_control_signals.rd_index),
		.WB_rf_write_en(WB_control_signals.rf_write_en),
		.register_file_rs(RF_register_file_rs2),
		.register_file_rs_index(RF_control_signals.rs2_index),
		.rs(RF_rs2));

	assign IF_pc_plus_four = IF_pc + 4;

	alu_operand_select #(.XLEN(XLEN)) alu_operand_select(
		.rs1(EX_rs1),
		.rs2(EX_rs2),
		.immediate(EX_immediate),
		.pc(EX_pc),
		.alu_op1_src(EX_control_signals.alu_op1_src),
		.alu_op2_src(EX_control_signals.alu_op2_src),
		.alu_op1(EX_alu_op1),
		.alu_op2(EX_alu_op2));

	alu #(.XLEN(XLEN)) alu(
		.a(EX_alu_op1),
		.b(EX_alu_op2),
		.op(EX_control_signals.alu_operation),
		.sign(EX_control_signals.sign),
		.result(EX_alu_result),
		.zero(EX_alu_zero));

	// data memory
	read_write_async_memory #(.MEM_SIZE(4096)) data_memory(
		.clk(clk),
		.reset(reset),
		.address(DM_alu_result[$clog2(4096)-1:0]),
		.data_in(DM_rs2),

		// no byte-addressing for now
		.read_byte_en(4'b1111),
		.write_byte_en({4{DM_control_signals.mem_write_en}}),
		.data_out(DM_memory_data_out));

	branch_target #(.XLEN(XLEN)) branch_target_calculator (
		.pc(RF_pc),
		.rs1(RF_rs1),
		.immediate(RF_immediate),
		.jalr(RF_control_signals.jalr),

		.branch_target(RF_branch_target)
	);

	branch_predictor #(.XLEN(XLEN)) branch_predictor(
		// inputs
		.pc_plus_four(RF_pc_plus_four),
		.branch_target(RF_branch_target),
		.jump(RF_control_signals.jump),
		.branch(RF_control_signals.branch),
		// outputs
		.branch_predicted_taken(RF_branch_predicted_taken));

	assign RF_predicted_next_instruction = RF_branch_predicted_taken ? RF_branch_target : RF_pc_plus_four;

	branch_evaluator #(.XLEN(XLEN)) branch_evaluator(
		// inputs
		.pc_plus_four(DM_pc_plus_four),
		.predicted_next_instruction(DM_predicted_next_instruction),
		.evaluated_branch_target(DM_branch_target),
		.jump(DM_control_signals.jump),
		.branch(DM_control_signals.branch),
		.branch_if_zero(DM_control_signals.branch_if_zero),
		.zero(DM_alu_zero),
		.branch_prediction(DM_branch_predicted_taken),
		// outputs
		.next_instruction(DM_evaluated_next_instruction),
		.branch_mispredicted(DM_branch_mispredicted));

	pc_select #(.XLEN(XLEN)) pc_select(
		.pc_plus_four(IF_pc_plus_four),
		.evaluated_next_instruction(DM_evaluated_next_instruction),
		.predicted_next_instruction(RF_predicted_next_instruction),
		.evaluated_branch_mispredicted(DM_branch_mispredicted),
		.predicted_branch_predicted_taken(RF_branch_predicted_taken),
		.pc_next(pc_next));

	// just assign these signals to the output ports for verification
	assign instruction = IF_instruction;
	assign rf_write_en = WB_control_signals.rf_write_en;
	assign mem_write_en = WB_control_signals.mem_write_en;
endmodule
