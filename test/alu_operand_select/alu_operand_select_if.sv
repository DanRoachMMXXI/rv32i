interface alu_operand_select_if #(parameter XLEN=32) ();
	logic [XLEN-1:0] rs1;
	logic [XLEN-1:0] rs2;
	logic [XLEN-1:0] immediate;
	logic [XLEN-1:0] pc;
	logic [1:0] alu_op1_src;
	logic alu_op2_src;
	logic [XLEN-1:0] alu_op1;
	logic [XLEN-1:0] alu_op2;
endinterface
