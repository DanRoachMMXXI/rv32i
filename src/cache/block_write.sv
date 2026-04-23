module block_write #(
	parameter XLEN=32,
	parameter BLOCK_SIZE
) (
	input logic [(XLEN/8)-1:0][7:0]		routed_data,
	input logic [BLOCK_SIZE-1:0][7:0]	routed_cache_data_block,
	input logic [$clog2(BLOCK_SIZE)-1:0]	routed_block_offset,
	input logic [(XLEN/8)-1:0]		routed_byte_mask,
	output logic [BLOCK_SIZE-1:0][7:0]	modified_cache_data_block
);

	// TODO: examine synthesis of this pattern
	always_comb begin
		modified_cache_data_block = routed_cache_data_block;
		for (int i = 0; i < (XLEN/8); i = i + 1) begin
			if (routed_byte_mask[i]) begin
				// TODO: not a huge fan of the width cast, but just doing it for testing for now
				modified_cache_data_block[32'(routed_block_offset) + i] = routed_data[i];
			end
		end
	end
endmodule
