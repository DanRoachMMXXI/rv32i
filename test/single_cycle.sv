module test_single_cycle;
	logic clk = 0;
	logic reset = 0;	// active low reset

	logic [31:0] pc;
	logic [31:0] instruction;
	logic [31:0] rd;
	logic rf_write_en;
	logic mem_write_en;


	single_cycle #(.XLEN(32), .PROGRAM("test/programs/simple-sum/simple-sum.vh")) cpu (
		.clk(clk),
		.reset(reset),
		.pc(pc),
		.instruction(instruction),
		.rd(rd),
		.rf_write_en(rf_write_en),
		.mem_write_en(mem_write_en)
		);

	initial begin
		#10 reset = 1;
	end

	always begin
		#5 clk = ~clk;
	end

	initial begin
		// test logic
		for (int i = 0; i < 20; i = i + 1) begin
			#10
			$display("i = %d", i);

			$display("pc = 0x%0h", pc);
			$display("instruction = 0x%0h", instruction);

			$display("rd = %d", rd);
			$display("rd = 0x%0h", rd);

			$display("rf_write_en = %d", rf_write_en);
			$display("mem_write_en = %d", mem_write_en);

			$display("");
		end
		$finish(0);
	end
endmodule
