interface alu_if #(parameter XLEN=32) ();
	logic [XLEN-1:0] a;
	logic [XLEN-1:0] b;
	logic [2:0] op;
	logic sign;
	logic [XLEN-1:0] result;
	logic zero;
endinterface
