module register_file
	#(parameter XLEN=32) (
	input logic clk,
	input logic reset,
	input logic [4:0] rs1_index,
	input logic [4:0] rs2_index,
	input logic [4:0] rd_index,
	input logic [XLEN-1:0] rd,
	input logic write_en,

	output logic [XLEN-1:0] rs1,
	output logic [XLEN-1:0] rs2);

	reg [XLEN-1:0] registers [0:31];
	integer i;
	
	always @(posedge clk)
		if (!reset) begin
			for (i = 0; i < 32; i = i + 1) begin
				registers[i] <= 0;
			end
		end else begin
			if (write_en && rd_index != 0)
				registers[rd_index] <= rd;
			registers[0] <= 0;	// register 0 is always 0
		end
	
	assign rs1 = registers[rs1_index];
	assign rs2 = registers[rs2_index];
endmodule
