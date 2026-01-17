// This is not an extensive register file test, this is simply testing the
// addition of the rob_tag and rob_tag_valid fields to the register file to
// support register renaming via reorder buffer tags.
module test_rf_rob_tags;
	localparam XLEN=32;
	localparam ROB_TAG_WIDTH=4;

	logic				clk;
	logic				reset;

	logic [4:0]			rs1_index;
	logic [4:0]			rs2_index;
	logic				rob_entry_alloc;
	logic [4:0]			rob_alloc_rd_index;
	logic [ROB_TAG_WIDTH-1:0]	rob_alloc_tag;
	logic [4:0]			rd_index;
	logic [XLEN-1:0]		rd;
	logic [ROB_TAG_WIDTH-1:0]	rd_rob_index;
	logic				write_en;
	logic [XLEN-1:0]		rs1;
	logic [ROB_TAG_WIDTH-1:0]	rs1_rob_tag;
	logic				rs1_rob_tag_valid;
	logic [XLEN-1:0]		rs2;
	logic [ROB_TAG_WIDTH-1:0]	rs2_rob_tag;
	logic				rs2_rob_tag_valid;

	register_file #(.XLEN(XLEN), .ROB_TAG_WIDTH(ROB_TAG_WIDTH)) rf (
		.clk(clk),
		.reset(reset),
		.rs1_index(rs1_index),
		.rs2_index(rs2_index),
		.rob_entry_alloc(rob_entry_alloc),
		.rob_alloc_rd_index(rob_alloc_rd_index),
		.rob_alloc_tag(rob_alloc_tag),
		.rd_index(rd_index),
		.rd(rd),
		.rd_rob_index(rd_rob_index),
		.write_en(write_en),
		.rs1(rs1),
		.rs1_rob_tag(rs1_rob_tag),
		.rs1_rob_tag_valid(rs1_rob_tag_valid),
		.rs2(rs2),
		.rs2_rob_tag(rs2_rob_tag),
		.rs2_rob_tag_valid(rs2_rob_tag_valid)
	);

	// disable the active low reset after the first clock cycle
	initial begin
		#10 reset = 1;
	end

	always begin
		#5 clk = ~clk;
	end

	initial begin	// test logic
		# 10	// wait for reset

		// put a ROB tag in x3
		rob_entry_alloc = 1;
		rob_alloc_rd_index = 3;
		rob_alloc_tag = 'hB;

		rs1_index = 3;	// instead of exposing the entire register set I'll just read the values from the read ports to validate
		# 10
		assert(rs1_rob_tag == 'hB);
		assert(rs1_rob_tag_valid == 1);

		rob_entry_alloc = 0;

		// now we'll commit an old instruction, so tag 'h9
		write_en = 1;
		rd_index = 3;
		rd_rob_index = 'h9;
		rd = 'h0123_4567;
		# 10
		assert(rs1 == 'h0123_4567);
		assert(rs1_rob_tag == 'hB);	// since an older instruction committed, we need to verify that the younger value still gets forwarded
		assert(rs1_rob_tag_valid == 1);

		write_en = 0;

		// now we'll commit the youngest instruction, which matches
		// what's stored in the register file 'hB
		rd_rob_index = 'hB;
		rd = 'h89AB_CDEF;
		# 10
		assert(rs1 == 'h89AB_CDEF);
		assert(rs1_rob_tag == 0);	// kinda irrelevant, but verifies reset happened
		assert(rs1_rob_tag_valid == 0);	// this is the money

		// now we need to verify that clear and write in the same
		// cycle produces the desired behavior: the allocated
		// instruction is reflected in the rob_tag, but the committed
		// value is what's stored in the register itself.

		// so we'll write a value to x5
		rob_entry_alloc = 1;
		rob_alloc_rd_index = 5;
		rob_alloc_tag = 'hF;
		// fuck it we'll read from rs2 for funsies
		rs2_index = 5;
		# 10
		assert(rs2_rob_tag == 'hF);
		assert(rs2_rob_tag_valid == 1);

		// so now we'll commit the instruction while also allocating
		// another (younger of course) ROB tag to x5
		write_en = 1;
		rd_index = 5;
		rd_rob_index = 'hF;
		rd = 'hAAAA_BBBB;

		rob_alloc_rd_index = 5;
		rob_alloc_tag = 'h2;
		# 10
		assert(rs2 == 'hAAAA_BBBB);
		assert(rs2_rob_tag == 'h2);
		assert(rs2_rob_tag_valid == 1);

		$display("All assertions passed.");
		$finish();
	end
endmodule
