module register_file_tb ();
	logic clk;
	logic reset;

	logic [4:0] rs1_index;
	logic [4:0] rs2_index;
	logic [4:0] rd_index;

	logic [31:0] rd;
	logic write_en;

	logic [31:0] rs1;
	logic [31:0] rs2;

	register_file rf(
		.clk(clk),
		.reset(reset),
		.rs1_index(rs1_index),
		.rs2_index(rs2_index),
		.rd_index(rd_index),
		.rd(rd),
		.write_en(write_en),
		.rs1(rs1),
		.rs2(rs2));

	always #10 clk <= ~clk;

	initial begin
		rs1_index = 'b0;
		rs2_index = 'b0;

		// reset the register file
		#10 reset = 0;
		#40 reset = 1;
		
		rd = 'b1;
		rd_index = 00001;
		write_en = 1;

		#20 rd = 'b10101010101010101010101010101010;
		rd_index = 00010;

		#20 write_en = 0;

		rs1_index = 00001;
		rs2_index = 00010;

		#20 $display("rs1: 0x%0h", rs1);
		#20 $display("rs2: 0x%0h", rs2);
	end
endmodule
