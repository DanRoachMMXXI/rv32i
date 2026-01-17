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

module operand_route #(parameter XLEN=32, parameter ROB_SIZE=64, parameter ROB_TAG_WIDTH=6) (
	input logic [6:0]	opcode,

	input logic [4:0]	rs1_index,
	input logic [4:0]	rs2_index,

	// inputs from register file
	input logic [XLEN-1:0]			rs1,
	input logic [ROB_TAG_WIDTH-1:0]		rs1_rob_tag,
	input logic				rs1_rob_tag_valid,
	input logic [XLEN-1:0]			rs2,
	input logic [ROB_TAG_WIDTH-1:0]		rs2_rob_tag,
	input logic				rs2_rob_tag_valid,

	input logic [XLEN-1:0]			pc,
	input logic [XLEN-1:0]			immediate,

	// input logic [ROB_SIZE-1:0]		rob_valid,
	input logic [ROB_SIZE-1:0][XLEN-1:0]	rob_value,
	input logic [ROB_SIZE-1:0]		rob_data_ready,

	output logic				q1_valid,
	output logic [ROB_TAG_WIDTH-1:0]	q1,
	output logic [XLEN-1:0]			v1,
	output logic				q2_valid,
	output logic [ROB_TAG_WIDTH-1:0]	q2,
	output logic [XLEN-1:0]			v2
);

	// TODO: LUI and AUIPC are just going to be written stright to the ROB,
	// so don't route them (more importantly, don't ISSUE them to
	// a reservation station).

	// these are the values that will be routed if the value is retrieved
	// from the register file or reorder buffer
	logic				q1_valid_rs1;
	logic [ROB_TAG_WIDTH-1:0]	q1_rs1;
	logic [XLEN-1:0]		v1_rs1;

	logic				q2_valid_rs2;
	logic [ROB_TAG_WIDTH-1:0]	q2_rs2;
	logic [XLEN-1:0]		v2_rs2;

	// we need to monitor the CDB for a tag if the register file has a tag
	// and the ROB cannot yet forward the result
	assign q1_valid_rs1 = rs1_rob_tag_valid && !rob_data_ready[rs1_rob_tag];

	// if we need to use a tag, we simply also need to route the tag
	assign q1_rs1 = q1_valid_rs1 ? rs1_rob_tag : 0;

	// if we don't need to use a tag, we can just route the value
	assign v1_rs1 = (!rs1_rob_tag_valid) ? rs1
		: (rob_data_ready[rs1_rob_tag]) ? rob_value[rs1_rob_tag]
		: 0;

	// same logic as rs1 above for forwarding/tagging rs2
	assign q2_valid_rs2 = rs2_rob_tag_valid && !rob_data_ready[rs2_rob_tag];
	assign q2_rs2 = q2_valid_rs2 ? rs2_rob_tag : 0;
	assign v2_rs2 = (!rs2_rob_tag_valid) ? rs2
		: (rob_data_ready[rs2_rob_tag]) ? rob_value[rs2_rob_tag]
		: 0;

	// operand 1 routing
	always_comb begin
		unique case (opcode)
			'b0110111:	// LUI
			begin
				q1_valid = 0;
				q1 = 0;
				v1 = 0;	// this is the actual value
			end

			// For these instructions, the value of the program
			// counter is used as the first operand.
			'b1101111,	// JAL
			'b1100011,	// B_TYPE
			'b0010111:	// AUIPC
			begin
				q1_valid = 0;
				q1 = 0;
				v1 = pc;
			end


			'b0110011,	// R_TYPE
			'b0010011,	// I_TYPE_ALU
			'b0000011,	// I_TYPE_LOAD
			'b1100111,	// I_TYPE_JALR
			'b0100011:	// S_TYPE
			begin
				q1_valid = q1_valid_rs1;
				q1 = q1_rs1;
				v1 = v1_rs1;
			end

			'b0000000:	// inserted stall, will not be routed to anything
			begin
				q1_valid = 0;
				q1 = 0;
				v1 = 0;
			end
		endcase

	end

	always_comb begin
		unique case (opcode)
			// operand 2 comes from rs2 for these opcodes
			'b0110011,	// R_TYPE
			'b1100011:	// B_TYPE
			begin
				q2_valid = q2_valid_rs2;
				q2 = q2_rs2;
				v2 = v2_rs2;
			end

			// operand 2 comes from the immediate for these opcodes
			'b0010011,	// I_TYPE_ALU
			'b0000011,	// I_TYPE_LOAD
			'b1100111,	// I_TYPE_JALR
			'b0100011,	// S_TYPE
			'b1101111,	// JAL
			'b0110111,	// LUI
			'b0010111:	// AUIPC
			begin
				q2_valid = 0;
				q2 = 0;
				v2 = immediate;
			end

			'b0000000:	// inserted stall, will not be routed to anything
			begin
				q2_valid = 0;
				q2 = 0;
				v2 = 0;
			end
		endcase
	end
endmodule
