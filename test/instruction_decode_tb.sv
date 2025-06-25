module instruction_decode_tb();
	logic [31:0] instruction;
	logic [4:0] rs1;
	logic [4:0] rs2;
	logic [4:0] rd;

	logic [31:0] immediate;
	logic op1_src;
	logic op2_src;
	logic [2:0] alu_op;
	logic sign;
	logic branch;
	logic branch_if_zero;
	logic jump;
	logic rf_write_en;
	logic mem_write_en;
endmodule
