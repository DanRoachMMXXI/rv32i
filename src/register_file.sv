module register_file
	#(parameter WIDTH=32) (
	input logic clk,
	input logic clr,	// positive anynchronous clear
	// TODO: base the widths of the _index variables on the WIDTH
	// parameter
	input logic [4:0] rs1_index,
	input logic [4:0] rs2_index,
	input logic [4:0] rd_index,
	input logic [WIDTH - 1:0] rd,
	input logic write_en,

	output logic [WIDTH - 1:0] rs1,
	output logic [WIDTH - 1:0] rs2);

	logic [WIDTH - 1:0][WIDTH - 1:0] registers;
	
	always @(posedge clk, posedge clr)
		if (clr) begin
			foreach (registers[i]) begin
				registers[i] <= 'b0;
				rs1 <= 'b0;
				rs2 <= 'b0;
			end
		end
		else begin
			rs1 <= registers[rs1_index];
			rs2 <= registers[rs2_index];
			if (write_en)
				registers[rd_index] <= rd;
		end
endmodule
