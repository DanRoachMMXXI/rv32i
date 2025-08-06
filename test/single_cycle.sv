module test_single_cycle;
	logic clk = 0;
	logic reset = 0;	// active low reset

	logic [31:0] instruction;

	logic [4:0] rs1_index;
	logic [4:0] rs2_index;
	logic [4:0] rd_index;

	logic [31:0] immediate;

	logic [31:0] rs1;
	logic [31:0] rs2;
	logic [31:0] rd;

	logic [1:0] alu_op1_src;
	logic alu_op2_src;
	logic [1:0] rd_select;

	logic branch;
	logic branch_if_zero;
	logic jump;
	logic branch_base;
	logic branch_predicted_taken;
	logic branch_mispredicted;

	logic rf_write_en;
	logic mem_write_en;

	logic [31:0] alu_op1;
	logic [31:0] alu_op2;
	logic [2:0] alu_operation;
	logic alu_sign;
	logic [31:0] alu_result;
	logic alu_zero;

	logic [31:0] memory_data_out;

	logic [31:0] pc;
	logic [31:0] pc_plus_four;
	logic [31:0] branch_target;
	logic [31:0] evaluated_next_instruction;
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
		.immediate(immediate),
		.alu_op1_src(alu_op1_src),
		.alu_op2_src(alu_op2_src),
		.rd_select(rd_select),
		.branch(branch),
		.branch_if_zero(branch_if_zero),
		.jump(jump),
		.branch_base(branch_base),
		.branch_predicted_taken(branch_predicted_taken),
		.branch_mispredicted(branch_mispredicted),
		.rf_write_en(rf_write_en),
		.mem_write_en(mem_write_en),
		.alu_op1(alu_op1),
		.alu_op2(alu_op2),
		.alu_operation(alu_operation),
		.alu_sign(alu_sign),
		.alu_result(alu_result),
		.alu_zero(alu_zero),
		.memory_data_out(memory_data_out),
		.pc(pc),
		.pc_plus_four(pc_plus_four),
		.branch_target(branch_target),
		.evaluated_next_instruction(evaluated_next_instruction),
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

			$display("immediate = 0x%0h", immediate);

			$display("alu_op1_src = %d", alu_op1_src);
			$display("alu_op2_src = %d", alu_op2_src);
			$display("rd_select = %d", rd_select);

			$display("branch = 0x%0h", branch);
			$display("branch_if_zero = 0x%0h", branch_if_zero);
			$display("jump = 0x%0h", jump);
			$display("branch_predicted_taken = 0x%0h", branch_predicted_taken);
			$display("branch_mispredicted = 0x%0h", branch_mispredicted);	// useless for single cycle

			$display("rf_write_en = %d", rf_write_en);
			$display("mem_write_en = %d", mem_write_en);

			$display("alu_op1 = 0x%0h", alu_op1);
			$display("alu_op2 = 0x%0h", alu_op2);
			$display("alu_operation = 0x%0h", alu_operation);
			$display("alu_sign = 0x%0h", alu_sign);
			$display("alu_result = 0x%0h", alu_result);
			$display("alu_zero = 0x%0h", alu_zero);

			$display("pc = 0x%0h", pc);
			$display("pc_plus_four = 0x%0h", pc_plus_four);
			$display("branch_target = 0x%0h", branch_target);
			$display("evaluated_next_instruction = 0x%0h", evaluated_next_instruction);
			$display("pc_next = 0x%0h", pc_next);

			$display("memory_data_out = %d", memory_data_out);

			$display("rs1 = %d", rs1);
			$display("rs2 = %d", rs2);
			$display("rd = %d", rd);
			$display("rd = 0x%0h", rd);
			$display("");
		end
		$finish(0);
	end
endmodule
