module hit_detection #(
	parameter N_WAYS,
	parameter TAG_START,
	parameter TAG_END
) (
	input logic [TAG_END:TAG_START]			tag_in,

	input logic [N_WAYS-1:0]			cache_set_valid,
	input logic [N_WAYS-1:0][TAG_END:TAG_START]	cache_set_tags,

	output logic					hit,
	output logic [$clog2(N_WAYS)-1:0]		hit_way_index
);
	always_comb begin
		hit = 0;
		hit_way_index = 0;

		for (int i = 0; i < N_WAYS; i = i + 1) begin
			if (cache_set_valid[i] && (cache_set_tags[i] == tag_in)) begin
				hit = 1;
				hit_way_index = i[$clog2(N_WAYS)-1:0];
				break;
			end
		end
	end
endmodule
