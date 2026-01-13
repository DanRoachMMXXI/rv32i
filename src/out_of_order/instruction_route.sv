module instruction_route #(parameter XLEN=32, parameter N_ALU_RS, parameter N_AGU_RS, parameter N_BRANCH_RS) (
	input logic [1:0]		instruction_type,

	input logic [N_ALU_RS-1:0]	alu_rs_busy,
	input logic [N_AGU_RS-1:0]	agu_rs_busy,
	input logic [N_BRANCH_RS-1:0]	branch_rs_busy,

	output logic [N_ALU_RS-1:0]	alu_rs_route,
	output logic [N_AGU_RS-1:0]	agu_rs_route,
	output logic [N_BRANCH_RS-1:0]	branch_rs_route,

	output logic			stall
	);

	// using lsb fixed priority arbiters to route the instruction to the
	// available reservation station with the lowest index (lowest index
	// is an arbitrary choice I made)

	logic [N_ALU_RS-1:0] alu_rs_arbiter_out;
	logic [N_AGU_RS-1:0] agu_rs_arbiter_out;
	logic [N_BRANCH_RS-1:0] branch_rs_arbiter_out;

	generate
		if (N_ALU_RS > 1) begin
			lsb_fixed_priority_arbiter #(.N(N_ALU_RS)) alu_rs_arbiter (
				.in(~alu_rs_busy),
				.out(alu_rs_arbiter_out)
			);
		end else begin
			assign alu_rs_arbiter_out = ~alu_rs_busy;
		end
	endgenerate

	generate
		if (N_AGU_RS > 1) begin
			lsb_fixed_priority_arbiter #(.N(N_AGU_RS)) agu_rs_arbiter (
				.in(~agu_rs_busy),
				.out(agu_rs_arbiter_out)
			);
		end else begin
			assign agu_rs_arbiter_out = ~agu_rs_busy;
		end
	endgenerate

	generate
		if (N_BRANCH_RS > 1) begin
			lsb_fixed_priority_arbiter #(.N(N_BRANCH_RS)) branch_rs_arbiter (
				.in(~branch_rs_busy),
				.out(branch_rs_arbiter_out)
			);
		end else begin
			assign branch_rs_arbiter_out = ~branch_rs_busy;
		end
	endgenerate

	assign alu_rs_route = alu_rs_arbiter_out & {N_ALU_RS{instruction_type == 'b00}};
	assign branch_rs_route = branch_rs_arbiter_out & {N_BRANCH_RS{instruction_type == 'b01}};
	assign agu_rs_route = agu_rs_arbiter_out & {N_AGU_RS{instruction_type[1]}};	// 'b10 or 'b11

	always_comb begin
		unique case (instruction_type)
			'b00:	// ALU
				stall = &alu_rs_busy;	// stall if all reservation stations are busy
			'b01:	// branch
				stall = &branch_rs_busy;	// stall if all reservation stations are busy
			'b10,	// load
			'b11:	// store
				stall = &agu_rs_busy;	// stall if all reservation stations are busy
		endcase
	end
endmodule
