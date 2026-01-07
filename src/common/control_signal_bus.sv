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
	logic [2:0] alu_operation;
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
	logic branch_base;	// if branch_target = base + immediate, this signal
				// tracks what the base is
				// 0: pc_plus_four
				// 1: rs1 for 'b1101111R

	// signals to write back to register file or memory
	logic rf_write_en;
	logic mem_write_en;

	// out of order signals
	// instruction_type: tracks the "OOO type" of instruction being
	// executed to route it to the correct FU and for use by the ROB to
	// know how/where to commit the instruction
	// 00 - ALU
	// 01 - branch
	// 10 - load
	// 11 - store
	logic [1:0] instruction_type;
} control_signal_bus;
