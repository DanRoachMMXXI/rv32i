module branch_target #(parameter XLEN=32) (
	input logic [XLEN-1:0]	pc,
	input logic [XLEN-1:0]	rs1,
	input logic [XLEN-1:0]	immediate,
	input logic		jalr,

	output logic [XLEN-1:0]	branch_target
);
	assign branch_target = (jalr ? rs1 : pc) + immediate;
endmodule
