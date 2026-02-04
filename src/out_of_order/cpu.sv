/*
 * TODO: figure out rs1 source for JALR target predictions
 * - when we pop off the RAS, we absolutely use that value
 * - when we aren't popping off the RAS, what do we use as a source?  I think
 *   there could be an argument for caching or forwarding LUI and AUIPC values
 *   from recent instructions (say the instruction just before the prediction)
 *   and using that when we see that rs1_index for the JALR is the same as the
 *   rd_index for the LUI or AUIPC.
 *   - I think this is a good cook
 *   - Talking with ChatGPT, it recommends "folding" the two instructions, not
 *   necessarily caching or forwarding.  Front end logic is specifically
 *   looking for an AUIPC/LUI followed by a JALR with a matching source
 *   register.  If the JALR rd overwrites the AUIPC/LUI rd, then the AUIPC/LUI
 *   does not need to be written to the ROB/RF, as the architectural state
 *   change is not visible.  This seems to be folding.
 *     - Supposedly "folding" is a term used for front-end optimization
 *     without computing the value in execution, and forwarding is using the
 *     computed value from execution before it writes back.  Since this is
 *     a front-end optimization, we call it folding.
 * - when neither of the above cases are viable, we use a branch target buffer
 *   or an indirect target predictor
 *   - this is a PC indexed data structure
 * - of note: ChatGPT mentions using the BTB/ITP for branches as well, as it
 *   saves us the one or more cycles it takes to decode the instruction where
 *   we identify it's a branch and construct the immediate value, add the
 *   immediate to PC, compute our branch prediction and update PC.  all these
 *   cycles are unavoidable stalls (unless we just load PC+4 in the meantime),
 *   but the BTB/ITP should provide greater accuracy
 *   - this is an optimization for WAY later tho, once the out-of-order design
 *   is proven to be working without it.
 *
 * TODO: consider flushing reservation station output buffers
 * this might not be a big deal if we keep the valid bits in the ROB, as long
 * as the ROB refuses to update when it sees the CDB active with a tag that is
 * no longer valid.  Even still, then it will still broadcast a value to the
 * CDB, which will be a wasted cycle.  Also worse, if the ROB does allocate
 * that entry again, and the old value is broadcast on the CDB, then the ROB
 * will update and consumers of the new instruction at that ROB entry will
 * consume the old misspeculated value.
 * I think that settles it, flush the output buffer.
 *
 * TODO: take validation one stage at a time
 * first validate instruction decode
 * then validate instruction decode => RF/Route
 * then validate decode => route => reservation station
 *
 * TODO: I think stalls should be implemented as disabling the "enable" inputs
 * of synchronous elements in the front-end.  This way, it guarantees nothing
 * is updated (including RAS, BTB, etc) when an instruction is stalled and
 * thus not yet committing its state change to the next stage in the pipeline.
 * I think I prefer this instead of effectively "re-routing" the stalled
 * instruction back into that synchronous element (i.e. the pc).
 * An important part of this todo is analyzing all the possible sources that
 * an instruction stall can from.  Is it JUST from the instruction routing?
 * Or can other things stall the front-end?
 */
