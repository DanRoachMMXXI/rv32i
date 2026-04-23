// TODO: improve on the following or accept it as is
// ugh
// I've needed to make this memory dual port (one read and one write) as revealed by a circular
// combinational circuit.  I need to read the tags to evaluate if it's a hit, that determines
// cache_operation, which routes the data back to the metadata_memory to be written.
module cache_metadata_memory #(
	parameter N_SETS,
	parameter N_WAYS,
	parameter TAG_END,
	parameter TAG_START
) (
	input logic	clk,
	input logic	reset,

	// combinational read index
	input logic [$clog2(N_SETS)-1:0]		set_index_in,

	input logic	write_en,

	// sequential write indices
	// maybe irrelevant but unsure if I want to use [SET_END:SET_START] or [$clog2(N_SETS)-1:0]
	input logic [$clog2(N_SETS)-1:0]		routed_set_index,
	input logic [$clog2(N_WAYS)-1:0]		routed_way_index,

	input logic					routed_op_type,
	input logic [TAG_END:TAG_START]			routed_tag,

	output logic [N_WAYS-1:0]			valid_out,
	output logic [N_WAYS-1:0]			dirty_out,
	output logic [N_WAYS-1:0][TAG_END:TAG_START]	tags_out
);
	reg [N_SETS-1:0][N_WAYS-1:0]			cache_valid;
	reg [N_SETS-1:0][N_WAYS-1:0]			cache_dirty;
	reg [N_SETS-1:0][N_WAYS-1:0][TAG_END:TAG_START]	cache_tags;

	always_ff @(posedge clk) begin
		if (!reset) begin
			cache_valid <= 0;
		end else if (write_en) begin
			cache_valid[routed_set_index][routed_way_index] <= 1'b1;
			// dirty needs to stay dirty even if it's accessed with just a read operation
			cache_dirty[routed_set_index][routed_way_index] <=
				cache_dirty[routed_set_index][routed_way_index] | routed_op_type;
			cache_tags[routed_set_index][routed_way_index] <= routed_tag;
		end
	end

	assign valid_out = cache_valid[set_index_in];
	assign dirty_out = cache_dirty[set_index_in];
	assign tags_out = cache_tags[set_index_in];
endmodule
