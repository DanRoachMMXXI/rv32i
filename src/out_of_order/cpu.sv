/*
 * TODO: figure out rs1 source for JALR target predictions
 * - when we pop off the RAS, we absolutely use that value
 * - when we identify JALR folding, we probably more absolutely use that value
 * - when neither of the above cases are viable, we use a branch target buffer or an indirect target
 *   predictor
 *   - this is a PC indexed data structure
 * - of note: ChatGPT mentions using the BTB/ITP for branches as well, as it saves us the one or
	 *   more cycles it takes to decode the instruction where we identify it's a branch and
	 *   construct the immediate value, add the immediate to PC, compute our branch prediction
	 *   and update PC.  all these cycles are unavoidable stalls (unless we just load PC+4 in
	 *   the meantime), but the BTB/ITP should provide greater accuracy
 *   - this is an optimization for WAY later tho, once the out-of-order design is proven to be
 *   working without it.
 *
 * TODO: I think stalls should be implemented as disabling the "enable" inputs of synchronous
 * elements in the front-end.  This way, it guarantees nothing is updated (including RAS, BTB, etc)
 * when an instruction is stalled and thus not yet committing its state change to the next stage in
 * the pipeline. I think I prefer this instead of effectively "re-routing" the stalled instruction
 * back into that synchronous element (i.e. the pc). An important part of this todo is analyzing all
 * the possible sources that an instruction stall can from.  Is it JUST from the instruction routing?
 * Or can other things stall the front-end?
 *
 * TODO: set up the LSU to broadcast forwarded loads to the CDB
 *
 * TODO: set up coverpoints throughout the design
 */