module cpu #(
	parameter XLEN=32,
	parameter ROB_SIZE=32,
	parameter LDQ_SIZE=8,
	parameter STQ_SIZE=8,
	parameter RAS_SIZE=8,
	parameter N_ALU_RS=3,
	parameter N_AGU_RS=2,
	parameter N_BRANCH_RS=1) (
);

	localparam ROB_TAG_WIDTH = $clog2(ROB_SIZE);

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

	logic	clk;
	logic	reset;

	// Instruction Fetch stage
	logic [XLEN-1:0]	pc;
	logic [XLEN-1:0]	pc_next;

	// Instruction Decode - instruction decode
	logic [XLEN-1:0]	ID_pc;
	logic [XLEN-1:0]	ID_instruction;
	logic [XLEN-1:0]	ID_immediate;
	control_signal_bus	ID_control_signals;

	// Instruction Decode - RAS control signals
	logic			ras_push;
	logic			ras_pop;
	logic			ras_checkpoint;
	logic			ras_restore_checkpoint;

	// Instruction Decode - RAS
	logic [XLEN-1:0]	ras_address_out;
	logic			ras_empty;
	logic			ras_full;

	// Instruction Decode - branch prediction
	logic [XLEN-1:0]	ID_branch_target;
	logic			ID_branch_prediction;	// 1 if taken, 0 if not taken

	// RF/Route - instruction decode signals
	logic [XLEN-1:0]	IR_pc;
	logic [XLEN-1:0]	IR_immediate;
	control_signal_bus	IR_control_signals;
	// IR_stall: did we have to stall the instruction due to being unable to route it?
	logic			IR_stall;

	logic [XLEN-1:0]	IR_predicted_next_instruction;
	logic			IR_branch_prediction;

	// register file read outputs
	logic [XLEN-1:0]		RF_rs1;
	logic [ROB_TAG_WIDTH-1:0]	RF_rs1_rob_tag;
	logic				RF_rs1_rob_tag_valid;
	logic [XLEN-1:0]		RF_rs2;
	logic [ROB_TAG_WIDTH-1:0]	RF_rs2_rob_tag;
	logic				RF_rs2_rob_tag_valid;

	// routed operands
	logic				IR_q1_valid;
	logic [ROB_TAG_WIDTH-1:0]	IR_q1;
	logic [XLEN-1:0]		IR_v1;
	logic				IR_q2_valid;
	logic [ROB_TAG_WIDTH-1:0]	IR_q2;
	logic [XLEN-1:0]		IR_v2;

	logic	IR_alloc_rob_entry;
	logic	IR_alloc_ldq_entry;
	logic	IR_alloc_stq_entry;

	// reservation station inputs
	logic [TOTAL_RS-1:0]	RS_reset;
	logic [TOTAL_RS-1:0]	RS_route;
	logic [TOTAL_RS-1:0]	RS_dispatched;

	// reservation station outputs
	logic [TOTAL_RS-1:0][XLEN-1:0]		RS_v1;
	logic [TOTAL_RS-1:0][XLEN-1:0]		RS_v2;
	logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]	RS_rob_tag;
	logic [TOTAL_RS-1:0]			RS_busy;
	logic [TOTAL_RS-1:0]			RS_ready_to_execute;
	control_signal_bus [TOTAL_RS-1:0]	RS_control_signals;

	// branch-specific RS signals
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX][XLEN-1:0]	RS_pc;
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX][XLEN-1:0]	RS_immediate;
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX][XLEN-1:0]	RS_predicted_next_instruction;
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]		RS_branch_prediction;

	// functional unit outputs
	logic [TOTAL_RS-1:0][XLEN-1:0]				FU_result;
	logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]			FU_rob_tag;
	logic [TOTAL_RS-1:0]					FU_exception;
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]	FU_mispredicted;
	logic [TOTAL_RS-1:0]					FU_write_to_buffer;
	logic [TOTAL_RS-1:0]					FU_buf_not_empty;	// aka data_bus_request

	// common data bus
	logic				cdb_valid;
	wire [XLEN-1:0]			cdb_data;
	wire [ROB_TAG_WIDTH-1:0]	cdb_rob_tag;
	wire				cdb_exception;
	wire				cdb_mispredicted;

	// CDB arbitration
	logic [TOTAL_RS-1:0]		cdb_permit;

	// memory address bus + arbitration
	logic						address_bus_valid;
	wire [XLEN-1:0]					address_bus_data;
	wire [ROB_TAG_WIDTH-1:0]			address_bus_tag; 
	logic [AGU_RS_END_INDEX:AGU_RS_START_INDEX]	AGU_FU_buf_not_empty;
	logic [AGU_RS_END_INDEX:AGU_RS_START_INDEX]	address_bus_permit;

	// ROB inputs
	logic [XLEN-1:0]		rob_value_in;
	logic				rob_data_ready_in;
	logic [ROB_TAG_WIDTH-1:0]	rob_new_tail;

	// ROB
	logic [ROB_SIZE-1:0]		rob_valid;
	logic [ROB_SIZE-1:0][1:0]	rob_instruction_type;
	logic [ROB_SIZE-1:0]		rob_address_valid;
	logic [ROB_SIZE-1:0][XLEN-1:0]	rob_destination;
	logic [ROB_SIZE-1:0][XLEN-1:0]	rob_value;
	logic [ROB_SIZE-1:0]		rob_data_ready;
	logic [ROB_SIZE-1:0]		rob_branch_mispredict;
	logic [ROB_SIZE-1:0]		rob_exception;
	logic [ROB_SIZE-1:0][XLEN-1:0]	rob_next_instruction;

	// the instruction committing
	logic				rob_commit_valid;
	logic [1:0]			rob_commit_instruction_type;
	logic				rob_commit_address_valid;
	logic [XLEN-1:0]		rob_commit_destination;
	logic [XLEN-1:0]		rob_commit_value;
	logic				rob_commit_data_ready;
	logic				rob_commit_branch_mispredict;
	logic				rob_commit_exception;
	logic [XLEN-1:0]		rob_commit_next_instruction;

	logic [ROB_TAG_WIDTH-1:0]	rob_head;
	logic [ROB_TAG_WIDTH-1:0]	rob_tail;
	logic				rob_commit;
	logic				rob_full;

	// exception handling
	logic				exception;
	logic [XLEN-1:0]		exception_next_instruction;
	logic [ROB_SIZE-1:0]		rob_flush;

	// LDQ
	logic ldq_full;

	// STQ
	logic stq_full;

	// MEMORY
	logic			MEM_kill_mem_req;
	logic			MEM_fire_memory_op;
	logic			MEM_memory_op_type;
	logic [XLEN-1:0]	MEM_memory_address;
	logic [XLEN-1:0]	MEM_memory_data;

	always_ff @(posedge clk) begin: pc_reg
		if (!reset)
			pc <= 0;
		else if (!IR_stall)
			pc <= pc_next;
	end

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
		.exception(exception),

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

		.exception(exception),

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

		.address_in(),
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

	instruction_route #(.XLEN(XLEN), .N_ALU_RS(N_ALU_RS), .N_AGU_RS(N_AGU_RS), .N_BRANCH_RS(N_BRANCH_RS)) instruction_route (
		.valid(),	// TODO gotta figure this one out still
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
		.flush(exception),
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
		.opcode(IR_control_signals.opcode),
		.rs1(RF_rs1),
		.rs1_rob_tag(RF_rs1_rob_tag),
		.rs1_rob_tag_valid(RF_rs1_rob_tag_valid),
		.rs2(RF_rs2),
		.rs2_rob_tag(RF_rs2_rob_tag),
		.rs2_rob_tag_valid(RF_rs2_rob_tag_valid),
		.pc(IR_pc),
		.immediate(IR_immediate),
		.rob_value(rob_value),
		.rob_data_ready(rob_data_ready),
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
		.rs2_rob_tag_valid(RF_rs2_rob_tag_valid),
		.rs2(RF_rs2),
		.pc(IR_pc),
		.instruction_length(IR_control_signals.instruction_length),
		.immediate(IR_immediate),
		.value(rob_value_in),
		.rob_data_ready_in(rob_data_ready_in)
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
		.request(FU_buf_not_empty[AGU_RS_END_INDEX:AGU_RS_START_INDEX]),
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
			reservation_station #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) alu_rs (
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
				.q1_valid_out(),
				.q1_out(),
				.v1_out(RS_v1[alu_genvar]),
				.q2_valid_out(),
				.q2_out(),
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
				.ready_to_execute(RS_ready_to_execute[alu_genvar])
			);

			reservation_station_reset #(.TAG_WIDTH($clog2(ROB_SIZE))) rs_reset (
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

			functional_unit_output_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH($clog2(ROB_SIZE))) alu_output_buf (
				.clk(clk),
				.reset(reset),
				.value(FU_result[alu_genvar]),
				.tag(FU_rob_tag[alu_genvar]),
				.exception(),
				.redirect_mispredicted(1'b0),
				.write_en(FU_write_to_buffer[alu_genvar]),
				.data_bus_permit(cdb_permit[alu_genvar]),
				.data_bus_data(cdb_data),
				.data_bus_tag(cdb_rob_tag),
				// no need to connect this output buffer to
				// the exception or misprediction lines of the
				// CDB if it can't generate either signal
				.data_bus_exception(),
				.data_bus_redirect_mispredicted(),
				.not_empty(FU_buf_not_empty[alu_genvar]),
				.full()
			);
		end
	endgenerate

	// Generate the AGU execution pipeline N_AGU_RS times, which will
	// broadcast results to the Load/Store Unit and ROB via the address
	// bus
	genvar agu_genvar;
	generate
		for (agu_genvar = AGU_RS_START_INDEX; agu_genvar <= AGU_RS_END_INDEX; agu_genvar = agu_genvar + 1) begin
			reservation_station #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) agu_rs (
				.clk(clk),
				.reset(RS_reset[agu_genvar]),
				.enable(RS_route[agu_genvar]),
				.dispatched_in(RS_dispatched[agu_genvar]),
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
				.cdb_valid(address_bus_valid),
				.cdb_rob_tag(address_bus_tag),
				.cdb_data(address_bus_data),
				.q1_valid_out(),
				.q1_out(),
				.v1_out(RS_v1[agu_genvar]),
				.q2_valid_out(),
				.q2_out(),
				.v2_out(RS_v2[agu_genvar]),
				.control_signals_out(RS_control_signals[agu_genvar]),
				.rob_tag_out(RS_rob_tag[agu_genvar]),
				// leave all branch specific fields
				// unconnected to anything so they're
				// optimized out during synthesis
				.pc_out(),
				.immediate_out(),
				.predicted_next_instruction_out(),
				.branch_prediction_out(),

				.busy(RS_busy[agu_genvar]),
				.ready_to_execute(RS_ready_to_execute[agu_genvar])
			);

			reservation_station_reset #(.TAG_WIDTH($clog2(ROB_SIZE))) rs_reset (
				.global_reset(reset),
				.bus_valid(address_bus_valid),
				.bus_rob_tag(address_bus_tag),
				.rs_rob_tag(RS_rob_tag[agu_genvar]),
				.reservation_station_reset(RS_reset[agu_genvar])	// this goes into the RS ^
			);

			memory_address_functional_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) memory_address_functional_unit (
				.base(RS_v1[agu_genvar]),
				.offset(RS_v2[agu_genvar]),
				.rob_tag_in(RS_rob_tag[agu_genvar]),
				.result(FU_result[agu_genvar]),
				.rob_tag_out(FU_rob_tag[agu_genvar]),
				.ready_to_execute(RS_ready_to_execute[agu_genvar]),
				.accept(RS_dispatched[agu_genvar]),
				.write_to_buffer(FU_write_to_buffer[agu_genvar])
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH($clog2(ROB_SIZE))) agu_output_buf (
				.clk(clk),
				.reset(reset),
				.value(FU_result[agu_genvar]),
				.tag(FU_rob_tag[agu_genvar]),
				// AGUs can't cause an exception or misprediction
				.exception(1'b0),
				.redirect_mispredicted(1'b0),
				.write_en(FU_write_to_buffer[agu_genvar]),
				.data_bus_permit(address_bus_permit[agu_genvar]),
				.data_bus_data(address_bus_data),
				.data_bus_tag(address_bus_tag),
				// the address bus doesn't have exception or
				// misprediction signals
				.data_bus_exception(),
				.data_bus_redirect_mispredicted(),
				.not_empty(AGU_FU_buf_not_empty[agu_genvar]),
				.full()
			);
		end
	endgenerate
	
	// Generate the branch execution pipeline N_BRANCH_RS times
	genvar branch_genvar;
	generate
		for (branch_genvar = BRANCH_RS_START_INDEX; branch_genvar <= BRANCH_RS_END_INDEX; branch_genvar = branch_genvar + 1) begin
			reservation_station #(.XLEN(XLEN), .TAG_WIDTH($clog2(ROB_SIZE))) branch_rs (
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
				.q1_valid_out(),
				.q1_out(),
				.v1_out(RS_v1[branch_genvar]),
				.q2_valid_out(),
				.q2_out(),
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
				.ready_to_execute(RS_ready_to_execute[branch_genvar])
			);

			reservation_station_reset #(.TAG_WIDTH($clog2(ROB_SIZE))) rs_reset (
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
				.redirect_mispredicted(FU_mispredicted[branch_genvar]),
				.rob_tag_out(FU_rob_tag[branch_genvar]),

				.ready_to_execute(RS_ready_to_execute[branch_genvar]),
				.accept(RS_dispatched[branch_genvar]),
				.write_to_buffer(FU_write_to_buffer[branch_genvar])
			);

			functional_unit_output_buffer #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH($clog2(ROB_SIZE))) branch_output_buf (
				.clk(clk),
				.reset(reset),
				.value(FU_result[branch_genvar]),
				.tag(FU_rob_tag[branch_genvar]),
				.exception(FU_exception[branch_genvar]),
				.redirect_mispredicted(FU_mispredicted[branch_genvar]),
				.write_en(FU_write_to_buffer[branch_genvar]),
				.data_bus_permit(cdb_permit[branch_genvar]),
				.data_bus_data(cdb_data),
				.data_bus_tag(cdb_rob_tag),
				.data_bus_exception(cdb_exception),
				.data_bus_redirect_mispredicted(cdb_mispredicted),
				.not_empty(FU_buf_not_empty[branch_genvar]),
				.full()
			);
		end
	endgenerate

	reorder_buffer #(.XLEN(XLEN), .BUF_SIZE(ROB_SIZE), .TAG_WIDTH($clog2(ROB_SIZE))) reorder_buffer (
		.clk(clk),
		.reset(reset),
		.input_en(IR_alloc_rob_entry),
		.instruction_type_in(IR_control_signals.instruction_type),
		// just store rd_index at allocation.  the only instructions
		// that don't write to RD are stores, which update the
		// destination when an address appears on the address bus
		.destination_in({27'b0, IR_control_signals.rd_index}),
		.value_in(rob_value_in),
		.data_ready_in(rob_data_ready_in),
		.pc_in(IR_pc),
		.cdb_valid(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_exception(cdb_exception),
		.branch_mispredict(cdb_mispredicted),
		.agu_address_valid(address_bus_valid),
		.agu_address_data(address_bus_data),
		.agu_address_rob_tag(address_bus_tag),
		.flush(rob_flush),
		.new_tail(rob_new_tail),
		.rob_valid(rob_valid),
		.rob_instruction_type(rob_instruction_type),
		.rob_address_valid(rob_address_valid),
		.rob_destination(rob_destination),
		.rob_value(rob_value),
		.rob_data_ready(rob_data_ready),
		.rob_branch_mispredict(rob_branch_mispredict),
		.rob_exception(rob_exception),
		.rob_next_instruction(rob_next_instruction),
		.rob_commit_valid(rob_commit_valid),
		.rob_commit_instruction_type(rob_commit_instruction_type),
		.rob_commit_address_valid(rob_commit_address_valid),
		.rob_commit_destination(rob_commit_destination),
		.rob_commit_value(rob_commit_value),
		.rob_commit_data_ready(rob_commit_data_ready),
		.rob_commit_branch_mispredict(rob_commit_branch_mispredict),
		.rob_commit_exception(rob_commit_exception),
		.rob_commit_next_instruction(rob_commit_next_instruction),
		.head(rob_head),
		.tail(rob_tail),
		.commit(rob_commit),
		.full(rob_full)
	);

	buffer_flusher #(.XLEN(XLEN), .BUF_SIZE(ROB_SIZE), .TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) buffer_flusher (
		.rob_branch_mispredict(rob_branch_mispredict),
		.rob_exception(rob_exception),
		.rob_head(rob_head),
		.rob_tail(rob_tail),
		.rob_next_instruction(rob_next_instruction),

		.ldq_valid(),
		.ldq_rob_tag(),
		.stq_valid(),
		.stq_rob_tag(),

		.flush(exception),

		.exception_next_instruction(exception_next_instruction),

		.rob_flush(rob_flush),
		.rob_new_tail(rob_new_tail),

		.flush_ldq(),
		.ldq_new_tail(),
		.flush_stq(),
		.stq_new_tail()
	);

	load_store_unit #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH), .LDQ_SIZE(LDQ_SIZE), .STQ_SIZE(STQ_SIZE)) lsu (
		.clk(clk),
		.reset(reset),
		.alloc_ldq_entry(IR_alloc_ldq_entry),
		.alloc_stq_entry(IR_alloc_stq_entry),
		.rob_tag_in(rob_tail),

		// TODO: I'm being lazy with these (it's a little late),
		// verify this is fine: i.e. only does something when
		// alloc_stq_entry is set
		.store_data(rob_value_in),
		.store_data_valid(rob_data_ready_in),
		.agu_address_valid(address_bus_valid),
		.agu_address_data(address_bus_data),
		.agu_address_rob_tag(address_bus_tag),
		.rob_commit(rob_commit),
		.rob_commit_tag(rob_head),

		// these signals come from cache/memory
		.load_succeeded(),
		.load_succeeded_rob_tag(),
		.store_succeeded(),
		.store_succeeded_rob_tag(),

		.cdb_active(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_tag(cdb_rob_tag),

		.kill_mem_req(MEM_kill_mem_req),
		.fire_memory_op(MEM_fire_memory_op),
		.memory_op_type(MEM_memory_op_type),
		.memory_address(MEM_memory_address),
		.memory_data(MEM_memory_data)
	);
endmodule
