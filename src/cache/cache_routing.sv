module cache_routing #(
	parameter XLEN=32,
	parameter BLOCK_SIZE,
	parameter N_SETS,
	parameter N_WAYS,
	parameter N_MSHR,

	// the below parameters are the indices in a given address for the cache
	// START indicates the LSB for that field, END indicates the MSB, both inclusive
	parameter TAG_START,
	parameter TAG_END,
	parameter SET_START,
	parameter SET_END,
	parameter BLOCK_OFFSET_START,
	parameter BLOCK_OFFSET_END
) (
	input logic [2:0]			cache_operation,

	input logic				memory_op_type_in,
	input logic [XLEN-1:0]			address_in,	// could do this as block_address_in
	input logic [XLEN-1:0]			data_in,
	input logic [(XLEN/8)-1:0]		byte_mask_in,
	input logic [$clog2(N_WAYS)-1:0]	hit_way_index,
	input logic [$clog2(N_WAYS)-1:0]	evicted_way_index,
	input logic [BLOCK_SIZE-1:0][7:0]	cache_block_data_out,

	input logic [XLEN-1:0]			fill_buffer_head_block_address,
	input logic [BLOCK_SIZE-1:0][7:0]	fill_buffer_head_block_data,

	input logic [N_MSHR-1:0]			mshr_valid,
	input logic [N_MSHR-1:0]			mshr_op_type,
	input logic [N_MSHR-1:0][XLEN-1:0]		mshr_address,
	input logic [N_MSHR-1:0][XLEN-1:0]		mshr_data,
	input logic [N_MSHR-1:0][(XLEN/8)-1:0]		mshr_byte_mask,
	input logic [N_MSHR-1:0][$clog2(N_WAYS)-1:0]	mshr_evicted_way_index,

	// need to output this to clear that MSHR
	output logic [$clog2(N_MSHR)-1:0]		fill_mshr_index,

	output logic [TAG_END:TAG_START]			routed_tag,
	output logic [$clog2(N_SETS)-1:0]			routed_set_index,
	output logic [BLOCK_OFFSET_END:BLOCK_OFFSET_START]	routed_block_offset,
	output logic [$clog2(N_WAYS)-1:0]			routed_way_index,
	output logic						routed_op_type,
	output logic [XLEN-1:0]					routed_data,
	output logic [(XLEN/8)-1:0]				routed_byte_mask,
	output logic [BLOCK_SIZE-1:0][7:0]			routed_cache_data_block
);

	// parallel search MSHR for fetched_block_address to find the evicted way index, data,
	// byte_mask, etc
	always_comb begin: MSHR_searching
		fill_mshr_index = 0;
		for (int i = 0; i < N_MSHR; i = i + 1) begin
			if (mshr_valid[i] && mshr_address[i][TAG_END:SET_START] == fill_buffer_head_block_address[TAG_END:SET_START]) begin
				fill_mshr_index = i[$clog2(N_MSHR)-1:0];
				break;
			end
		end
	end

	always_comb begin: routing
		// way index routing to the data memory
		// special because we route a different way for misses instead of hits
		case (cache_operation[1:0])
			2'b01:	// fill
				routed_way_index = mshr_evicted_way_index[fill_mshr_index];
			2'b10:	// miss
				routed_way_index = evicted_way_index;
			default:	// hit + nop
				routed_way_index = hit_way_index;
		endcase

		// all other routing
		case (cache_operation[1:0])
			2'b01: begin	// fill routing
				routed_tag = mshr_address[fill_mshr_index][TAG_END:TAG_START];
				routed_set_index = mshr_address[fill_mshr_index][SET_END:SET_START];
				routed_block_offset = mshr_address[fill_mshr_index][BLOCK_OFFSET_END:BLOCK_OFFSET_START];
				routed_op_type = mshr_op_type[fill_mshr_index];
				routed_data = mshr_data[fill_mshr_index];
				routed_byte_mask = mshr_byte_mask[fill_mshr_index];
				routed_cache_data_block = fill_buffer_head_block_data;
			end
			default: begin	// default routing from input
				routed_tag = address_in[TAG_END:TAG_START];
				routed_set_index = address_in[SET_END:SET_START];
				routed_block_offset = address_in[BLOCK_OFFSET_END:BLOCK_OFFSET_START];
				routed_op_type = memory_op_type_in;
				routed_data = data_in;
				routed_byte_mask = byte_mask_in;
				routed_cache_data_block = cache_block_data_out;
			end
		endcase
	end
endmodule
