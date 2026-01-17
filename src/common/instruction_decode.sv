module immediate_decode #(parameter XLEN=32) (
	input logic [31:0] instruction,
	output logic [XLEN-1:0] immediate
	);

	logic [6:0] opcode;

	assign opcode = instruction[6:0];

	// Immediate value computation and assignment
	// Page 27
	always_comb
		case (opcode)
			'b0010011, 'b0000011, 'b1100111:	// I_TYPE
				immediate = {
					{XLEN{instruction[31]}}, instruction[31:20]
				}[XLEN-1:0];
			'b1100011:	// B_TYPE
				immediate = {
					{XLEN{instruction[31]}},
					instruction[7],
					instruction[30:25],
					instruction[11:8],
					1'b0
				}[XLEN-1:0];
			'b0100011:	// S_TYPE
				immediate = {
					{XLEN{instruction[31]}},
					instruction[31:25],
					instruction[11:7]
				}[XLEN-1:0];
			'b1101111:	// J type
				immediate = {
					{XLEN{instruction[31]}},
					instruction[19:12],
					instruction[20],
					instruction[30:21],
					1'b0
				}[XLEN-1:0];
			'b0110111, 'b0010111:	// U type
				immediate = {
					instruction[31:12],
					{12{1'b0}}
				};
			default:
				immediate = 0;
		endcase
endmodule

module branch_decode (
	input logic [6:0] opcode,
	input logic [2:0] funct3,
	output logic jump,
	output logic jalr,
	output logic branch,
	output logic branch_if_zero
	);

	// JAL || I_TYPE_JALR
	assign jump = (opcode == 'b1101111 || opcode == 'b1100111) ? 1 : 0;
	assign jalr = opcode == 'b1100111;
	assign branch = (opcode == 'b1100011) ? 1 : 0;	// B_TYPE
	always_comb
		case (funct3)
			'b000,	// beq
			'b011,	// bge
			'b111:	// bgeu
				branch_if_zero = 1;
			default:
				branch_if_zero = 0;
		endcase
endmodule

module alu_decode (
	input logic [31:0] instruction,
	output logic [2:0] alu_operation,
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
		if (opcode == 'b1100011)	// B_TYPE
			unique case (funct3)
				'b000, 'b001:	// beq and bne
				begin
					alu_operation = 'b000;
					sign = 1;
				end

				'b100, 'b101:	// blt and bge
				begin
					alu_operation = 'b010;
					sign = 0;
				end

				'b110, 'b111:	// bltu and bgeu
				begin
					alu_operation = 'b011;
					sign = 0;
				end
			endcase
		// LUI and AUIPC utilize the ALU for addition
		// STOREs and LOADs utilize the ALU for addition to compute
		// the memory address
		// STOREs and LOADs utilize funct3 to specify size: lb vs lh
		// vs lw.  TODO implement ^, probably in a memory_decode module
		else if (opcode == 'b0110111		// LUI
				|| opcode == 'b0010111	// AUIPC
				|| opcode == 'b0000011	// I_TYPE_LOAD
				|| opcode == 'b0100011)	// S_TYPE
		begin
			alu_operation = 'b000;
			sign = 0;
		end
		else	// R type and I type, and other instruction types will not read this
		begin
			alu_operation = funct3;
			sign = (opcode == 'b0110011) ? instruction[30] : 0;	// R type specific
		end

	// ALU OP1 source
	// This is almost always the register value.
	// In the case of auipc, we pass the PC into the adder to add with the immediate
	// In the case of lui, we can just use the ALU's adder to add 0 with the immediate
	always_comb
		case (opcode)
			'b0110111:	// LUI
				op1_src = 2;
			'b0010111:	// AUIPC
				op1_src = 1;
			default:
				op1_src = 0;
		endcase

	// ALU OP2 source
	always_comb
		case (opcode)
			'b0110011,	// R_TYPE
			'b1100011:	// B_TYPE
				op2_src = 0;

			'b0010011,	// I_TYPE_ALU
			'b0000011,	// I_TYPE_LOAD
			'b1100111,	// I_TYPE_JALR
			'b0100011,	// S_TYPE
			'b0110111:	// LUI
				op2_src = 1;

			default:	// ALU unused or illegal instruction
				op2_src = 0;
		endcase
endmodule

module out_of_order_decode (
	input logic [6:0] opcode,
	output logic [1:0] instruction_type
	);

	always_comb begin
		case (opcode)
			'b0110011,	// R_TYPE
			'b0010011,	// I_TYPE_ALU
			'b0110111,	// LUI
			'b0010111:	// AUIPC
				instruction_type = 'b00;	// ALU
			'b1100111,	// I_TYPE_JALR
			'b1100011,	// B_TYPE
			'b1101111:	// J_TYPE
				instruction_type = 'b01;	// branch
			'b0000011:	// I_TYPE_LOAD
				instruction_type = 'b10;	// load
			'b0100011:	// S_TYPE
				instruction_type = 'b11;	// store
			default:
				instruction_type = 'b00;
		endcase
	end
endmodule

module instruction_decode #(parameter XLEN=32) (
	input logic [31:0] instruction,
	output logic [XLEN-1:0] immediate,
	output control_signal_bus control_signals
	);

	logic [6:0] opcode;
	logic [2:0] funct3;

	assign opcode = instruction[6:0];
	assign funct3 = instruction[14:12];

	// these values always map to these bits in the instruction ... but
	// these bits in the instruction are not always interpreted as these
	// values
	assign control_signals.rs1_index = instruction[19:15];
	assign control_signals.rs2_index = instruction[24:20];
	assign control_signals.rd_index = instruction[11:7];

	// branch and jump signals
	branch_decode branch_decode(
		.opcode(opcode),
		.funct3(funct3),
		.jump(control_signals.jump),
		.branch(control_signals.branch),
		.branch_if_zero(control_signals.branch_if_zero),
		.jalr(control_signals.jalr));


	immediate_decode #(.XLEN(32)) immediate_decode(
		.instruction(instruction),
		.immediate(immediate));

	alu_decode alu_decode(
		.instruction(instruction),
		.alu_operation(control_signals.alu_operation),
		.sign(control_signals.sign),
		.op1_src(control_signals.alu_op1_src),
		.op2_src(control_signals.alu_op2_src));

	// RF writeback source
	always_comb
		case (opcode)
			'b0110011,	// R_TYPE
			'b0010011,	// I_TYPE_ALU
			'b0110111,	// LUI
			'b0010111:	// AUIPC
				control_signals.rd_select = 0;
			'b0000011:	// I_TYPE_LOAD
				control_signals.rd_select = 1;
			'b1101111,	// JAL
			'b1100111:	// I_TYPE_JALR
				control_signals.rd_select = 2;

			// RF is not written by this instruction, or the
			// instruction is illegal
			default:
				control_signals.rd_select = 0;
		endcase

	// Register file and memory write enable signals
	always_comb
		case (opcode)
			'b0110111,	// LUI
			'b0010111,	// AUIPC
			'b0110011,	// R_TYPE
			'b1101111,	// JAL
			'b0010011,	// I_TYPE_ALU
			'b0000011,	// I_TYPE_LOAD
			'b1100111:	// I_TYPE_JALR
				control_signals.rf_write_en = 1;
			default:
				control_signals.rf_write_en = 0;
		endcase
	assign control_signals.mem_write_en = (opcode == 'b0100011) ? 1 : 0;	// S_TYPE

	out_of_order_decode ooo_decode (
		.opcode(opcode),
		.instruction_type(control_signals.instruction_type)
	);
endmodule
