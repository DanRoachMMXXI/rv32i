interface instruction_decode_if #(parameter XLEN=32) ();
	// inputs
	logic [31:0] instruction;

	// outputs
	logic [4:0] rs1;
	logic [4:0] rs2;
	logic [4:0] rd;
	logic [XLEN-1:0] immediate;
	logic [1:0] op1_src;
	logic op2_src;
	logic [1:0] rd_select;
	logic [2:0] alu_op;
	logic sign;
	logic branch;
	logic branch_if_zero;
	logic jump;
	logic rf_write_en;
	logic mem_write_en;
endinterface
