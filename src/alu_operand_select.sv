module alu_operand_select #(parameter XLEN=32) (
	input logic [XLEN-1:0] rs1,
	input logic [XLEN-1:0] rs2,
	input logic [XLEN-1:0] immediate,
	// NOTE: THIS IS NOT PC + 4, THIS IS THE PC OF THE INSTRUCTION
	// USED FOR AUIPC
	input logic [XLEN-1:0] pc,

	input logic [1:0] alu_op1_src,
	input logic alu_op2_src,

	output logic [XLEN-1:0] alu_op1,
	output logic [XLEN-1:0] alu_op2);
	
	always_comb
		case (alu_op1_src)
			0:	alu_op1 = rs1;
			1:	alu_op1 = pc;	// AUIPC
			2:	alu_op1 = 0;	// LUI
		endcase

	always_comb
		case (alu_op2_src)
			0:	alu_op2 = rs2;
			1:	alu_op2 = immediate;
		endcase
endmodule
