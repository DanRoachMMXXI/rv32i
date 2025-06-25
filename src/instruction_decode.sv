module instruction_decode #(parameter XLEN=32) (
	input logic [31:0] instruction,

	// register indices
	output logic [4:0] rs1,
	output logic [4:0] rs2,
	output logic [4:0] rd,

	output logic [XLEN-1:0] immediate,

	output logic op1_src,	// mux input to select data source for
				// the first opernad of the alu
				// 0 for register value, 1 for 32'b0

	output logic op2_src,	// mux input to select data source for
				// the second operand of the alu
				// 0 for register value, 1 for immediate

	// alu control signals
	output logic [2:0] alu_op,
	output logic sign,	// only used in R type instructions

	// branch and jump signals
	// it feels a bit odd to have three signals for this but I haven't
	// been able to reduce it further.  branching logic is as follows:
	// branch if (jump || (branch && (branch_if_zero ~^ zero)))
	// in english:
	// branch if unconditional jump or conditional and condition is met
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

	logic opcode = inst[6:0];
	logic funct3 = inst[14:12];

	// these values always map to these bits in the instruction ... but
	// these bits in the instruction are not always interpreted as these
	// values
	assign rs1 = inst[19:15];
	assign rs2 = inst[24:20];
	assign rd = inst[11:7];

	// branch and jump signals
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

	// ALU operation and sign
	always_comb
		if (opcode == 'b1100011)	// B type
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
				begin
					alu_op = 'b000;
					sign = 0;
				end
			endcase
		else	// R type and I type, and other instruction types will not read this
		begin
			alu_op = funct3;
			sign = (opcode == R_TYPE) ? inst[30] : 0;	// R type specific
		end

	// Immediate value assignment
	// Page 27
	always_comb
		case (opcode)
			R_TYPE:
				immediate = 0;
			I_TYPE_ALU,
			I_TYPE_LOAD,
			I_TYPE_JALR:
				immediate = {{XLEN{inst[31]}}, inst[31:20]};	// TODO test
			B_TYPE:
				immediate = {{XLEN{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
			S_TYPE:
				immediate = {{XLEN{inst[31]}}, inst[31:25], inst[11:7]};

			JAL:
				immediate = {{XLEN{inst[31]}}, inst[20], inst[10:1], inst[11], inst[19:12], 1'b0};
			LUI,
			AUIPC:
				immediate = {inst[31:12], {12{'b0}}};
			default:
				immediate = 0;
		endcase

	// ALU OP1 source
	// This is almost always the register value, but in the case of lui,
	// we can just use the ALU's adder to add 0 with the immediate
	always_comb
		case (opcode)
			LUI:
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

	// B type
	// using registers for comparison, using separate adder to
	// compute new PC

	// S type
	// address = rs1 + imm
	// rs2 gets stored

	// TODO:
	// seems we need an additional adder for PC + immediate, this
	// satisfies branch computations
	// TODO: op1_src to include PC for AUIPC, I didn't realize this stores
	// the result in rd
	// TODO: rf_write_en and mem_write_en
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
