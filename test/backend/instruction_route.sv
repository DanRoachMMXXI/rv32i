module test_instruction_route;
	localparam XLEN = 32;
	localparam N_ALU_RS = 8;
	localparam N_AGU_RS = 4;
	localparam N_BRANCH_RS = 2;

	logic [1:0]		instruction_type;

	logic [N_ALU_RS-1:0]	alu_rs_busy;
	logic [N_AGU_RS-1:0]	agu_rs_busy;
	logic [N_BRANCH_RS-1:0]	branch_rs_busy;

	logic [N_ALU_RS-1:0]	alu_rs_route;
	logic [N_AGU_RS-1:0]	agu_rs_route;
	logic [N_BRANCH_RS-1:0]	branch_rs_route;

	logic			stall;

	instruction_route #(.XLEN(XLEN), .N_ALU_RS(N_ALU_RS), .N_AGU_RS(N_AGU_RS), .N_BRANCH_RS(N_BRANCH_RS)) route (
		.instruction_type(instruction_type),

		.alu_rs_busy(alu_rs_busy),
		.agu_rs_busy(agu_rs_busy),
		.branch_rs_busy(branch_rs_busy),

		.alu_rs_route(alu_rs_route),
		.agu_rs_route(agu_rs_route),
		.branch_rs_route(branch_rs_route),

		.stall(stall)
	);

	// test logic
	initial begin
		instruction_type = 'b00;	// ALU
		alu_rs_busy = {N_ALU_RS{1'b0}};
		agu_rs_busy = {N_AGU_RS{1'b0}};
		branch_rs_busy = {N_BRANCH_RS{1'b0}};
		# 10
		assert(alu_rs_route == {{N_ALU_RS{1'b0}}, 1'b1}[N_ALU_RS-1:0]);
		assert(agu_rs_route == {N_AGU_RS{1'b0}});
		assert(branch_rs_route == {N_BRANCH_RS{1'b0}});
		assert(stall == 0);

		alu_rs_busy = 8'b01101111;
		agu_rs_busy = 4'b0101;
		branch_rs_busy = 2'b10;
		instruction_type = 2'b00;
		# 10
		assert(alu_rs_route == 8'b00010000);
		assert(agu_rs_route == {N_AGU_RS{1'b0}});
		assert(branch_rs_route == {N_BRANCH_RS{1'b0}});
		assert(stall == 0);

		instruction_type = 'b01;	// branch
		# 10
		assert(alu_rs_route == {N_ALU_RS{1'b0}});
		assert(agu_rs_route == {N_AGU_RS{1'b0}});
		assert(branch_rs_route == 2'b01);
		assert(stall == 0);

		instruction_type = 'b10;	// load
		# 10
		assert(alu_rs_route == {N_ALU_RS{1'b0}});
		assert(agu_rs_route == 4'b0010);
		assert(branch_rs_route == {N_BRANCH_RS{1'b0}});
		assert(stall == 0);

		instruction_type = 'b11;	// store
		# 10
		assert(alu_rs_route == {N_ALU_RS{1'b0}});
		assert(agu_rs_route == 4'b0010);
		assert(branch_rs_route == {N_BRANCH_RS{1'b0}});
		assert(stall == 0);

		alu_rs_busy = {N_ALU_RS{1'b1}};
		instruction_type = 2'b00;
		# 10
		assert(alu_rs_route == {N_ALU_RS{1'b0}});
		assert(agu_rs_route == {N_AGU_RS{1'b0}});
		assert(branch_rs_route == {N_BRANCH_RS{1'b0}});
		assert(stall == 1);

		$display("All assertions passed.");
		$finish();
	end
endmodule
