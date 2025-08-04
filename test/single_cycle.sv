module test_single_cycle;
	logic clk = 0;
	logic reset = 0;	// active low reset

	logic [31:0] instruction;

	logic [4:0] rs1_index;
	logic [4:0] rs2_index;
	logic [4:0] rd_index;

	logic [31:0] rs1;
	logic [31:0] rs2;
	logic [31:0] rd;

	logic [31:0] pc;
	logic [31:0] pc_plus_four;
	logic [31:0] branch_target;
	logic [31:0] evaluated_branch_result;
	logic [31:0] pc_next;

	single_cycle #(.XLEN(32), .PROGRAM("test/programs/simple-sum/simple-sum.vh")) cpu (
		.clk(clk),
		.reset(reset),
		.instruction(instruction),
		.rs1_index(rs1_index),
		.rs2_index(rs2_index),
		.rd_index(rd_index),
		.rs1(rs1),
		.rs2(rs2),
		.rd(rd),
		.pc(pc),
		.pc_plus_four(pc_plus_four),
		.branch_target(branch_target),
		.evaluated_branch_result(evaluated_branch_result),
		.pc_next(pc_next)
		);

	initial begin
		#10 reset = 1;
	end

	always begin
		#5 clk = ~clk;
	end

	integer i;

	initial begin
		// test logic
		for (i = 0; i < 20; i = i + 1) begin
			#10
			$display("i = %d", i);

			$display("pc = 0x%0h", pc);
			$display("instruction = 0x%0h", instruction);

			$display("rs1_index = %d", rs1_index);
			$display("rs2_index = %d", rs2_index);
			$display("rd_index = %d", rd_index);

			$display("rs1 = %d", rs1);
			$display("rs2 = %d", rs2);
			$display("rd = %d", rd);
			$display("");
		end
		$finish(0);
	end
endmodule
