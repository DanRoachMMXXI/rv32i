interface register_file_if
	#(parameter XLEN=32, ADDR_WIDTH=5) (
	input logic clk
);
	// inputs
	logic reset;
	logic [ADDR_WIDTH-1:0] rs1_index;
	logic [ADDR_WIDTH-1:0] rs2_index;
	logic [ADDR_WIDTH-1:0] rd_index;
	logic [XLEN-1:0] rd;
	logic write_en;

	// outputs
	logic [XLEN-1:0] rs1;
	logic [XLEN-1:0] rs2;
endinterface
