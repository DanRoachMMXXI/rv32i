// simple-sum.s
// 00000000 <init>:
//    0:	00001137          	lui	sp,0x1
// 
// 00000004 <main>:
//    4:	fe010113          	addi	sp,sp,-32 # fe0 <main+0xfdc>
//    8:	00112e23          	sw	ra,28(sp)
//    c:	00812c23          	sw	s0,24(sp)
//   10:	02010413          	addi	s0,sp,32
//   14:	00400793          	li	a5,4
//   18:	fef42623          	sw	a5,-20(s0)
//   1c:	00500793          	li	a5,5
//   20:	fef42423          	sw	a5,-24(s0)
//   24:	fec42703          	lw	a4,-20(s0)
//   28:	fe842783          	lw	a5,-24(s0)
//   2c:	00f707b3          	add	a5,a4,a5
//   30:	fef42223          	sw	a5,-28(s0)
//   34:	fe442783          	lw	a5,-28(s0)
//   38:	00078513          	mv	a0,a5
//   3c:	01c12083          	lw	ra,28(sp)
//   40:	01812403          	lw	s0,24(sp)
//   44:	02010113          	addi	sp,sp,32
//   48:	00008067          	ret
module test_ooo_cpu;
	localparam XLEN=32;
	localparam ROB_SIZE=32;
	localparam LDQ_SIZE=8;
	localparam STQ_SIZE=8;
	localparam RAS_SIZE=8;
	localparam N_ALU_RS=3;
	localparam N_AGU_RS=2;
	localparam N_BRANCH_RS=1;

	localparam ROB_TAG_WIDTH = $clog2(ROB_SIZE) + 2;
	localparam LDQ_TAG_WIDTH = $clog2(LDQ_SIZE) + 2;
	localparam STQ_TAG_WIDTH = $clog2(STQ_SIZE) + 2;
	localparam TOTAL_RS = N_ALU_RS + N_AGU_RS + N_BRANCH_RS;
	localparam BRANCH_RS_START_INDEX = 0;
	localparam BRANCH_RS_END_INDEX = N_BRANCH_RS-1;
	localparam ALU_RS_START_INDEX = N_BRANCH_RS;
	localparam ALU_RS_END_INDEX = ALU_RS_START_INDEX + N_ALU_RS - 1;
	localparam AGU_RS_START_INDEX = ALU_RS_START_INDEX + N_ALU_RS;
	localparam AGU_RS_END_INDEX = AGU_RS_START_INDEX + N_AGU_RS - 1;

	logic	clk = 0;
	logic	reset = 0;

	// Instruction Fetch stage
	logic [XLEN-1:0]	pc;
	logic [XLEN-1:0]	pc_next;
	logic [XLEN-1:0]	IF_instruction;

	// Instruction Decode - instruction decode
	logic [XLEN-1:0]	ID_pc;
	logic [XLEN-1:0]	ID_pc_next;	// pc+2 if compressed, pc+4 if uncompressed
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

	logic			IR_branch_prediction;
	logic [XLEN-1:0]	IR_predicted_next_instruction;

	// register file read outputs
	logic [XLEN-1:0]		RF_rs1;
	logic [ROB_TAG_WIDTH-1:0]	RF_rs1_rob_tag;
	logic				RF_rs1_rob_tag_valid;
	logic [XLEN-1:0]		RF_rs2;
	logic [ROB_TAG_WIDTH-1:0]	RF_rs2_rob_tag;
	logic				RF_rs2_rob_tag_valid;

	logic				RF_write_en;

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
	logic [TOTAL_RS-1:0][XLEN-1:0]		RS_immediate;
	logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]	RS_rob_tag;
	logic [TOTAL_RS-1:0]			RS_busy;
	logic [TOTAL_RS-1:0]			RS_ready_to_execute;
	control_signal_bus [TOTAL_RS-1:0]	RS_control_signals;

	// branch-specific RS signals
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX][XLEN-1:0]	RS_pc;
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX][XLEN-1:0]	RS_predicted_next_instruction;
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]		RS_branch_prediction;

	// functional unit outputs
	logic [TOTAL_RS-1:0][XLEN-1:0]				FU_result;
	logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]			FU_rob_tag;
	logic [TOTAL_RS-1:0]					FU_uarch_exception;
	logic [TOTAL_RS-1:0]					FU_arch_exception;
	logic [BRANCH_RS_END_INDEX:BRANCH_RS_START_INDEX]	FU_redirect_mispredicted;
	logic [TOTAL_RS-1:0]					FU_write_to_buffer;
	logic [TOTAL_RS-1:0]					FU_buf_not_empty;	// aka data_bus_request

	// common data bus
	logic				cdb_valid;
	wire [XLEN-1:0]			cdb_data;
	wire [ROB_TAG_WIDTH-1:0]	cdb_rob_tag;
	wire				cdb_uarch_exception;
	wire				cdb_arch_exception;
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
	logic				rob_ready_in;

	// ROB
	logic [ROB_SIZE-1:0]		rob_valid;
	logic [ROB_SIZE-1:0][1:0]	rob_instruction_type;
	logic [ROB_SIZE-1:0][4:0]	rob_destination;
	logic [ROB_SIZE-1:0][XLEN-1:0]	rob_value;
	logic [ROB_SIZE-1:0]		rob_ready;
	logic [ROB_SIZE-1:0]		rob_branch_mispredict;
	logic [ROB_SIZE-1:0]		rob_uarch_exception;
	logic [ROB_SIZE-1:0]		rob_arch_exception;
	logic [ROB_SIZE-1:0][XLEN-1:0]	rob_next_instruction;
	logic [ROB_SIZE-1:0][LDQ_TAG_WIDTH-1:0] rob_ldq_tail;
	logic [ROB_SIZE-1:0][STQ_TAG_WIDTH-1:0] rob_stq_tail;

	// the instruction committing
	logic				rob_commit_valid;
	logic [1:0]			rob_commit_instruction_type;
	logic [4:0]			rob_commit_destination;
	logic [XLEN-1:0]		rob_commit_value;
	logic				rob_commit_ready;
	logic				rob_commit_branch_mispredict;
	logic				rob_commit_uarch_exception;
	logic				rob_commit_arch_exception;
	logic [XLEN-1:0]		rob_commit_next_instruction;
	logic [LDQ_TAG_WIDTH-1:0]	rob_commit_ldq_tail;
	logic [STQ_TAG_WIDTH-1:0]	rob_commit_stq_tail;

	logic [ROB_TAG_WIDTH-1:0]	rob_head;
	logic [ROB_TAG_WIDTH-1:0]	rob_tail;
	logic				rob_empty;
	logic				rob_full;
	logic				rob_commit;

	// exception handling / flushing
	logic				flush;
	logic [XLEN-1:0]		exception_next_instruction;
	logic [ROB_TAG_WIDTH-1:0]	flush_start_tag;
	logic [LDQ_TAG_WIDTH-1:0]	ldq_new_tail;
	logic [STQ_TAG_WIDTH-1:0]	stq_new_tail;

	logic				LSU_load_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	LSU_load_succeeded_rob_tag;
	logic				LSU_store_succeeded;
	logic [ROB_TAG_WIDTH-1:0]	LSU_store_succeeded_rob_tag;

	// LDQ
	logic ldq_full;
	logic [LDQ_TAG_WIDTH-1:0]	ldq_tail;

	// STQ
	logic stq_full;
	logic [STQ_TAG_WIDTH-1:0]	stq_tail;

	// MEMORY
	logic			MEM_kill_mem_req;
	logic			MEM_fire_memory_op;
	logic			MEM_memory_op_type;
	logic [XLEN-1:0]	MEM_memory_address;
	logic [XLEN-1:0]	MEM_memory_data;

	// debug signals
	logic [TOTAL_RS-1:0]			RS_q1_valid;
	logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]	RS_q1;
	logic [TOTAL_RS-1:0]			RS_q2_valid;
	logic [TOTAL_RS-1:0][ROB_TAG_WIDTH-1:0]	RS_q2;
	logic [TOTAL_RS-1:0][3:0]		FU_buf_valid;

	cpu #(
		.XLEN(XLEN),
		.ROB_SIZE(ROB_SIZE),
		.LDQ_SIZE(LDQ_SIZE),
		.STQ_SIZE(STQ_SIZE),
		.RAS_SIZE(RAS_SIZE),
		.N_ALU_RS(N_ALU_RS),
		.N_AGU_RS(N_AGU_RS),
		.N_BRANCH_RS(N_BRANCH_RS),
		.PROGRAM("test/programs/simple-sum/simple-sum.vh")
	) cpu (
		.clk(clk),
		.reset(reset),
		.LSU_load_succeeded(LSU_load_succeeded),
		.LSU_load_succeeded_rob_tag(LSU_load_succeeded_rob_tag),
		.LSU_store_succeeded(LSU_store_succeeded),
		.LSU_store_succeeded_rob_tag(LSU_store_succeeded_rob_tag),
		.pc(pc),
		.pc_next(pc_next),
		.IF_instruction(IF_instruction),
		.ID_pc(ID_pc),
		.ID_pc_next(ID_pc_next),
		.ID_instruction(ID_instruction),
		.ID_immediate(ID_immediate),
		.ID_control_signals(ID_control_signals),
		.ras_push(ras_push),
		.ras_pop(ras_pop),
		.ras_checkpoint(ras_checkpoint),
		.ras_restore_checkpoint(ras_restore_checkpoint),
		.ras_address_out(ras_address_out),
		.ras_empty(ras_empty),
		.ras_full(ras_full),
		.ID_branch_target(ID_branch_target),
		.ID_branch_prediction(ID_branch_prediction),
		.IR_pc(IR_pc),
		.IR_immediate(IR_immediate),
		.IR_control_signals(IR_control_signals),
		.IR_stall(IR_stall),
		.IR_branch_prediction(IR_branch_prediction),
		.IR_predicted_next_instruction(IR_predicted_next_instruction),
		.RF_rs1(RF_rs1),
		.RF_rs1_rob_tag(RF_rs1_rob_tag),
		.RF_rs1_rob_tag_valid(RF_rs1_rob_tag_valid),
		.RF_rs2(RF_rs2),
		.RF_rs2_rob_tag(RF_rs2_rob_tag),
		.RF_rs2_rob_tag_valid(RF_rs2_rob_tag_valid),
		.RF_write_en(RF_write_en),
		.IR_q1_valid(IR_q1_valid),
		.IR_q1(IR_q1),
		.IR_v1(IR_v1),
		.IR_q2_valid(IR_q2_valid),
		.IR_q2(IR_q2),
		.IR_v2(IR_v2),
		.IR_alloc_rob_entry(IR_alloc_rob_entry),
		.IR_alloc_ldq_entry(IR_alloc_ldq_entry),
		.IR_alloc_stq_entry(IR_alloc_stq_entry),
		.RS_reset(RS_reset),
		.RS_route(RS_route),
		.RS_dispatched(RS_dispatched),
		.RS_v1(RS_v1),
		.RS_v2(RS_v2),
		.RS_rob_tag(RS_rob_tag),
		.RS_busy(RS_busy),
		.RS_ready_to_execute(RS_ready_to_execute),
		.RS_control_signals(RS_control_signals),
		.RS_pc(RS_pc),
		.RS_immediate(RS_immediate),
		.RS_predicted_next_instruction(RS_predicted_next_instruction),
		.RS_branch_prediction(RS_branch_prediction),
		.FU_result(FU_result),
		.FU_rob_tag(FU_rob_tag),
		.FU_uarch_exception(FU_uarch_exception),
		.FU_arch_exception(FU_arch_exception),
		.FU_redirect_mispredicted(FU_redirect_mispredicted),
		.FU_write_to_buffer(FU_write_to_buffer),
		.FU_buf_not_empty(FU_buf_not_empty),
		.cdb_valid(cdb_valid),
		.cdb_data(cdb_data),
		.cdb_rob_tag(cdb_rob_tag),
		.cdb_uarch_exception(cdb_uarch_exception),
		.cdb_arch_exception(cdb_arch_exception),
		.cdb_mispredicted(cdb_mispredicted),
		.cdb_permit(cdb_permit),
		.address_bus_valid(address_bus_valid),
		.address_bus_data(address_bus_data),
		.address_bus_tag(address_bus_tag),
		.AGU_FU_buf_not_empty(AGU_FU_buf_not_empty),
		.address_bus_permit(address_bus_permit),
		.rob_value_in(rob_value_in),
		.rob_ready_in(rob_ready_in),
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
		.rob_head(rob_head),
		.rob_tail(rob_tail),
		.rob_empty(rob_empty),
		.rob_full(rob_full),
		.rob_commit(rob_commit),
		.flush(flush),
		.exception_next_instruction(exception_next_instruction),
		.flush_start_tag(flush_start_tag),
		.ldq_new_tail(ldq_new_tail),
		.stq_new_tail(stq_new_tail),
		.ldq_full(ldq_full),
		.ldq_tail(ldq_tail),
		.stq_full(stq_full),
		.stq_tail(stq_tail),
		.MEM_kill_mem_req(MEM_kill_mem_req),
		.MEM_fire_memory_op(MEM_fire_memory_op),
		.MEM_memory_op_type(MEM_memory_op_type),
		.MEM_memory_address(MEM_memory_address),
		.MEM_memory_data(MEM_memory_data),
		.RS_q1_valid(RS_q1_valid),
		.RS_q1(RS_q1),
		.RS_q2_valid(RS_q2_valid),
		.RS_q2(RS_q2),
		.FU_buf_valid(FU_buf_valid)
	);

	// test signals/variables
	// RS_route_snapshot is a dynamic array indexed by the address of the instruction.
	// When the instruction gets routed to a RS, we can snapshot RS_route to know exactly which
	// reservation station it got routed to, enabling us to check the status of that instruction
	// in its reservation station.
	logic [TOTAL_RS-1:0]	RS_route_snapshot [];

	always begin
		#5 clk = ~clk;
	end

	// test logic
	initial begin
		RS_route_snapshot = new ['h50];	// allocate enough entries to just index with the PC of the instruction
		# 10	// wait for reset
		reset = 1;
	
		// PC = 0x0
		// loading the first instruction
		assert(IF_instruction == 'h00001137);
		# 10
		// PC = 0x4 
		// 0x0 is being decoded
		// 0x4 is being fetched
		assert(IF_instruction == 'hfe010113);
		# 10
		// PC = 0x8
		// the first instruction is being routed.  It is a lui, so it
		// should not be routed to any execution units, and the value
		// should be written straight to the ROB.
		// 0x4 (addi) is being decoded
		// 0x8 is being fetched

		// assertions for 0x0 route
		RS_route_snapshot[IR_pc] = RS_route;
		assert(RS_route == 0);	// ensure the instruction is not routed to any RS
		assert(IR_alloc_rob_entry == 1);
		assert(rob_ready_in == 1);
		assert(rob_value_in == 'h1000);
		assert(IF_instruction == 'h00112e23);
		# 10
		// PC = 0xC
		// 0x0 (lui) should be in the ROB and ready to commit
		// 0x4 (addi) is being routed, and should be routed to an ALU
		// unit
		// 0x8 (sw) is being decoded
		// 0xC (sw) is being fetched

		// assertions for 0x0 commit
		assert(rob_commit == 1);
		assert(rob_commit_destination == 2);	// ensure it's written to the stack pointer
		assert(rob_commit_value == 'h1000);
		assert(RF_write_en == 1);

		// assertions for 0x4 route
		RS_route_snapshot[IR_pc] = RS_route;
		assert(RS_route[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);	// ensure it's routed to ANY ALU rs, idc which one
		assert(IR_alloc_rob_entry == 1);
		assert(rob_tail == 1);

		assert(IF_instruction == 'h00812c23);
		# 10
		// PC = 0x10
		// 0x4 (addi) has been placed in an ALU RS and should be
		// executed this cycle, to be stored in the output buffer the
		// next cycle
		// 0x8 (sw) should be routed to the AGU and the LSU.  The
		// register operand for the AGU should not be ready, as it's
		// referencing the new stack pointer which is being computed
		// by the ALU RS.
		// 0xC (sw) is being decoded
		// 0x10 (addi) is being fetched

		// assertions for 0x4 execution
		assert((RS_busy & RS_route_snapshot['h4]) != 0);	// ensure that the ALU RS is busy
		assert((RS_ready_to_execute & RS_route_snapshot['h4]) != 0);	// ensure that the ALU RS states its operation is ready to execute
		assert((RS_dispatched & RS_route_snapshot['h4]) != 0);	// ensure that the ALU FU has accepted the operation

		// assertions for 0x8 route
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IR_alloc_rob_entry == 1);
		assert(IR_alloc_stq_entry == 1);
		assert(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);	// ensure that the sw is routed to an AGU RS
		assert(IR_q1_valid == 1);
		assert(IR_q1 == 1);	// ROB index for 0x4 instruction
		assert(IR_q2_valid == 0);
		assert(rob_tail == 2);

		assert(IF_instruction == 'h02010413);
		# 10
		// PC = 0x14
		// 0x4 (addi) has been placed in the output buffer and should
		// be broadcast to the CDB as it's the first value to be
		// placed in a CDB output buffer
		// 0x8 (sw) has been placed in the AGU and should pick up the
		// result of 0x4 from the CDB, making it ready to execute next
		// cycle
		// 0xC (sw) is being routed to the second AGU (if it exists)
		// 0x10 (addi) is being decoded
		// 0x14 (li => addi) is being fetched

		// assertions to ensure nothing is committing this cycle
		assert(rob_commit == 0);
		assert(rob_head == 1);

		// assertions for 0x4 CDB broadcast
		assert(cdb_valid == 1);
		assert(cdb_rob_tag == 1);
		assert(cdb_data == 'hfe0);

		// assertions for 0x8 reading the CDB
		assert(RS_ready_to_execute[AGU_RS_END_INDEX:AGU_RS_START_INDEX] == 0);

		// assertions for 0xC routing to the AGU
		if (N_AGU_RS > 1) begin
			RS_route_snapshot[IR_pc] = RS_route;
			assert(IR_alloc_rob_entry == 1);
			assert(IR_alloc_stq_entry == 1);
			assert(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
			assert(IR_q1_valid == 0);	// this value is being forwarded as it's actively being broadcast on the CDB
			assert(IR_v1 == 'hfe0);		// verify the value on the CDB is forwarded
		end else if (N_AGU_RS == 1) begin
			assert(IR_stall == 1);
			# 10
			// the occupying instruction is now executing and will
			// write to the output buffer next clock cycle
			# 10
			// the occupying instruction has written to the output
			// buffer and should have permission to broadcast
			// (there's only one entry).  the RS should see this
			// value get broadcast and clear itself.
			assert(address_bus_valid == 1);
			assert(address_bus_tag == 2);
			assert(RS_reset == 0);	// active low
			# 10
			RS_route_snapshot[IR_pc] = RS_route;
			assert(RS_busy[AGU_RS_END_INDEX:AGU_RS_START_INDEX] == 0);	// verify it's been cleared
			assert(IR_stall == 0);
			assert(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);	// verify the new instruction is routed
		end else begin
			$fatal("NON-POSITIVE NUMBER OF AGU RESERVATION STATIONS");
		end
		assert(rob_tail == 3);

		assert(IF_instruction == 'h00400793);
		# 10
		// PC = 0x18
		// 0x4 (addi) has its value in the CDB and is ready to commit
		// 0x8 (sw) is executing in its AGU if N_AGU_RS > 1 
		// 0xC (sw) is executing in its AGU
		// 0x10 (addi) is being routed to an ALU FU, and the register
		// operand is ready
		// 0x14 (li => addi) is being decoded
		// 0x18 (sw) is being fetched

		// assertions for 0x4 commit
		assert(rob_commit == 1);
		assert(rob_head == 1);
		assert(rob_commit_ready == 1);
		assert(rob_commit_value == 'hfe0);
		assert(rob_commit_destination == 2);	// sp

		// assertions for 0x8 execution
		if (N_AGU_RS > 1) begin
			assert(RS_ready_to_execute[AGU_RS_START_INDEX] == 1);
			assert(RS_dispatched[AGU_RS_START_INDEX] == 1);
			assert(FU_write_to_buffer[AGU_RS_START_INDEX] == 1);
		end

		// assertions for 0xC execution
		// this just verifies that ANYTHING is executing
		// TODO: in future, could take a snapshot of RS_route for
		// these instructions and use it as a mask for the other
		// signals like these.  that allows us to track which RS each
		// instruction is in
		assert(RS_ready_to_execute[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
		assert(RS_dispatched[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
		assert(FU_write_to_buffer[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);

		// assertions for 0x10 routing
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IR_alloc_rob_entry == 1);
		assert(IR_q1_valid == 0);
		assert(IR_q2_valid == 0);
		assert(RS_route[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);
		assert(rob_tail == 4);

		assert(IF_instruction == 'hfef42623);
		# 10
		// PC = 0x1C
		// 0x8 (sw) has been executed and is being broadcast on the
		// address bus
		// 0xC (sw) has been executed and is waiting to broadcast to
		// the address bus next cycle
		// 0x10 (addi) is executing in its ALU FU
		// 0x14 (li => addi) is being routed to an ALU FU
		// 0x18 (sw) is being decoded

		// assertions to ensure nothing is committing this cycle
		assert(rob_commit == 0);
		assert(rob_head == 2);

		// assertions for 0x8 bus broadcast
		// at this point, not supporting N_AGU_RS < 2
		assert(address_bus_valid == 1);
		assert(address_bus_tag == 2);

		// not asserting anything for 0xC, it's in its output buffer
		// waiting to broadcast to the address bus

		// assertions for 0x10 execution
		assert(RS_ready_to_execute[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);
		assert(RS_dispatched[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);

		// assertions for 0x14 routing to an ALU RS
		RS_route_snapshot[IR_pc] = RS_route;
		assert(RS_route[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);	// ensure it's routed to ANY ALU rs, idc which one
		assert(IR_alloc_rob_entry == 1);
		// this is a li, so no operand dependencies
		assert(IR_q1_valid == 0);
		assert(IR_q2_valid == 0);
		assert(rob_tail == 5);

		assert(IF_instruction == 'h00500793);
		# 10
		// PC = 0x20
		// 0x8 (sw) has been broadcast to the address bus, so rob_ready should be set and it
		// should commit
		// 0xC (sw) is being broadcast to the address bus now
		// 0x10 (addi) has been stored in its output buffer and is being broadcast to the
		// CDB
		// 0x14 (li => addi) is executing in its ALU FU
		// 0x18 (sw) is being routed to an AGU, one should be available since 0x8 broadcast
		// to the address bus last cycle
		// 0x1C (li => addi) is being decoded
		// 0x20 (sw) is being fetched

		// assertions for 0x8 commit
		assert(rob_commit == 1);
		assert(rob_head == 2);
		assert(rob_ready[2] == 1);
		// nothing else matters, the rest is handled by the LSU
		// TODO: write assertions for the LSU after these stores
		// commit

		// assertions for 0xC bus broadcast
		assert(address_bus_valid == 1);
		assert(address_bus_tag == 3);

		// assertions for 0x10 CDB broadcast
		assert(cdb_valid == 1);
		assert(cdb_rob_tag == 4);
		assert(cdb_data == 'h1000);

		// assertions for 0x14 execution
		assert(RS_ready_to_execute[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);
		assert(RS_dispatched[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);

		// assertions for 0x18 routing
		// its register operand comes from the result of 0x10, which
		// is being broadcast on the CDB
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IR_alloc_rob_entry == 1);
		assert(IR_alloc_stq_entry == 1);
		assert(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
		assert(IR_q1_valid == 0);	// this value is being forwarded from the CDB
		assert(IR_v1 == 'h1000);
		$display("0x18 IR_immediate: 0x%h", IR_immediate);
		assert(IR_immediate == -20);
		assert(rob_tail == 6);

		assert(IF_instruction == 'hfef42423);
		# 10
		// PC = 0x24
		// 0xC (sw) is being committed
		// 0x10 (addi) has been recorded in the CDB and is ready to
		// commit
		// 0x14 (li => addi) has been stored in the output buffer and
		// is being broadcast to the CDB
		// 0x18 (sw) is executing in an AGU FU
		// 0x1C (li => addi) is being routed to an ALU FU
		// 0x20 (sw) is being decoded
		// 0x24 (lw) is being fetched

		// assertions for 0xC commit
		assert(rob_commit == 1);
		assert(rob_head == 3);
		assert(rob_ready[3] == 1);

		// assertions for 0x10
		assert(rob_ready[4] == 1);

		// assertions for 0x14 broadcast to CDB
		assert(cdb_valid == 1);
		assert(cdb_rob_tag == 5);
		assert(cdb_data == 4);

		// assertions for 0x18 execution
		assert(RS_ready_to_execute[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
		assert(RS_dispatched[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);

		// assertions for 0x1C being routed to an ALU FU
		RS_route_snapshot[IR_pc] = RS_route;
		assert(RS_route[ALU_RS_END_INDEX:ALU_RS_START_INDEX] != 0);	// ensure it's routed to ANY ALU rs, idc which one
		assert(IR_alloc_rob_entry == 1);
		// this is a li, so no operand dependencies
		assert(IR_q1_valid == 0);
		assert(IR_q2_valid == 0);
		assert(rob_tail == 7);

		assert(IF_instruction == 'hfec42703);
		# 10
		// PC = 0x28
		// 0x10 (addi) is being committed
		// 0x14 (li => addi) has been recorded in the CDB and is ready
		// to commit
		// 0x18 (sw) is broadcasting its address to the address bus
		// 0x1C (li => addi) is executing in an ALU FU
		// 0x20 (sw) is being routed.  Its data should not be ready this cycle.
		// 0x24 (lw) is being decoded
		// 0x28 (lw) is being fetched

		// assertions for 0x10 commit
		assert(rob_commit == 1);
		assert(rob_head == 4);
		assert(rob_ready[4] == 1);

		// assertions for 0x14
		assert(rob_ready[5] == 1);

		// assertions for 0x18 broadcasting to the address bus
		assert(address_bus_valid == 1);
		assert(address_bus_tag == 6);
		assert(address_bus_data == 'hFEC);
		assert((~RS_reset & RS_route_snapshot['h18]) != 0);

		// assertions for 0x1C execution
		assert((RS_ready_to_execute & RS_route_snapshot['h1C]) != 0);
		assert((RS_dispatched & RS_route_snapshot['h1C]) != 0);
		assert((FU_write_to_buffer & RS_route_snapshot['h1C]) != 0);

		// assertions for 0x20 route
		RS_route_snapshot[IR_pc] = RS_route;
		assert(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
		assert(rob_tail == 8);

		assert(IF_instruction == 'hfe842783);
		# 10
		// PC = 0x2C
		// 0x14 (li => addi) is being committed
		// 0x18 (sw) is ready in the ROB.  It's dependent on the result from the li, but the
		// store will not commit until the LI has committed, meaning the data will be in the
		// store queue.
		// 0x1C (li => addi) has been stored in an ALU output buffer and is broadcasting its
		// value to the CDB
		// 0x20 (sw) is performing an address computation in an AGU FU.  Its data is being
		// broadcast to the CDB this cycle.  Next cycle, verify it has been stored in the
		// store_queue.
		// 0x24 (lw) is being routed to an AGU FU.
		// 0x28 (lw) is being decoded
		// 0x2C (add) is being fetched

		// assertions for 0x14 commit
		assert(rob_commit == 1);
		assert(rob_head == 5);
		assert(rob_ready[5] == 1);

		// assertions for 0x18
		assert(rob_ready[6] == 1);

		// assertions for 0x1C CDB broadcast
		assert(cdb_valid == 1);
		assert(cdb_rob_tag == 7);
		assert(cdb_data == 5);
		assert((~RS_reset & RS_route_snapshot['h1C]) != 0);

		// assertions for 0x20 address computation
		assert((RS_ready_to_execute & RS_route_snapshot['h20]) != 0);
		assert((RS_dispatched & RS_route_snapshot['h20]) != 0);
		assert((FU_write_to_buffer & RS_route_snapshot['h20]) != 0);

		// assertions for 0x24 routing
		RS_route_snapshot[IR_pc] = RS_route;
		assert(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
		assert(rob_tail == 9);

		assert(IF_instruction == 'h00f707b3);
		# 10

		// PC = 0x30
		// 0x18 (sw) is being committed
		// 0x1C (li => addi) is ready to commit in the ROB
		// 0x20 (sw) is broadcasting its address computation to the address bus.  Its
		// store_queue entry should have captured the data from the CDB last cycle.  Its
		// reservation station should clear next cycle.
		// 0x24 (lw) is performing an address computation in an AGU FU.
		// 0x28 (lw) is being routed to an AGU reservation station.  Since there are fewer than
		// 3 AGUs, this causes a front-end stall since two AGU reservation stations are
		// occupied.
		// 0x2C (add) is being decoded
		// 0x30 (sw) is being fetched

		// assertions for 0x18 commit
		assert(rob_commit == 1);
		assert(rob_head == 6);
		assert(rob_ready[6] == 1);

		// assertions for 0x1C
		assert(rob_ready[7] == 1);

		// assertions for 0x20
		assert(address_bus_valid == 1);
		assert(address_bus_tag == 8);
		assert(address_bus_data == 'hFE8);
		assert((~RS_reset & RS_route_snapshot['h20]) != 0);

		// assertions for 0x24 (lw) execution
		assert((RS_ready_to_execute & RS_route_snapshot['h24]) != 0);
		assert((FU_write_to_buffer & RS_route_snapshot['h24]) != 0);

		// assertions for the 0x28 (lw) routing - stall
		assert(IR_stall == 1);

		assert(IF_instruction == 'hfef42223);
		# 10
		// PC = 0x30 since the front-end was stalled
		// 0x1C (li => addi) is being committed
		// 0x20 (sw) is ready to commit in the ROB
		// 0x24 (lw) is broadcasting its address computation to the address bus.  This will
		// not be ready to commit in the ROB until the load result is broadcast to the CDB.
		// The AGU RS will still be cleared since the address is computed, and the
		// instruction tracking will be done by the load_queue and the ROB.
		// 0x28 (lw) is being routed to an AGU reservation station.
		// 0x2C (add) is being decoded
		// 0x30 (sw) is being fetched

		// assertions for 0x1C commit
		assert(rob_commit == 1);
		assert(rob_head == 7);
		assert(rob_ready[7] == 1);

		// assertions for 0x20
		assert(rob_ready[8] == 1);

		// assertions for 0x24 broadcasting to the CDB and resetting the reservation station
		assert(AGU_FU_buf_not_empty != 0);
		assert(address_bus_valid == 1);
		assert(address_bus_tag == 9);
		assert(address_bus_data == 'hFEC);
		assert((~RS_reset & RS_route_snapshot['h24]) != 0);

		// assertions for 0x28 route
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IR_stall == 0);
		assert(RS_route[AGU_RS_END_INDEX:AGU_RS_START_INDEX] != 0);
		assert(rob_tail == 10);

		assert(IF_instruction == 'hfef42223);
		# 10
		// PC = 0x34
		// 0x20 (sw) is being committed
		// 0x24 (lw) has completed its address computation, freed its RS, and is awaiting
		// its value on the CDB.
		// 0x28 (lw) is performing an address computation in an AGU FU.
		// 0x2C (add) is being routed to an ALU FU.
		// 0x30 (sw) is being decoded
		// 0x34 (lw) is being fetched

		// assertions for 0x20 commit
		assert(rob_commit == 1);
		assert(rob_head == 8);

		RS_route_snapshot[IR_pc] = RS_route;
		assert(IF_instruction == 'hfe442783);
		# 10
		// PC = 0x38
		// 0x24 (lw) is at the head of the ROB awaiting its data before it can commit.
		// 0x28 (lw) is broadcasting its address computation to the address bus.  This will
		// not be ready to commit in the ROB until the load result is broadcast to the CDB.
		// The AGU RS will be cleared.
		// 0x2C (add) is awaiting its operands from the previous two lw instructions in an
		// ALU RS.
		// 0x30 (sw) is being routed to an AGU RS.
		// 0x34 (lw) is being decoded
		// 0x38 (mv => addi) is being fetched

		// assertions for 0x24
		assert(rob_commit == 0);
		assert(rob_head == 9);

		// assertions for 0x24 status in ROB
		assert(rob_ready[9] == 0);

		// assertions for 0x28 broadcasting to address bus
		assert(address_bus_valid == 1);
		assert(address_bus_tag == 10);

		// assertions for 0x2C in RS

		// assertions for 0x30 routing
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IR_stall == 0);

		assert(IF_instruction == 'h00078513);
		# 10
		// PC = 0x3C
		// 0x24 (lw) is at the head of the ROB awaiting its data before it can commit.
		// 0x28 (lw) has completed its address computation and broadcast to the address bus.
		// Its AGU RS has been freed.  This load is also waiting to find its data on the
		// CDB.
		// 0x2C (add) is waiting to find both operands from the previous two lw instructions
		// on the CDB.
		// 0x30 (sw) is performing an address computation in an AGU.
		// 0x34 (lw) is being routed to an AGU FU.
		// 0x38 (mv => addi) is being decoded
		// 0x3C (lw) is being fetched
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IF_instruction == 'h01c12083);
		# 10
		// PC = 0x40
		// 0x24 (lw) is at the head of the ROB awaiting its data before it can commit.
		// 0x28 (lw) is in the ROB awaiting its data before it is ready to commit.
		// 0x2C (add) is waiting to find both operands from the previous two lw instructions
		// on the CDB.
		// 0x30 (sw) is broadcasting its address computation to the address bus.  Next cycle,
		// the occupied AGU RS will be freed and the instruction will be marked as ready to
		// commit in the ROB.
		// 0x34 (lw) is executing in an AGU FU.
		// 0x38 (mv => addi) is being routed to an ALU FU.
		// 0x3C (lw) is being decoded
		// 0x40 (lw) is being fetched
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IF_instruction == 'h01812403);
		# 10
		// PC = 0x44
		// 0x24 (lw) is at the head of the ROB awaiting its data before it can commit.
		// 0x28 (lw) is in the ROB awaiting its data before it is ready to commit.
		// 0x2C (add) is waiting to find both operands from the previous two lw instructions
		// on the CDB.
		// 0x30 (sw) is ready to commit.
		// 0x34 (lw) is broadcasting its address computation to the address bus.  Next cycle,
		// the occupied AGU RS will be freed and the instruction will be marked as ready to
		// commit in the ROB.
		// 0x38 (mv => addi) is in an ALU RS awaiting its register operand, which comes from
		// the add instruction at 0x2C
		// 0x3C (lw) is being routed to an AGU FU.
		// 0x40 (lw) is being decoded
		// 0x44 (addi) is being fetched
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IF_instruction == 'h02010113);
		# 10
		// PC = 0x44
		// 0x24 (lw) is at the head of the ROB awaiting its data before it can commit.
		// 0x28 (lw) is in the ROB awaiting its data before it is ready to commit.
		// 0x2C (add) is waiting to find both operands from the previous two lw instructions
		// on the CDB.
		// 0x30 (sw) is ready to commit.
		// 0x34 (lw) is in the ROB awaiting its data before it is ready to commit.
		// 0x38 (mv => addi) is in an ALU RS awaiting its register operand, which comes from
		// the add instruction at 0x2C
		// 0x3C (lw) is executing in an AGU FU
		// 0x40 (lw) is being routed to an AGU FU
		// 0x44 (addi) is being decoded
		// 0x48 (ret => jalr) is being fetched
		RS_route_snapshot[IR_pc] = RS_route;
		assert(IF_instruction == 'h00008067);

		$display("All assertions passed.");
		$finish();
	end
endmodule
