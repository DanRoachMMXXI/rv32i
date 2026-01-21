module test_operand_route;
	localparam XLEN=32;
	localparam ROB_SIZE=16;
	localparam ROB_TAG_WIDTH=4;


	logic [6:0]			opcode;
	logic [XLEN-1:0]		rs1;
	logic [ROB_TAG_WIDTH-1:0]	rs1_rob_tag;
	logic				rs1_rob_tag_valid;
	logic [XLEN-1:0]		rs2;
	logic [ROB_TAG_WIDTH-1:0]	rs2_rob_tag;
	logic				rs2_rob_tag_valid;
	logic [XLEN-1:0]		pc;
	logic [XLEN-1:0]		immediate;
	logic [ROB_SIZE-1:0][XLEN-1:0]	rob_value;
	logic [ROB_SIZE-1:0]		rob_data_ready;
	logic				q1_valid;
	logic [ROB_TAG_WIDTH-1:0]	q1;
	logic [XLEN-1:0]		v1;
	logic				q2_valid;
	logic [ROB_TAG_WIDTH-1:0]	q2;
	logic [XLEN-1:0]		v2;

	operand_route #(.XLEN(XLEN), .ROB_SIZE(ROB_SIZE), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) operand_route (
		.opcode(opcode),
		.rs1(rs1),
		.rs1_rob_tag(rs1_rob_tag),
		.rs1_rob_tag_valid(rs1_rob_tag_valid),
		.rs2(rs2),
		.rs2_rob_tag(rs2_rob_tag),
		.rs2_rob_tag_valid(rs2_rob_tag_valid),
		.pc(pc),
		.immediate(immediate),
		.rob_value(rob_value),
		.rob_data_ready(rob_data_ready),
		.q1_valid(q1_valid),
		.q1(q1),
		.v1(v1),
		.q2_valid(q2_valid),
		.q2(q2),
		.v2(v2)
	);

	initial begin
		// assign some specific values to pc and the immediate value
		// to easily verify when they're routed correctly
		pc = 'hCAFE_CAFE;
		immediate = DEAD_BEEF;

		// TODO: finish, stopping for now to iron out branch FU and
		// operands
	end
endmodule
