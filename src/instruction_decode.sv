/*
 * TODO
 * use comments to denote which opcodes correlate to which
 * instructions/instruction types, now that the defined values from the opcodes
 * package have been removed for synthesis.
 */
module immediate_decode #(parameter XLEN=32) (
	input logic [31:0] instruction,
	output logic [XLEN-1:0] immediate
	);

	logic [6:0] opcode;

	assign opcode = instruction[6:0];

	// Immediate value computation and assignment
	// Page 27
	/* verilator lint_off WIDTHTRUNC */
	always_comb
		case (opcode)
			'b0010011, 'b0000011, 'b1100111:
				immediate = {
					{XLEN{instruction[31]}}, instruction[31:20]
				};
			'b1100011:
				immediate = {
					{XLEN{instruction[31]}},
					instruction[31],
					instruction[7],
					instruction[30:25],
					instruction[11:8],
					1'b0
				};
			'b0100011:
				immediate = {
					{XLEN{instruction[31]}},
					instruction[31:25],
					instruction[11:7]
				};
			'b1101111:		// J type
				immediate = {
					{XLEN{instruction[31]}},
					instruction[20],
					instruction[10:1],
					instruction[11],
					instruction[19:12],
					1'b0
				};
			'b0110111, 'b0010111:	// U type
				immediate = {
					instruction[31:12],
					{12{1'b0}}
				};
			default:
				immediate = 0;
		endcase
	/* verilator lint_on WIDTHTRUNC */
endmodule

module branch_decode (
	input logic [6:0] opcode,
	input logic [2:0] funct3,
	output logic jump,
	output logic branch,
	output logic branch_if_zero,
	output logic branch_base
	);

	assign jump = (opcode == 'b1101111 || opcode == 'b1100111) ? 1 : 0;
	assign branch = (opcode == 'b1100011) ? 1 : 0;
	always_comb
		case (funct3)
			'b000,	// beq
			'b011,	// bge
			'b111:	// bgeu
				branch_if_zero = 1;
			default:
				branch_if_zero = 0;
		endcase
	assign branch_base = (opcode == 'b1100111) ? 1 : 0;
endmodule

module alu_decode (
	input logic [31:0] instruction,
	output logic [2:0] alu_op,
	output logic sign,
	output logic [1:0] op1_src,
	output logic op2_src
	);

	logic [6:0] opcode;
	logic [2:0] funct3;

	assign opcode = instruction[6:0];
	assign funct3 = instruction[14:12];

	// ALU operation and sign
	always_comb
		if (opcode == 'b1100011)
			case (funct3)
				'b000, 'b001:	// beq and bne
				begin
					alu_op = 'b000;
					sign = 1;
				end

				'b100, 'b101:	// blt and bge
				begin
					alu_op = 'b010;
					sign = 0;
				end

				'b110, 'b111:	// bltu and bgeu
				begin
					alu_op = 'b011;
					sign = 0;
				end

				default:	// illegal instruction
						// TODO: fault
				begin
					alu_op = 'b000;
					sign = 0;
				end
			endcase
		// 'b0110111 and 'b0010111 utilize the ALU for addition
		// STOREs and LOADs utilize the ALU for addition to compute
		// the memory address
		// STOREs and LOADs utilize funct3 to specify size: lb vs lh
		// vs lw.  TODO implement ^, probably in a memory_decode module
		else if (opcode == 'b0110111
				|| opcode == 'b0010111
				|| opcode == 'b0000011
				|| opcode == 'b0100011)
		begin
			alu_op = 'b000;
			sign = 0;
		end
		else	// R type and I type, and other instruction types will not read this
		begin
			alu_op = funct3;
			sign = (opcode == 'b0110011) ? instruction[30] : 0;	// R type specific
		end

	// ALU OP1 source
	// This is almost always the register value.
	// In the case of auipc, we pass the PC into the adder to add with the immediate
	// In the case of lui, we can just use the ALU's adder to add 0 with the immediate
	always_comb
		case (opcode)
			'b0110111:
				op1_src = 2;
			'b0010111:
				op1_src = 1;
			default:
				op1_src = 0;
		endcase

	// ALU OP2 source
	always_comb
		case (opcode)
			'b0110011,
			'b1100011:
				op2_src = 0;

			'b0010011,
			'b0000011,
			'b1100111,
			'b0100011,
			'b0110111:
				op2_src = 1;

			default:	// ALU unused or illegal instruction
				op2_src = 0;
		endcase
endmodule

module instruction_decode #(parameter XLEN=32) (
	input logic [31:0] instruction,

	// register indices
	output logic [4:0] rs1,
	output logic [4:0] rs2,
	output logic [4:0] rd,

	output logic [XLEN-1:0] immediate,

	output logic [1:0] op1_src,	// mux input to select data source for
					// the first opernad of the alu
					// 0 for register value, 1 for PC,
					// 2 for 32'b0

	output logic op2_src,	// mux input to select data source for
				// the second operand of the alu
				// 0 for register value, 1 for immediate
	output logic [1:0] rd_select,	// mux select to select the data source
					// to write back to the register file
					// 0: alu
					// 1: memory
					// 2: pc + 4 for jump instructions

	// alu control signals
	output logic [2:0] alu_op,
	output logic sign,	// only used in R type instructions

	// branch and jump signals
	// it feels a bit odd to have three signals for this but I haven't
	// been able to reduce it further.  branching logic is as follows:
	// branch if (jump || (branch && (branch_if_zero ~^ zero)))
	// in english:
	// branch if unconditional jump or conditional and condition is met
	// these signals go into the branch_module
	output logic branch,		// bool to jump conditionally
	output logic branch_if_zero,	// bool indicating the condition to jump
	output logic jump,		// bool to jump unconditionally
	output logic branch_base,	// if branch_target = base + immediate, this signal
					// tracks what the base is
					// 0: pc_plus_four
					// 1: rs1 for 'b1101111R

	// signals to write back to register file or memory
	output logic rf_write_en,
	output logic mem_write_en
	);

	logic [6:0] opcode;
	logic [2:0] funct3;

	assign opcode = instruction[6:0];
	assign funct3 = instruction[14:12];

	// these values always map to these bits in the instruction ... but
	// these bits in the instruction are not always interpreted as these
	// values
	assign rs1 = instruction[19:15];
	assign rs2 = instruction[24:20];
	assign rd = instruction[11:7];

	// branch and jump signals
	branch_decode branch_decode(
		.opcode(opcode),
		.funct3(funct3),
		.jump(jump),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.branch_base(branch_base));


	immediate_decode #(.XLEN(32)) immediate_decode(
		.instruction(instruction),
		.immediate(immediate));

	alu_decode alu_decode(
		.instruction(instruction),
		.alu_op(alu_op),
		.sign(sign),
		.op1_src(op1_src),
		.op2_src(op2_src));

	// RF writeback source
	always_comb
		case (opcode)
			'b0110011,
			'b0010011,
			'b0110111,
			'b0010111:
				rd_select = 0;

			'b0000011:
				rd_select = 1;

			'b1101111,
			'b1100111:
				rd_select = 2;

			// RF is not written by this instruction, or the
			// instruction is illegal
			default:
				rd_select = 0;
		endcase

	// Register file and memory write enable signals
	always_comb
		case (opcode)
			'b0110111,
			'b0010111,
			'b0110011,
			'b1101111,
			'b0010011,
			'b0000011,
			'b1100111:
				rf_write_en = 1;
			default:
				rf_write_en = 0;
		endcase
	assign mem_write_en = (opcode == 'b0100011) ? 1 : 0;

endmodule
