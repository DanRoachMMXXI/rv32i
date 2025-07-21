interface memory_if #(
	parameter XLEN=32,
	parameter ADDR_WIDTH=32,
	parameter MEM_FILE = "") (
	input logic clk
	);
	// inputs
	logic reset;
	logic [ADDR_WIDTH-1:0] address;
	logic write_en;
	logic [XLEN-1:0] data_in;
	logic [XLEN-1:0] data_out;
endinterface
