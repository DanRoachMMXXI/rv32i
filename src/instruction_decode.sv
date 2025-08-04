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

	// signals to write back to register file or memory
	output logic rf_write_en,
	output logic mem_write_en
	);

	localparam R_TYPE = 'b0110011;
	localparam I_TYPE_ALU = 'b0010011;
	localparam I_TYPE_LOAD = 'b0000011;
	localparam I_TYPE_JALR = 'b1100111;
	localparam B_TYPE = 'b1100011;
	localparam S_TYPE = 'b0100011;
	localparam JAL = 'b1101111;
	localparam LUI = 'b0110111;
	localparam AUIPC = 'b0010111;

	logic [6:0] opcode = instruction[6:0];
	logic [2:0] funct3 = instruction[14:12];

	// these values always map to these bits in the instruction ... but
	// these bits in the instruction are not always interpreted as these
	// values
	assign rs1 = instruction[19:15];
	assign rs2 = instruction[24:20];
	assign rd = instruction[11:7];

	// branch and jump signals
	assign jump = (opcode == JAL || opcode == I_TYPE_JALR) ? 1 : 0;
	assign branch = (opcode == B_TYPE) ? 1 : 0;
	always_comb
		case (funct3)
			'b000,	// beq
			'b011,	// bge
			'b111:	// bgeu
				branch_if_zero = 1;
			default:
				branch_if_zero = 0;
		endcase

	// ALU operation and sign
	always_comb
		if (opcode == B_TYPE)
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
		else if (opcode == LUI || opcode == AUIPC)	// LUI and AUIPC both utilize the ALU for addition
		begin
			alu_op = 'b000;
			sign = 0;
		end
		else	// R type and I type, and other instruction types will not read this
		begin
			alu_op = funct3;
			sign = (opcode == R_TYPE) ? instruction[30] : 0;	// R type specific
		end

	// Immediate value computation and assignment
	// Page 27
	/* verilator lint_off WIDTHTRUNC */
	logic [XLEN-1:0] i_type_immediate = {
		{XLEN{instruction[31]}}, instruction[31:20]
	};
	logic [XLEN-1:0] b_type_immediate = {
		{XLEN{instruction[31]}},
		instruction[31],
		instruction[7],
		instruction[30:25],
		instruction[11:8],
		1'b0
	};
	logic [XLEN-1:0] s_type_immediate = {
		{XLEN{instruction[31]}},
		instruction[31:25],
		instruction[11:7]
	};
	logic [XLEN-1:0] j_type_immediate = {
		{XLEN{instruction[31]}},
		instruction[20],
		instruction[10:1],
		instruction[11],
		instruction[19:12],
		1'b0
	};
	logic [XLEN-1:0] u_type_immediate = {
		instruction[31:12],
		{12{1'b0}}
	};
	/* verilator lint_on WIDTHTRUNC */

	always_comb
		case (opcode)
			I_TYPE_ALU, I_TYPE_LOAD, I_TYPE_JALR:
				immediate = i_type_immediate;
			B_TYPE:
				immediate = b_type_immediate;
			S_TYPE:
				immediate = s_type_immediate;
			JAL:		// J type
				immediate = j_type_immediate;
			LUI, AUIPC:	// U type
				immediate = u_type_immediate;
			default:
				immediate = 0;
		endcase

	// ALU OP1 source
	// This is almost always the register value.
	// In the case of auipc, we pass the PC into the adder to add with the
	// immedaiate
	// In the case of lui, we can just use the ALU's adder to add 0 with
	// the immediate
	always_comb
		case (opcode)
			LUI:
				op1_src = 2;
			AUIPC:
				op1_src = 1;
			default:
				op1_src = 0;
		endcase

	// ALU OP2 source
	always_comb
		case (opcode)
			R_TYPE,
			B_TYPE:
				op2_src = 0;

			I_TYPE_ALU,
			I_TYPE_LOAD,
			I_TYPE_JALR,
			S_TYPE,
			LUI:
				op2_src = 1;

			default:	// ALU unused or illegal instruction
				op2_src = 0;
		endcase

	// RF writeback source
	always_comb
		case (opcode)
			R_TYPE,
			I_TYPE_ALU,
			LUI,
			AUIPC:
				rd_select = 0;

			I_TYPE_LOAD:
				rd_select = 1;

			JAL,
			I_TYPE_JALR:
				rd_select = 2;

			// RF is not written by this instruction, or the
			// instruction is illegal
			default:
				rd_select = 0;
		endcase

	// Register file and memory write enable signals
	always_comb
		case (opcode)
			LUI,
			AUIPC,
			R_TYPE,
			JAL,
			I_TYPE_ALU,
			I_TYPE_LOAD,
			I_TYPE_JALR:
				rf_write_en = 1;
			default:
				rf_write_en = 0;
		endcase
	assign mem_write_en = (opcode == S_TYPE) ? 1 : 0;

endmodule
