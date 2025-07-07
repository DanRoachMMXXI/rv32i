module register_file
	#(parameter XLEN=32, ADDR_WIDTH=5) (
	input logic clk,
	input logic reset,
	input logic [ADDR_WIDTH-1:0] rs1_index,
	input logic [ADDR_WIDTH-1:0] rs2_index,
	input logic [ADDR_WIDTH-1:0] rd_index,
	input logic [XLEN-1:0] rd,
	input logic write_en,

	output logic [XLEN-1:0] rs1,
	output logic [XLEN-1:0] rs2);

	reg [XLEN-1:0] registers [0:((2**ADDR_WIDTH)-1)];
	integer i;
	
	always @(posedge clk)
		if (!reset) begin
			for (i = 0; i < ((2**ADDR_WIDTH)-1); i = i + 1) begin
				registers[i] <= 0;
			end
		end else begin
			if (write_en)
				registers[rd_index] <= rd;
			// TODO add else reg[rd_ind] <= rd if no work
			// but that seems pointless
			registers[0] <= 0;	// register 0 is always 0
		end
	
	assign rs1 = registers[rs1_index];
	assign rs2 = registers[rs2_index];
endmodule
