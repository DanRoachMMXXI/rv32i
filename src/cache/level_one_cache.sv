// This cache is assuming that the memory request is aligned to the XLEN boundary
// It's counting on the LSU to handle setting the byte_mask and aligning the data appropriately.
// For example, if XLEN=32 and the operation is a read/write to the most significant byte of the
// word (addr[1:0] = 2'b11), the LSU will set byte_mask to 'b1000 and ensure that the byte to be
// stored is moved into the most significant byte of the word provided to the data_in port.
module cache #(
	parameter XLEN=32,
	parameter CACHE_SIZE,	// in bytes
	parameter N_WAYS,
	parameter BLOCK_SIZE,	// in bytes
	parameter N_MSHR,	// number of Miss Status Holding Registers
	parameter FILL_BUFFER_SIZE
	) (
	input logic		clk,
	input logic		reset,

	// generic status signals for the current operation
	output logic		hit,
	output logic		miss,

	// interface with the LSU
	// control signals from LSU
	input logic			fire_memory_op,
	input logic			memory_op_type,
	input logic [XLEN-1:0]		address_in,
	input logic [XLEN-1:0]		data_in,
	input logic [(XLEN/8)-1:0]	byte_mask,
	output logic [XLEN-1:0]		data_out,

	// the actual data block retrieved from SRAM (cache_data_memory module)
	// this is either the hit data or the evicted data, depending on whether the access was
	// a hit or miss respectively
	output logic [BLOCK_SIZE-1:0][7:0]	cache_block_data_out,

	// interface to lower memory
	// outputs to lower memory (for misses and evictions)
	output logic [XLEN-1:0]			missed_block_address,
	output logic [XLEN-1:0]			evicted_address,
	output logic				write_evicted_data,
	// inputs from lower memory (fetched values)
	input logic				fetch_valid,
	input logic [XLEN-1:0]			fetched_block_address,
	input logic [BLOCK_SIZE-1:0][7:0]	fetched_block_data,

	// debug signals
	output logic [2:0]			cache_operation
	);
	localparam N_SETS = CACHE_SIZE / (BLOCK_SIZE * N_WAYS);

	localparam BLOCK_OFFSET_START = 0;
	localparam BLOCK_OFFSET_END = BLOCK_OFFSET_START + $clog2(BLOCK_SIZE) - 1;
	localparam SET_START = BLOCK_OFFSET_END + 1;
	localparam SET_END = SET_START + $clog2(N_SETS) - 1;
	localparam TAG_START = SET_END + 1;
	localparam TAG_END = XLEN - 1;

	// the data block to be written back into the cache
	logic [BLOCK_SIZE-1:0][7:0]	modified_cache_data_block;

	// signals from the metadata memory (cache_metadata_memory module)
	// these retrieve all the signals for each way, as they're used to examine the state of the
	// entire set.
	logic [N_WAYS-1:0]				cache_set_valid;
	logic [N_WAYS-1:0]				cache_set_dirty;
	logic [N_WAYS-1:0][TAG_END:TAG_START]		cache_set_tags;

	// logic [2:0]					cache_operation;

	logic [$clog2(N_WAYS)-1:0]			evicted_way_index;

	logic [N_MSHR-1:0]				mshr_valid;
	logic [N_MSHR-1:0]				mshr_op_type;
	logic [N_MSHR-1:0][XLEN-1:0]			mshr_address;
	logic [N_MSHR-1:0][XLEN-1:0]			mshr_data;
	logic [N_MSHR-1:0][(XLEN/8)-1:0]		mshr_byte_mask;
	logic [N_MSHR-1:0][$clog2(N_WAYS)-1:0]		mshr_evicted_way_index;

	logic [TAG_END:TAG_START]			tag;
	logic [SET_END:SET_START]			set_index;
	logic [BLOCK_OFFSET_END:BLOCK_OFFSET_START]	block_offset;

	// fill buffer outputs
	logic [$clog2(FILL_BUFFER_SIZE):0]			fill_buffer_head;
	logic [$clog2(FILL_BUFFER_SIZE):0]			fill_buffer_tail;
	logic [FILL_BUFFER_SIZE-1:0]				fill_buffer_valid;
	logic [FILL_BUFFER_SIZE-1:0][XLEN-1:0]			fill_buffer_block_address;
	logic [FILL_BUFFER_SIZE-1:0][BLOCK_SIZE-1:0][7:0]	fill_buffer_block_data;
	logic							fill_buffer_full;
	logic							fill_buffer_empty;

	// routed signals from input or fill buffer
	logic [TAG_END:TAG_START]			routed_tag;
	logic [$clog2(N_SETS)-1:0]			routed_set_index;
	logic [$clog2(N_WAYS)-1:0]			routed_way_index;
	logic						routed_op_type;
	logic [XLEN-1:0]				routed_data;
	logic [(XLEN/8)-1:0]				routed_byte_mask;
	logic [BLOCK_SIZE-1:0][7:0]			routed_cache_data_block;
	logic [BLOCK_OFFSET_END:BLOCK_OFFSET_START]	routed_block_offset;

	logic [$clog2(N_MSHR)-1:0]			fill_mshr_index;

	// the index of the WAY in the set that hits
	logic [$clog2(N_WAYS)-1:0]			hit_way_index;

	logic	fill;

	// assign hit = (cache_operation[1:0] == 2'b11);
	assign miss = (cache_operation[1:0] == 2'b10);
	assign fill = (cache_operation[1:0] == 2'b01);

	assign tag = address_in[TAG_END:TAG_START];
	assign set_index = address_in[SET_END:SET_START];
	assign block_offset = address_in[BLOCK_OFFSET_END:BLOCK_OFFSET_START];

	cache_metadata_memory #(.N_SETS(N_SETS), .N_WAYS(N_WAYS), .TAG_END(TAG_END), .TAG_START(TAG_START)) metadata_memory (
		.clk(clk),
		.reset(reset),

		.set_index_in(set_index),

		.write_en(cache_operation[0]),	// update metadata on a hit or a fill

		.routed_set_index(routed_set_index),
		.routed_way_index(routed_way_index),

		.routed_op_type(routed_op_type),
		.routed_tag(routed_tag),

		.valid_out(cache_set_valid),
		.dirty_out(cache_set_dirty),
		.tags_out(cache_set_tags)
	);

	hit_detection #(.N_WAYS(N_WAYS), .TAG_START(TAG_START), .TAG_END(TAG_END)) hit_detection (
		.tag_in(tag),
		.cache_set_valid(cache_set_valid),
		.cache_set_tags(cache_set_tags),

		.hit(hit),
		.hit_way_index(hit_way_index)
	);

	cache_control cache_control (
		.fire_memory_op(fire_memory_op),
		.memory_op_type(memory_op_type),
	
		.hit(hit),

		.fill_buffer_empty(fill_buffer_empty),
		.fill_mshr_op_type(mshr_op_type[fill_mshr_index]),

		.cache_operation(cache_operation)
	);

	lru_eviction #(.N_SETS(N_SETS), .N_WAYS(N_WAYS)) lru_eviction (
		.clk(clk),
		.reset(reset),

		.cache_operation(cache_operation),

		.set_index(set_index),
		.way_index(routed_way_index),

		.evicted_way_index(evicted_way_index)
	);

	cache_data_memory #(.N_SETS(N_SETS), .N_WAYS(N_WAYS), .BLOCK_SIZE(BLOCK_SIZE)) data_memory (
		.clk(clk),
		.write_en((cache_operation[2] || !cache_operation[1]) && cache_operation[0]),	// (hit && op == write) || fill

		.set_index(routed_set_index),
		.way_index(routed_way_index),
		.block_data_in(modified_cache_data_block),

		.block_data_out(cache_block_data_out)
	);

	mshr #(.XLEN(XLEN), .N_MSHR(N_MSHR), .N_WAYS(N_WAYS)) mshr (
		.clk(clk),
		.reset(reset),

		.memory_op_type_in(memory_op_type),
		.address_in(address_in),
		.data_in(data_in),
		.byte_mask_in(byte_mask),
		.evicted_way_index_in(evicted_way_index),

		.miss(miss),
		
		.clear_entry(fill),
		.clear_entry_index(fill_mshr_index),

		.mshr_valid(mshr_valid),
		.mshr_op_type(mshr_op_type),
		.mshr_address(mshr_address),
		.mshr_data(mshr_data),
		.mshr_byte_mask(mshr_byte_mask),
		.mshr_evicted_way_index(mshr_evicted_way_index)
	);

	fill_buffer #(.XLEN(XLEN), .BUF_SIZE(FILL_BUFFER_SIZE), .BLOCK_SIZE(BLOCK_SIZE)) fill_buffer (
		.clk(clk),
		.reset(reset),

		.fetch_valid(fetch_valid),
		.fetched_block_address(fetched_block_address),
		.fetched_block_data(fetched_block_data),

		.fill(fill),

		.head(fill_buffer_head),
		.tail(fill_buffer_tail),

		.buf_valid(fill_buffer_valid),
		.buf_block_address(fill_buffer_block_address),
		.buf_block_data(fill_buffer_block_data),

		.full(fill_buffer_full),
		.empty(fill_buffer_empty)
	);

	cache_routing #(.XLEN(XLEN), .BLOCK_SIZE(BLOCK_SIZE), .N_WAYS(N_WAYS), .N_SETS(N_SETS), .N_MSHR(N_MSHR),
		.TAG_START(TAG_START), .TAG_END(TAG_END), .SET_START(SET_START), .SET_END(SET_END),
		.BLOCK_OFFSET_START(BLOCK_OFFSET_START), .BLOCK_OFFSET_END(BLOCK_OFFSET_END)) routing (
		.cache_operation(cache_operation),

		.memory_op_type_in(memory_op_type),
		.address_in(address_in),
		.data_in(data_in),
		.byte_mask_in(byte_mask),
		.hit_way_index(hit_way_index),
		.evicted_way_index(evicted_way_index),
		.cache_block_data_out(cache_block_data_out),

		.fill_buffer_head_block_address(fill_buffer_block_address[fill_buffer_head]),
		.fill_buffer_head_block_data(fill_buffer_block_data[fill_buffer_head]),

		.mshr_valid(mshr_valid),
		.mshr_op_type(mshr_op_type),
		.mshr_address(mshr_address),
		.mshr_data(mshr_data),
		.mshr_byte_mask(mshr_byte_mask),
		.mshr_evicted_way_index(mshr_evicted_way_index),

		.fill_mshr_index(fill_mshr_index),

		.routed_tag(routed_tag),
		.routed_set_index(routed_set_index),
		.routed_block_offset(routed_block_offset),
		.routed_way_index(routed_way_index),
		.routed_op_type(routed_op_type),
		.routed_data(routed_data),
		.routed_byte_mask(routed_byte_mask),
		.routed_cache_data_block(routed_cache_data_block)
	);

	block_write #(.XLEN(XLEN), .BLOCK_SIZE(BLOCK_SIZE)) block_write (
		.routed_data(routed_data),
		.routed_cache_data_block(routed_cache_data_block),
		.routed_block_offset(routed_block_offset),
		.routed_byte_mask(routed_byte_mask),
		.modified_cache_data_block(modified_cache_data_block)
	);

	assign missed_block_address[TAG_END:TAG_START] = tag;
	assign missed_block_address[SET_END:SET_START] = set_index;
	assign missed_block_address[BLOCK_OFFSET_END:BLOCK_OFFSET_START] = 0;

	// // construct the address of the evicted block
	assign evicted_address[TAG_END:TAG_START] = cache_set_tags[evicted_way_index];
	assign evicted_address[SET_END:SET_START] = set_index;
	assign evicted_address[BLOCK_OFFSET_END:BLOCK_OFFSET_START] = 0;

	assign write_evicted_data = miss && cache_set_valid[evicted_way_index] && cache_set_dirty[evicted_way_index];

	// TODO
	// miss behavior:
	// - ChatGPT mentioned merging outstanding miss requests that already occupy a MSHR with new
	// ones.  Also mentions stalling and replaying dependent pipeline operations, but I'm unsure
	// if this is relevant to my OOO design.

	// Assuming the LSU handles the realignment and merges misaligned results
	// always_comb begin
	// 	// write each byte to data_out
	// 	// probably don't need to worry about whether it's a hit or not, because anything
	// 	// that cares should be checking the hit boolean output
	// 	for (int i = 0; i < XLEN/8; i = i + 1) begin
	// 		data_out[(8*i+7):(8*i)] = cache_block_data_out[block_offset + i[BLOCK_OFFSET_END:BLOCK_OFFSET_START]] & {8{byte_mask[i]}};
	// 	end
	// end
endmodule
