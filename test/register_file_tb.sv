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
		rd_index = 1;
		write_en = 1;

		#20 rd = 'hAAAAAAAA;
		rd_index = 2;

		#20 write_en = 0;

		rs1_index = 1;
		rs2_index = 2;

		#20 $display("rs1: expected %0d, actual %0d", 1, rs1);
		#20 $display("rs2: expected %0d, actual %0d", 'hAAAAAAAA, rs2);

		$finish(0);
	end
endmodule