module cpu #(
	parameter XLEN=32,
	parameter ROB_SIZE=32,
	parameter LDQ_SIZE=8,
	parameter STQ_SIZE=8,
	parameter RAS_SIZE=8,
	parameter N_ALU_RS=3,
	parameter N_AGU_RS=2,
	parameter N_BRANCH_RS=1,
	parameter PROGRAM="") (
	input logic	clk,
	input logic	reset,

	input logic			LSU_load_succeeded,
	input logic [ROB_TAG_WIDTH-1:0]	LSU_load_succeeded_rob_tag,
	input logic			LSU_store_succeeded,
	input logic [ROB_TAG_WIDTH-1:0]	LSU_store_succeeded_rob_tag,

	// Instruction Fetch stage
	output logic [XLEN-1:0]	pc,
	output logic [XLEN-1:0]	pc_next,
	output logic [XLEN-1:0]	IF_instruction,

	// Instruction Decode - instruction decode
	output logic [XLEN-1:0]	ID_pc,
	output logic [XLEN-1:0]	ID_pc_next,	// pc+2 if compressed, pc+4 if uncompressed
	output logic [XLEN-1:0]	ID_instruction,
	output logic [XLEN-1:0]	ID_immediate,
	control_signal_bus	ID_control_signals,

	// Instruction Decode - RAS control signals
	output logic			ras_push,
	output logic			ras_pop,
	output logic			ras_checkpoint,
	output logic			ras_restore_checkpoint,

	// Instruction Decode - RAS
	output logic [XLEN-1:0]	ras_address_out,
	output logic			ras_empty,
	output logic			ras_full,

	// Instruction Decode - branch prediction
	output logic [XLEN-1:0]	ID_branch_target,
	output logic			ID_branch_prediction,	// 1 if taken, 0 if not taken

	// RF/Route - instruction decode signals
	output logic [XLEN-1:0]	IR_pc,
	output logic [XLEN-1:0]	IR_immediate,
	control_signal_bus	IR_control_signals,
	// IR_stall: did we have to stall the instruction due to being unable to route it?
	output logic		IR_stall,

	output logic		IR_branch_prediction,
	output logic [XLEN-1:0]	IR_predicted_next_instruction,

	// register file read outputs
	output logic [XLEN-1:0]			RF_rs1,
	output logic [ROB_TAG_WIDTH-1:0]	RF_rs1_rob_tag,
	output logic				RF_rs1_rob_tag_valid,
	output logic [XLEN-1:0]			RF_rs2,
	output logic [ROB_TAG_WIDTH-1:0]	RF_rs2_rob_tag,
	output logic				RF_rs2_rob_tag_valid,

	output logic				RF_write_en,

	// routed operands
	output logic				IR_q1_valid,
	output logic [ROB_TAG_WIDTH-1:0]	IR_q1,
	output logic [XLEN-1:0]			IR_v1,
	output logic				IR_q2_valid,
	output logic [ROB_TAG_WIDTH-1:0]	IR_q2,
	output logic [XLEN-1:0]			IR_v2,

	output logic	IR_alloc_rob_entry,
	output logic	IR_alloc_ldq_entry,
	output logic	IR_alloc_stq_entry,

	// reservation station inputs
	output logic [TOTAL_RS-1:0]	RS_reset,
	output logic [TOTAL_RS-1:0]	RS_route,
	output logic [TOTAL_RS-1:0]	RS_dispatched,

	// reservation station outputs
	output logic [TOTAL_RS-1:0][XLEN-1:0]		RS_v1,
	output logic [TOTAL_RS-1:0][XLEN-1:0]		RS_v2,
	output logic [TOTAL_RS-1:0][XLEN-1:0]		RS_immediate,
	output logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]	RS_rob_tag,
	output logic [TOTAL_RS-1:0]			RS_busy,
	output logic [TOTAL_RS-1:0]			RS_ready_to_execute,
	control_signal_bus [TOTAL_RS-1:0]		RS_control_signals,

	// branch-specific RS signals
	output logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX][XLEN-1:0]	RS_pc,
	output logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX][XLEN-1:0]	RS_predicted_next_instruction,
	output logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]		RS_branch_prediction,

	// functional unit outputs
	output logic [TOTAL_RS-1:0][XLEN-1:0]				FU_result,
	output logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]			FU_rob_tag,
	output logic [TOTAL_RS-1:0]					FU_uarch_exception,
	output logic [TOTAL_RS-1:0]					FU_arch_exception,
	output logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]	FU_redirect_mispredicted,
	output logic [TOTAL_RS-1:0]					FU_write_to_buffer,
	output logic [TOTAL_RS-1:0]					FU_buf_not_empty,	// aka data_bus_request

	// common data bus
	output logic				cdb_valid,
	output wire [XLEN-1:0]			cdb_data,
	output wire [ROB_TAG_WIDTH-1:0]		cdb_rob_tag,
	output wire				cdb_uarch_exception,
	output wire				cdb_arch_exception,
	output wire				cdb_mispredicted,

	// CDB arbitration
	output logic [TOTAL_RS-1:0]		cdb_permit,

	// memory address bus + arbitration
	output logic						address_bus_valid,
	wire [XLEN-1:0]						address_bus_data,
	wire [ROB_TAG_WIDTH-1:0]				address_bus_tag, 
	output logic [AGU_RS_END_INDEX:AGU_RS_START_INDEX]	AGU_FU_buf_not_empty,
	output logic [AGU_RS_END_INDEX:AGU_RS_START_INDEX]	address_bus_permit,

	// ROB inputs
	output logic [XLEN-1:0]			rob_value_in,
	output logic				rob_ready_in,

	// ROB
	output logic [ROB_SIZE-1:0]		rob_valid,
	output logic [ROB_SIZE-1:0][1:0]	rob_instruction_type,
	output logic [ROB_SIZE-1:0][4:0]	rob_destination,
	output logic [ROB_SIZE-1:0][XLEN-1:0]	rob_value,
	output logic [ROB_SIZE-1:0]		rob_ready,
	output logic [ROB_SIZE-1:0]		rob_branch_mispredict,
	output logic [ROB_SIZE-1:0]		rob_uarch_exception,
	output logic [ROB_SIZE-1:0]		rob_arch_exception,
	output logic [ROB_SIZE-1:0][XLEN-1:0]	rob_next_instruction,
	output logic [ROB_SIZE-1:0][LDQ_TAG_WIDTH-1:0] rob_ldq_tail,
	output logic [ROB_SIZE-1:0][STQ_TAG_WIDTH-1:0] rob_stq_tail,

	// the instruction committing
	output logic				rob_commit_valid,
	output logic [1:0]			rob_commit_instruction_type,
	output logic [4:0]			rob_commit_destination,
	output logic [XLEN-1:0]			rob_commit_value,
	output logic				rob_commit_ready,
	output logic				rob_commit_branch_mispredict,
	output logic				rob_commit_uarch_exception,
	output logic				rob_commit_arch_exception,
	output logic [XLEN-1:0]			rob_commit_next_instruction,
	output logic [LDQ_TAG_WIDTH-1:0]	rob_commit_ldq_tail,
	output logic [STQ_TAG_WIDTH-1:0]	rob_commit_stq_tail,

	output logic [ROB_TAG_WIDTH-1:0]	rob_head,
	output logic [ROB_TAG_WIDTH-1:0]	rob_tail,
	output logic				rob_empty,
	output logic				rob_full,
	output logic				rob_commit,

	// exception handling / flushing
	output logic				flush,
	output logic [XLEN-1:0]			exception_next_instruction,
	output logic [ROB_TAG_WIDTH-1:0]	flush_start_tag,
	output logic [LDQ_TAG_WIDTH-1:0]	ldq_new_tail,
	output logic [STQ_TAG_WIDTH-1:0]	stq_new_tail,

	// LDQ
	output logic				ldq_full,
	output logic [LDQ_TAG_WIDTH-1:0]	ldq_tail,

	// STQ
	output logic				stq_full,
	output logic [STQ_TAG_WIDTH-1:0]	stq_tail,

	// MEMORY
	output logic		MEM_kill_mem_req,
	output logic		MEM_fire_memory_op,
	output logic		MEM_memory_op_type,
	output logic [XLEN-1:0]	MEM_memory_address,
	output logic [XLEN-1:0]	MEM_memory_data,

	// debug signals
	output logic [TOTAL_RS-1:0]			RS_q1_valid,
	output logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]	RS_q1,
	output logic [TOTAL_RS-1:0]			RS_q2_valid,
	output logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]	RS_q2,
	output logic [TOTAL_RS-1:0][3:0]		FU_buf_valid
);

	localparam ROB_TAG_WIDTH = $clog2(ROB_SIZE) + 2;
	localparam LDQ_TAG_WIDTH = $clog2(LDQ_SIZE) + 2;
	localparam STQ_TAG_WIDTH = $clog2(STQ_SIZE) + 2;

	// I needed some convention to follow here for the indices of the
	// reservation station busses (busy, route, etc) and how they map to
	// the reservation stations.
	// note that the LSB gets priority to broadcast to the CDB and thus
	// gets priority in clearing the RS
	// also remember that the AGU doesn't depend on the CDB, it has its
	// own bus
	// I've decided to give branch/jalr executions priority so we can
	// recover from misspeculations sooner
	localparam TOTAL_RS = N_ALU_RS + N_AGU_RS + N_BRANCH_RS;
	localparam BRANCH_RS_START_INDEX = 0;
	localparam BRANCH_RS_END_INDEX = N_BRANCH_RS-1;

	localparam ALU_RS_START_INDEX = N_BRANCH_RS;
	localparam ALU_RS_END_INDEX = ALU_RS_START_INDEX + N_ALU_RS - 1;

	localparam AGU_RS_START_INDEX = ALU_RS_START_INDEX + N_ALU_RS;
	localparam AGU_RS_END_INDEX = AGU_RS_START_INDEX + N_AGU_RS - 1;

	always_ff @(posedge clk) begin: pc_reg
		if (!reset)
			pc <= 0;
		else if (!IR_stall)
			pc <= pc_next;
	end

	always_ff @(posedge clk) begin: IF_ID_pipeline_reg
		if (!reset || flush) begin
			ID_pc <= 0;
			ID_instruction <= 0;
		end else if (!IR_stall) begin
			ID_pc <= pc;
			ID_instruction <= IF_instruction;
		end
	end

	assign ID_pc_next = ID_pc + (ID_control_signals.instruction_length ? XLEN'(4) : XLEN'(2));

	always_ff @(posedge clk) begin: ID_IR_pipeline_reg
		if (!reset || flush) begin
			IR_pc <= 0;
			IR_immediate <= 0;
			IR_control_signals <= 0;
			IR_branch_prediction <= 0;
			IR_predicted_next_instruction <= 0;
		end else if (!IR_stall) begin
			IR_pc <= ID_pc;
			IR_immediate <= ID_immediate;
			IR_control_signals <= ID_control_signals;
			IR_branch_prediction <= ID_branch_prediction;
			IR_predicted_next_instruction <= ID_branch_prediction
				? ID_branch_target
				: ID_pc_next;
		end
	end

	read_only_async_memory #(.MEM_SIZE(128), .MEM_FILE(PROGRAM)) instruction_memory (
		.clk(clk),
		.reset(reset),
		.address(pc[$clog2(128)-1:0]),
		.read_byte_en(4'b1111),	// always loading 32-bit instruction
		.data_out(IF_instruction)
	);

	pc_mux #(.XLEN(XLEN)) pc_mux (
		.pc(pc),
		.predicted_next_instruction(ID_branch_target),
		.exception_next_instruction(exception_next_instruction),

		// TODO: figure out how instruction_fetch knows the
		// instruction length before it reaches decode stage
		// if we just use the signal in decode stage, we miss every
		// other cycle waiting for the instruction to decode to know
		// the length of the instruction.
		// For now, since I'm not supporting compressed instructions,
		// I'll hardwire this to 1 (aka instruction length of 4 bytes)
		.instruction_length(1'b1),

		.prediction(ID_branch_prediction),
		.exception(flush),

		.pc_next(pc_next)
	);

	instruction_decode #(.XLEN(XLEN)) instruction_decode (
		.instruction(ID_instruction),
		.immediate(ID_immediate),
		.control_signals(ID_control_signals)
	);

	// branch prediction
	ras_control ras_control (
		.branch(ID_control_signals.branch),
		.jump(ID_control_signals.jump),
		.jalr(ID_control_signals.jalr),
		.jalr_fold(1'b0),	// TODO: change this when folding is implemented

		.flush(flush),

		.rs1_index(ID_control_signals.rs1_index),
		.rd_index(ID_control_signals.rd_index),

		.push(ras_push),
		.pop(ras_pop),
		.checkpoint(ras_checkpoint),
		.restore_checkpoint(ras_restore_checkpoint)
	);

	return_address_stack #(.XLEN(XLEN), .STACK_SIZE(RAS_SIZE)) ras (
		.clk(clk),
		.reset(reset),

		.address_in(ID_pc_next),
		.push(ras_push),
		.pop(ras_pop),

		.checkpoint(ras_checkpoint),
		.restore_checkpoint(ras_restore_checkpoint),

		.address_out(ras_address_out),
		.empty(ras_empty),
		.full(ras_full),

		// debug/unit test signals, leave disconnected here
		.stack(),
		.stack_pointer(),
		.sp_checkpoint(),
		.n_entries(),
		.n_entries_cp()
	);

	branch_target #(.XLEN(XLEN)) branch_target_calculator (
		.pc(ID_pc),
		.rs1(ras_address_out),	// TODO: update this when BTB is implemented
		.immediate(ID_immediate),
		.jalr(ID_control_signals.jalr),
		.branch_target(ID_branch_target)
	);

	branch_predictor #(.XLEN(XLEN)) branch_predictor (
		.pc(ID_pc),
		.branch_target(ID_branch_target),
		.jump(ID_control_signals.jump),
		.branch(ID_control_signals.branch),
		.branch_predicted_taken(ID_branch_prediction)
	);

	// perhaps it might be more elegant to have stores write to register 0,
	// but for now, decode just sets rd_index to instruction[11:7] blindly,
	// and that gets blindly put into the destination field for the ROB.
	assign RF_write_en = rob_commit && rob_commit_instruction_type != 'b11;

	register_file #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) register_file (
		.clk(clk),
		.reset(reset),

		.rs1_index(IR_control_signals.rs1_index),
		.rs2_index(IR_control_signals.rs2_index),

		// don't update ROB tags for store instructions
		// TODO: make this more elegant (no expressions in port connections)
		.update_rob_tag_en(IR_alloc_rob_entry && !(IR_control_signals.instruction_type == 2'b11)),
		.update_rob_tag_index(IR_control_signals.rd_index),
		.rob_tail(rob_tail),

		.flush(flush),
		.flush_start_tag(flush_start_tag),

		.rd_index(rob_commit_destination),
		.rd(rob_commit_value),
		.rd_rob_index(rob_head),
		.write_en(RF_write_en),

		.rs1(RF_rs1),
		.rs1_rob_tag(RF_rs1_rob_tag),
		.rs1_rob_tag_valid(RF_rs1_rob_tag_valid),
		.rs2(RF_rs2),
		.rs2_rob_tag(RF_rs2_rob_tag),
		.rs2_rob_tag_valid(RF_rs2_rob_tag_valid)
	);

	instruction_route #(.XLEN(XLEN), .N_ALU_RS(N_ALU_RS), .N_AGU_RS(N_AGU_RS), .N_BRANCH_RS(N_BRANCH_RS)) instruction_route (
		.valid(IR_control_signals.valid && !ID_control_signals.fold),
		.instruction_type(IR_control_signals.instruction_type),
		.ctl_branch(IR_control_signals.branch),
		.ctl_jalr(IR_control_signals.jalr),
		.ctl_u_type(IR_control_signals.u_type),
		.ctl_alloc_rob_entry(IR_control_signals.alloc_rob_entry),
		.ctl_alloc_ldq_entry(IR_control_signals.alloc_ldq_entry),
		.ctl_alloc_stq_entry(IR_control_signals.alloc_stq_entry),
		.rob_full(rob_full),
		.ldq_full(ldq_full),
		.stq_full(stq_full),
		.flush(flush),
		.alu_rs_busy(RS_busy[ALU_RS_END_INDEX:ALU_RS_START_INDEX]),
		.agu_rs_busy(RS_busy[AGU_RS_END_INDEX:AGU_RS_START_INDEX]),
		.branch_rs_busy(RS_busy[BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]),

		.alloc_rob_entry(IR_alloc_rob_entry),
		.alloc_ldq_entry(IR_alloc_ldq_entry),
		.alloc_stq_entry(IR_alloc_stq_entry),

		.alu_rs_route(RS_route[ALU_RS_END_INDEX:ALU_RS_START_INDEX]),
		.agu_rs_route(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX]),
		.branch_rs_route(RS_route[BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]),

		.stall(IR_stall)
	);

	operand_route #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) operand_route (
		.control_signals(IR_control_signals),
		.rs1(RF_rs1),
		.rs1_rob_tag(RF_rs1_rob_tag),
		.rs1_rob_tag_valid(RF_rs1_rob_tag_valid),
		.rs2(RF_rs2),
		.rs2_rob_tag(RF_rs2_rob_tag),
		.rs2_rob_tag_valid(RF_rs2_rob_tag_valid),
		.pc(IR_pc),
		.immediate(IR_immediate),
		.rob_value(rob_value),
		.rob_ready(rob_ready),
		.cdb_valid(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_rob_tag(cdb_rob_tag),
		.q1_valid(IR_q1_valid),
		.q1(IR_q1),
		.v1(IR_v1),
		.q2_valid(IR_q2_valid),
		.q2(IR_q2),
		.v2(IR_v2)
	);
	
	rob_data_in_route #(.XLEN(XLEN)) rob_data_in_route (
		.instruction_type(IR_control_signals.instruction_type),
		.branch(IR_control_signals.branch),
		.jalr(IR_control_signals.jalr),
		.lui(IR_control_signals.lui),
		.auipc(IR_control_signals.auipc),
		.pc(IR_pc),
		.instruction_length(IR_control_signals.instruction_length),
		.immediate(IR_immediate),
		.value(rob_value_in),
		.rob_ready_in(rob_ready_in)
	);

	// only the branch and alu FUs output to the CDB, but we should be
	// able to instantiate this using TOTAL_RS and have the AGU bits
	// optimized away
	// TODO: validate that assumption ^
	// TODO: I wonder if driving the CDB from the arbiter worsens
	// propagation delay for the CDB, cause it would be
	// time_to_request_CDB + time_for_valid_to_propagate
	// I wonder if each requester can just drive cdb_valid to 1 when it
	// has data, knowing that it if it gets access, it's valid, and if
	// something else gets access over it, it's also valid.  There's never
	// a case where an FU output buffer has a value and the CDB is not
	// valid.
	// update on ^: while it's true that it worsens the delay for
	// cdb_valid, the arbiter still has to receive input from the
	// non-empty buffers and permit one to broadcast to the CDB, so the
	// propagation delay is unavoidable in that context.  So this is
	// a fine optimization to make to remove a very small amount of
	// hardware, but it's likely not impacting performance.
	cdb_arbiter #(.N(TOTAL_RS)) cdb_arbiter (
		.request(FU_buf_not_empty),
		.grant(cdb_permit),
		.cdb_valid(cdb_valid)
	);

	cdb_arbiter #(.N(N_AGU_RS)) address_data_bus_arbiter (
		.request(AGU_FU_buf_not_empty[AGU_RS_END_INDEX:AGU_RS_START_INDEX]),
		.grant(address_bus_permit),
		.cdb_valid(address_bus_valid)
	);

	// Generate the ALU execution pipeline N_ALU_RS times
	genvar alu_genvar;
	generate
		for (alu_genvar = ALU_RS_START_INDEX; alu_genvar <= ALU_RS_END_INDEX; alu_genvar = alu_genvar + 1) begin
			// remember to use reservation_station_reset to
			// connect to the reset pin of the reservation_station
			// module
			reservation_station #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) alu_rs (
				.clk(clk),
				.reset(RS_reset[alu_genvar]),
				.enable(RS_route[alu_genvar]),
				.dispatched_in(RS_dispatched[alu_genvar]),
				.q1_valid_in(IR_q1_valid),
				.q1_in(IR_q1),
				.v1_in(IR_v1),
				.q2_valid_in(IR_q2_valid),
				.q2_in(IR_q2),
				.v2_in(IR_v2),
				.control_signals_in(IR_control_signals),
				.rob_tag_in(rob_tail),
				// leave all branch specific fields to 0
				.pc_in(XLEN'(0)),
				.immediate_in(XLEN'(0)),
				.predicted_next_instruction_in(XLEN'(0)),
				.branch_prediction_in(1'b0),
				.cdb_valid(cdb_valid),
				.cdb_rob_tag(cdb_rob_tag),
				.cdb_data(cdb_data),
				.v1_out(RS_v1[alu_genvar]),
				.v2_out(RS_v2[alu_genvar]),
				.control_signals_out(RS_control_signals[alu_genvar]),
				.rob_tag_out(RS_rob_tag[alu_genvar]),
				// leave all branch specific fields
				// unconnected to anything so they're
				// optimized out during synthesis
				.pc_out(),
				.immediate_out(),
				.predicted_next_instruction_out(),
				.branch_prediction_out(),

				.busy(RS_busy[alu_genvar]),
				.ready_to_execute(RS_ready_to_execute[alu_genvar]),
				.q1_valid(RS_q1_valid[alu_genvar]),
				.q1(RS_q1[alu_genvar]),
				.q2_valid(RS_q2_valid[alu_genvar]),
				.q2(RS_q2[alu_genvar])
			);

			reservation_station_reset #(.ROB_TAG_WIDTH(ROB_TAG_WIDTH)) rs_reset (
				.global_reset(reset),
				.bus_valid(cdb_valid),
				.bus_rob_tag(cdb_rob_tag),
				.rs_rob_tag(RS_rob_tag[alu_genvar]),
				.reservation_station_reset(RS_reset[alu_genvar])	// this goes into the RS ^
			);

			alu_functional_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) alu_functional_unit (
				.a(RS_v1[alu_genvar]),
				.b(RS_v2[alu_genvar]),
				.rob_tag_in(RS_rob_tag[alu_genvar]),
				.funct3(RS_control_signals[alu_genvar].funct3),
				.sign(RS_control_signals[alu_genvar].sign),
				.result(FU_result[alu_genvar]),
				.rob_tag_out(FU_rob_tag[alu_genvar]),
				.ready_to_execute(RS_ready_to_execute[alu_genvar]),
				.accept(RS_dispatched[alu_genvar]),
				.write_to_buffer(FU_write_to_buffer[alu_genvar])
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) alu_output_buf (
				.clk(clk),
				.reset(reset),
				.value_in(FU_result[alu_genvar]),
				.tag_in(FU_rob_tag[alu_genvar]),
				.uarch_exception_in(1'b0),
				.arch_exception_in(1'b0),
				.redirect_mispredicted_in(1'b0),
				.write_en(FU_write_to_buffer[alu_genvar]),
				.flush(flush),
				.flush_start_tag(flush_start_tag),
				.data_bus_permit(cdb_permit[alu_genvar]),
				.data_bus_data(cdb_data),
				.data_bus_tag(cdb_rob_tag),
				// still connecting these exception and
				// mispredicted signals to ensure they are
				// driven to 0 if the FU can not generate
				// these signals, otherwise they are Z
				.data_bus_uarch_exception(cdb_uarch_exception),
				.data_bus_arch_exception(cdb_arch_exception),
				.data_bus_redirect_mispredicted(cdb_mispredicted),
				.not_empty(FU_buf_not_empty[alu_genvar]),
				.full(),
				.valid(FU_buf_valid[alu_genvar])
			);
		end
	endgenerate

	// Generate the AGU execution pipeline N_AGU_RS times, which will
	// broadcast results to the Load/Store Unit and ROB via the address
	// bus
	genvar agu_genvar;
	generate
		for (agu_genvar = AGU_RS_START_INDEX; agu_genvar <= AGU_RS_END_INDEX; agu_genvar = agu_genvar + 1) begin
			reservation_station #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) agu_rs (
				.clk(clk),
				.reset(RS_reset[agu_genvar]),
				.enable(RS_route[agu_genvar]),
				.dispatched_in(RS_dispatched[agu_genvar]),
				.q1_valid_in(IR_q1_valid),
				.q1_in(IR_q1),
				.v1_in(IR_v1),
				.q2_valid_in(1'b0),
				.q2_in(ROB_TAG_WIDTH'(0)),
				.v2_in(XLEN'(0)),
				.control_signals_in(IR_control_signals),
				.rob_tag_in(rob_tail),
				// leave all branch specific fields to 0
				.pc_in(XLEN'(0)),
				.immediate_in(IR_immediate),
				.predicted_next_instruction_in(XLEN'(0)),
				.branch_prediction_in(1'b0),
				.cdb_valid(cdb_valid),
				.cdb_rob_tag(cdb_rob_tag),
				.cdb_data(cdb_data),
				.v1_out(RS_v1[agu_genvar]),
				.v2_out(),
				.control_signals_out(RS_control_signals[agu_genvar]),
				.rob_tag_out(RS_rob_tag[agu_genvar]),
				// leave branch specific fields unconnected to anything so they're
				// optimized out during synthesis
				.pc_out(),
				.immediate_out(RS_immediate[agu_genvar]),
				.predicted_next_instruction_out(),
				.branch_prediction_out(),

				.busy(RS_busy[agu_genvar]),
				.ready_to_execute(RS_ready_to_execute[agu_genvar]),
				.q1_valid(RS_q1_valid[agu_genvar]),
				.q1(RS_q1[agu_genvar]),
				.q2_valid(RS_q2_valid[agu_genvar]),
				.q2(RS_q2[agu_genvar])
			);

			reservation_station_reset #(.ROB_TAG_WIDTH(ROB_TAG_WIDTH)) rs_reset (
				.global_reset(reset),
				.bus_valid(address_bus_valid),
				.bus_rob_tag(address_bus_tag),
				.rs_rob_tag(RS_rob_tag[agu_genvar]),
				.reservation_station_reset(RS_reset[agu_genvar])	// this goes into the RS ^
			);

			memory_address_functional_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) memory_address_functional_unit (
				.base(RS_v1[agu_genvar]),
				.offset(RS_immediate[agu_genvar]),
				.rob_tag_in(RS_rob_tag[agu_genvar]),
				.result(FU_result[agu_genvar]),
				.rob_tag_out(FU_rob_tag[agu_genvar]),
				.ready_to_execute(RS_ready_to_execute[agu_genvar]),
				.accept(RS_dispatched[agu_genvar]),
				.write_to_buffer(FU_write_to_buffer[agu_genvar])
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) agu_output_buf (
				.clk(clk),
				.reset(reset),
				.value_in(FU_result[agu_genvar]),
				.tag_in(FU_rob_tag[agu_genvar]),
				// AGUs can't cause an exception or misprediction
				.uarch_exception_in(1'b0),
				.arch_exception_in(1'b0),
				.redirect_mispredicted_in(1'b0),
				.write_en(FU_write_to_buffer[agu_genvar]),
				.flush(flush),
				.flush_start_tag(flush_start_tag),
				.data_bus_permit(address_bus_permit[agu_genvar]),
				.data_bus_data(address_bus_data),
				.data_bus_tag(address_bus_tag),
				// this FU is not connected to the CDB, so we
				// don't wire these CDB-specific signals
				.data_bus_uarch_exception(),
				.data_bus_arch_exception(),
				.data_bus_redirect_mispredicted(),
				.not_empty(AGU_FU_buf_not_empty[agu_genvar]),
				.full(),
				.valid(FU_buf_valid[agu_genvar])
			);
		end
	endgenerate
	
	// Generate the branch execution pipeline N_BRANCH_RS times
	genvar branch_genvar;
	generate
		for (branch_genvar = BRANCH_RS_START_INDEX; branch_genvar <= BRANCH_RS_END_INDEX; branch_genvar = branch_genvar + 1) begin
			reservation_station #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) branch_rs (
				.clk(clk),
				.reset(RS_reset[branch_genvar]),
				.enable(RS_route[branch_genvar]),
				.dispatched_in(RS_dispatched[branch_genvar]),
				.q1_valid_in(IR_q1_valid),
				.q1_in(IR_q1),
				.v1_in(IR_v1),
				.q2_valid_in(IR_q2_valid),
				.q2_in(IR_q2),
				.v2_in(IR_v2),
				.control_signals_in(IR_control_signals),
				.rob_tag_in(rob_tail),
				// leave all branch specific fields to 0
				.pc_in(IR_pc),
				.immediate_in(IR_immediate),
				.predicted_next_instruction_in(IR_predicted_next_instruction),
				.branch_prediction_in(IR_branch_prediction),
				.cdb_valid(cdb_valid),
				.cdb_rob_tag(cdb_rob_tag),
				.cdb_data(cdb_data),
				.v1_out(RS_v1[branch_genvar]),
				.v2_out(RS_v2[branch_genvar]),
				.control_signals_out(RS_control_signals[branch_genvar]),
				.rob_tag_out(RS_rob_tag[branch_genvar]),
				// leave all branch specific fields
				// unconnected to anything so they're
				// optimized out during synthesis
				.pc_out(RS_pc[branch_genvar]),
				.immediate_out(RS_immediate[branch_genvar]),
				.predicted_next_instruction_out(RS_predicted_next_instruction[branch_genvar]),
				.branch_prediction_out(RS_branch_prediction[branch_genvar]),

				.busy(RS_busy[branch_genvar]),
				.ready_to_execute(RS_ready_to_execute[branch_genvar]),
				.q1_valid(RS_q1_valid[branch_genvar]),
				.q1(RS_q1[branch_genvar]),
				.q2_valid(RS_q2_valid[branch_genvar]),
				.q2(RS_q2[branch_genvar])
			);

			reservation_station_reset #(.ROB_TAG_WIDTH(ROB_TAG_WIDTH)) rs_reset (
				.global_reset(reset),
				.bus_valid(cdb_valid),
				.bus_rob_tag(cdb_rob_tag),
				.rs_rob_tag(RS_rob_tag[branch_genvar]),
				.reservation_station_reset(RS_reset[branch_genvar])	// this goes into the RS ^
			);

			branch_functional_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) branch_functional_unit (
				.v1(RS_v1[branch_genvar]),
				.v2(RS_v2[branch_genvar]),
				.pc(RS_pc[branch_genvar]),
				.immediate(RS_immediate[branch_genvar]),
				.predicted_next_instruction(RS_predicted_next_instruction[branch_genvar]),
				.rob_tag_in(RS_rob_tag[branch_genvar]),
				.funct3(RS_control_signals[branch_genvar].funct3),
				.instruction_length(RS_control_signals[branch_genvar].instruction_length),
				.jalr(RS_control_signals[branch_genvar].jalr),
				.branch(RS_control_signals[branch_genvar].branch),
				.next_instruction(FU_result[branch_genvar]),
				.redirect_mispredicted(FU_redirect_mispredicted[branch_genvar]),
				.rob_tag_out(FU_rob_tag[branch_genvar]),

				.ready_to_execute(RS_ready_to_execute[branch_genvar]),
				.accept(RS_dispatched[branch_genvar]),
				.write_to_buffer(FU_write_to_buffer[branch_genvar])
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) branch_output_buf (
				.clk(clk),
				.reset(reset),
				.value_in(FU_result[branch_genvar]),
				.tag_in(FU_rob_tag[branch_genvar]),
				.uarch_exception_in(FU_uarch_exception[branch_genvar]),
				.arch_exception_in(FU_arch_exception[branch_genvar]),
				.redirect_mispredicted_in(FU_redirect_mispredicted[branch_genvar]),
				.write_en(FU_write_to_buffer[branch_genvar]),
				.flush(flush),
				.flush_start_tag(flush_start_tag),
				.data_bus_permit(cdb_permit[branch_genvar]),
				.data_bus_data(cdb_data),
				.data_bus_tag(cdb_rob_tag),
				.data_bus_uarch_exception(cdb_uarch_exception),
				.data_bus_arch_exception(cdb_arch_exception),
				.data_bus_redirect_mispredicted(cdb_mispredicted),
				.not_empty(FU_buf_not_empty[branch_genvar]),
				.full(),
				.valid(FU_buf_valid[branch_genvar])
			);
		end
	endgenerate

	reorder_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_TAG_WIDTH(LDQ_TAG_WIDTH), .STQ_TAG_WIDTH(STQ_TAG_WIDTH)) reorder_buffer (
		.clk(clk),
		.reset(reset),
		.input_en(IR_alloc_rob_entry),
		.instruction_type_in(IR_control_signals.instruction_type),
		.destination_in(IR_control_signals.rd_index),
		.value_in(rob_value_in),
		.ready_in(rob_ready_in),
		.pc_in(IR_pc),
		.ldq_tail_in(ldq_tail),
		.stq_tail_in(stq_tail),
		.cdb_valid(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_uarch_exception(cdb_uarch_exception),
		.cdb_arch_exception(cdb_arch_exception),
		.branch_mispredict(cdb_mispredicted),
		.agu_address_valid(address_bus_valid),
		.agu_address_data(address_bus_data),
		.agu_address_rob_tag(address_bus_tag),
		.flush(flush),
		.flush_start_tag(flush_start_tag),
		.rob_valid(rob_valid),
		.rob_instruction_type(rob_instruction_type),
		.rob_destination(rob_destination),
		.rob_value(rob_value),
		.rob_ready(rob_ready),
		.rob_branch_mispredict(rob_branch_mispredict),
		.rob_uarch_exception(rob_uarch_exception),
		.rob_arch_exception(rob_arch_exception),
		.rob_next_instruction(rob_next_instruction),
		.rob_ldq_tail(rob_ldq_tail),
		.rob_stq_tail(rob_stq_tail),
		.rob_commit_valid(rob_commit_valid),
		.rob_commit_instruction_type(rob_commit_instruction_type),
		.rob_commit_destination(rob_commit_destination),
		.rob_commit_value(rob_commit_value),
		.rob_commit_ready(rob_commit_ready),
		.rob_commit_branch_mispredict(rob_commit_branch_mispredict),
		.rob_commit_uarch_exception(rob_commit_uarch_exception),
		.rob_commit_arch_exception(rob_commit_arch_exception),
		.rob_commit_next_instruction(rob_commit_next_instruction),
		.rob_commit_ldq_tail(rob_commit_ldq_tail),
		.rob_commit_stq_tail(rob_commit_stq_tail),
		.head(rob_head),
		.tail(rob_tail),
		.empty(rob_empty),
		.full(rob_full),
		.commit(rob_commit)
	);

	buffer_flusher #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .LDQ_TAG_WIDTH(LDQ_TAG_WIDTH), .STQ_SIZE(STQ_SIZE), .STQ_TAG_WIDTH(STQ_TAG_WIDTH)) buffer_flusher (
		.rob_branch_mispredict(rob_branch_mispredict),
		.rob_uarch_exception(rob_uarch_exception),
		.rob_head(rob_head),
		.rob_next_instruction(rob_next_instruction),
		.rob_ldq_tail(rob_ldq_tail),
		.rob_stq_tail(rob_stq_tail),

		.flush(flush),
		.exception_next_instruction(exception_next_instruction),
		.flush_start_tag(flush_start_tag),
		.ldq_new_tail(ldq_new_tail),
		.stq_new_tail(stq_new_tail)
	);

	load_store_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .LDQ_TAG_WIDTH(LDQ_TAG_WIDTH), .STQ_SIZE(STQ_SIZE), .STQ_TAG_WIDTH(STQ_TAG_WIDTH)) lsu (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(IR_alloc_ldq_entry),
		.alloc_stq_entry(IR_alloc_stq_entry),
		.rob_tag_in(rob_tail),

		.store_data(IR_v2),
		.store_data_valid(!IR_q2_valid),
		.data_producer_rob_tag_in(IR_q2),
		.agu_address_valid(address_bus_valid),
		.agu_address_data(address_bus_data),
		.agu_address_rob_tag(address_bus_tag),
		.rob_commit(rob_commit),
		.rob_commit_tag(rob_head),

		.flush(flush),
		.flush_rob_tag(flush_start_tag),
		.ldq_new_tail(ldq_new_tail),
		.stq_new_tail(stq_new_tail),

		// these signals come from cache/memory
		.load_succeeded(LSU_load_succeeded),
		.load_succeeded_rob_tag(LSU_load_succeeded_rob_tag),
		.store_succeeded(LSU_store_succeeded),
		.store_succeeded_rob_tag(LSU_store_succeeded_rob_tag),

		.cdb_active(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_tag(cdb_rob_tag),

		.ldq_tail(ldq_tail),
		.stq_tail(stq_tail),

		.kill_mem_req(MEM_kill_mem_req),
		.fire_memory_op(MEM_fire_memory_op),
		.memory_op_type(MEM_memory_op_type),
		.memory_address(MEM_memory_address),
		.memory_data(MEM_memory_data)
	);
endmodule
