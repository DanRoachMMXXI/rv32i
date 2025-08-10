`ifndef OPCODE_SV
`define OPCODE_SV

package opcode;
	logic[6:0] R_TYPE = 'b0110011;
	logic[6:0] I_TYPE_ALU = 'b0010011;
	logic[6:0] I_TYPE_LOAD = 'b0000011;
	logic[6:0] I_TYPE_JALR = 'b1100111;
	logic[6:0] B_TYPE = 'b1100011;
	logic[6:0] S_TYPE = 'b0100011;
	logic[6:0] JAL = 'b1101111;
	logic[6:0] LUI = 'b0110111;
	logic[6:0] AUIPC = 'b0010111;

	const logic[6:0] opcodes[] = '{
		R_TYPE,
		I_TYPE_ALU,
		I_TYPE_LOAD,
		I_TYPE_JALR,
		B_TYPE,
		S_TYPE,
		JAL,
		LUI,
		AUIPC
	};
endpackage

`endif
