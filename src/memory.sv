module memory #(
	parameter XLEN=32,
	parameter ADDR_WIDTH=32,
	parameter MEM_FILE = "") (
	input logic clk,
	input logic reset,	// active low reset
	input logic [ADDR_WIDTH-1:0] address,
	input logic write_en,
	input logic [XLEN-1:0] data_in,
	output logic [XLEN-1:0] data_out
	);

	reg [XLEN-1:0] memory [0:((2**ADDR_WIDTH)-1)];
	integer i;

	initial begin
		if (MEM_FILE != "") begin
			$readmemh(MEM_FILE, memory);
		end else begin
			for (i = 0; i < ((2**ADDR_WIDTH)-1); i = i + 1) begin
				memory[i] = 0;
			end
		end
	end

	// This was taken from ChipVerify without the select signal
	// https://www.chipverify.com/verilog/verilog-arrays-memories
	// TODO: test
	// potential modifications:
	// - add select signal
	// - remove else block for updating memory contents
	always @ (posedge clk) begin
		if (!reset) begin
			for (i = 0; i < ((2**ADDR_WIDTH)-1); i = i + 1) begin
				memory[i] <= 0;
			end
		end else begin
			if (write_en)
				memory[address] <= data_in;
			else	// is this really necessary?
				memory[address] <= memory[address];
		end
	end

	// TODO maybe copy ChipVerify part
	assign data_out = memory[address];
endmodule
