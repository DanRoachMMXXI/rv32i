/*
 * As I'm using verilator to simulate, there's an open issue regarding
 * Warning-MULTIDRIVEN on unpacked structures when different processes/always
 * blocks modify different signals of the struct
 * https://github.com/verilator/verilator/issues/4226
 * For my use case, packing the structure is a viable workaround.
 * In fact, this has proven convenient in clearing the entire control signal
 * bus, as you can just assign 0 to it.
 */
typedef struct packed {
	// carry forward funct3, as it's already encoded for use by the ALU
	logic [2:0] funct3;

	// valid exists for a couple reasons
	// - if a pipeline stage is reset to 0, valid will be set to 0, so the
	// router will use that to ensure nothing is allocated in the ROB or
	// load and store queues
	// - if an instruction in the route stage is folded into an
	// instruction in the decode stage, the decode stage can clear the
	// valid bit seen by the router to again ensure nothing is allocated
	// in the ROB (or load and store queues if those instructions are ever
	// folded).
	logic	valid;

	// boolean to indicate length of the instruction, in case I support
	// compressed instructions in the future
	// 0 = 2 bytes (compressed)
	// 1 = 4 bytes (normal RV32I instruction)
	logic		instruction_length;

	// register indices
	logic [4:0] rs1_index;
	logic [4:0] rs2_index;
	logic [4:0] rd_index;

	logic [1:0] alu_op1_src;	// mux input to select data source for
					// the first opernad of the alu
					// 0 for register value, 1 for PC,
					// 2 for 32'b0

	logic alu_op2_src;	// mux input to select data source for
				// the second operand of the alu
				// 0 for register value, 1 for immediate
	logic [1:0] rd_select;	// mux select to select the data source
				// to write back to the register file
				// 0: alu
				// 1: memory
				// 2: pc + 4 for jump instructions

	// alu control signals
	logic sign;	// only used in R type instructions

	// branch and jump signals
	// it feels a bit odd to have three signals for this but I haven't
	// been able to reduce it further.  branching logic is as follows:
	// branch if (jump || (branch && (branch_if_zero ~^ zero)))
	// in english:
	// branch if unconditional jump or conditional and condition is met
	// these signals go into the branch_module
	logic branch;		// bool to jump conditionally
	logic branch_if_zero;	// bool indicating the condition to jump
	logic jump;		// bool to jump unconditionally
	logic jalr;		// for jumps, this tracks whether it's a JAL or JALR
				// if branch_target = base + immediate, the
				// jalr signal will be used to track what the
				// base is
				// 0: pc
				// 1: rs1 for JALR

	logic lui;	// is the instruction specifically LUI - it has to get specifically routed to the ROB
	logic auipc;	// is the instruction specifically AUIPC - it has to get specifically routed to the ROB
	logic u_type;	// is the instruction LUI or AUIPC
	// in the out-of-order design, U_TYPE instructions will not be issued
	// to a functional unit.  instead, their value will already be
	// available, and it will be written directly to the reorder buffer.

	// signals to write back to register file or memory
	logic rf_write_en;
	logic mem_write_en;

	// out of order signals
	// instruction_type: tracks the "out-of-order type" of instruction
	// being executed to route it to the correct FU and for use by the ROB
	// to know how/where to commit the instruction
	// 00 - ALU
	// 01 - branch
	// 10 - load
	// 11 - store
	logic [1:0] instruction_type;

	logic alloc_rob_entry;
	logic alloc_ldq_entry;
	logic alloc_stq_entry;

	logic fold;

	// source for operand 1 for the out-of-order design
	// 2'b00: 0
	// 2'b01: pc
	// 2'b1X: rs1
	logic [1:0] op1_src;

	// source for operand 2 for the out-of-order design
	// 2'b00: 0
	// 2'b01: immediate
	// 2'b1X: rs2
	logic [1:0] op2_src;
} control_signal_bus;
