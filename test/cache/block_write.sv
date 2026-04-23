module test_block_write;

	localparam XLEN=32;
	localparam BLOCK_SIZE=8;

	logic [XLEN-1:0]		routed_data;
	logic [BLOCK_SIZE-1:0][7:0]	routed_cache_data_block;
	logic [$clog2(BLOCK_SIZE)-1:0]	routed_block_offset;
	logic [(XLEN/8)-1:0]		routed_byte_mask;
	logic [BLOCK_SIZE-1:0][7:0]	modified_cache_data_block;

	block_write #(.XLEN(XLEN), .BLOCK_SIZE(BLOCK_SIZE)) block_write (
		.routed_data(routed_data),
		.routed_cache_data_block(routed_cache_data_block),
		.routed_block_offset(routed_block_offset),
		.routed_byte_mask(routed_byte_mask),
		.modified_cache_data_block(modified_cache_data_block)
	);

	initial begin
		routed_data = 'h44444444;
		routed_cache_data_block = 'h0123456789ABCDEF;
		routed_block_offset = 0;
		routed_byte_mask = 4'b0011;
		# 10
		assert(modified_cache_data_block == 'h0123456789AB4444);

		routed_byte_mask = 4'b1111;
		# 10
		assert(modified_cache_data_block == 'h0123456744444444);

		routed_block_offset = 6;
		routed_byte_mask = 4'b0011;
		# 10
		assert(modified_cache_data_block == 'h4444456789ABCDEF);

		$display("All assertions passed.");
		$finish();
	end
endmodule
