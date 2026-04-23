// TODO
// rethink the tracking of evicted entries and using that to select the next entry to evict
// the current design has an edge case where all entries can be evicted and it won't do anything if
// another miss occurs and tries to evict a way.
// also, the current design won't choose a "recently used" but not evicted entry if all the other
// "not recently used" entries have been evicted.  I think it will just choose way 0, which may be
// evicted.  so it's gotta be some sort of priority thing.  if all "not recently used" entries are
// evicted, evict a recently used entry.
module lru_eviction #(
	parameter N_SETS,
	parameter N_WAYS
) (
	input logic				clk,
	input logic				reset,

	// input logic				hit,
	// input logic				miss,
	// input logic				fill,
	input logic [2:0]			cache_operation,

	input logic [$clog2(N_SETS)-1:0]	set_index,
	input logic [$clog2(N_WAYS)-1:0]	way_index,	// hit_index || mshr_evicted_way_index[fill_mshr_index]
								// unused on miss, we decide which
								// way to evict in this module if
								// miss is set

	output logic [$clog2(N_WAYS)-1:0]	evicted_way_index
);
	reg [N_SETS-1:0][N_WAYS-1:0]	cache_pseudo_lru;
	reg [N_SETS-1:0][N_WAYS-1:0]	cache_evicted;	// metadata bits tracking whether each cache block has already been evicted

	// if hit or filling with new data, this has a 1 in the index of the way that hit or was
	// filled, otherwise it's just 0, and the cache_pseudo_lru entry goes unchanged
	// cache_operation is encoded such that [0] = 1'b1 if and only if it's a hit or a fill
	logic [N_WAYS-1:0] plru_bitmask;
	assign plru_bitmask = N_WAYS'(cache_operation[0]) << way_index;

	logic [N_WAYS-1:0]	next_plru;
	// pseudo LRU replacement logic for each set
	always_comb begin
		// generate the next pseudo_lru value
		// following the Pseudo LRU algorithm described in Appendix B of the
		// Hennessy and Patterson book.
		next_plru = (&(cache_pseudo_lru[set_index] | plru_bitmask))	// If all bits will be set
			? plru_bitmask						// Clear all bits and only set the most recent access
			: (cache_pseudo_lru[set_index] | plru_bitmask);		// Else set the most recent access and leave the others unchanged
	end

	// synchronous write of the next pseudo_lru value
	always_ff @(posedge clk) begin
		// for (int i = 0; i < N_SETS; i = i + 1) begin
		if (!reset) begin
			// cache_pseudo_lru[i] <= 0;
			cache_pseudo_lru <= 0;
		end else begin
			cache_pseudo_lru[set_index] <= next_plru;
		end
		// end
	end

	// select an eligible way to evict
	logic [N_WAYS-1:0]	eligible_to_evict;
	assign eligible_to_evict = ~cache_pseudo_lru[set_index] & ~cache_evicted[set_index];
	// in english: it's eligible to evict if it's not recently used and not already evicted

	lsb_priority_encoder #(.N(N_WAYS)) evict_index_encoder (
		.in(eligible_to_evict),
		.out(evicted_way_index),
		.valid()	// TODO: maybe use this, identifies edge case where all entries in the way are evicted
	);

	// register/memory to track which ways have been evicted
	always_ff @(posedge clk) begin
		if (!reset) begin
			cache_evicted <= 0;
		end else begin
			if (cache_operation[1:0] == 2'b10)	// miss
				cache_evicted[set_index][evicted_way_index] <= 1'b1;
			else if (cache_operation[1:0] == 2'b01)	// fill
				cache_evicted[set_index][way_index] <= 1'b0;
		end
	end
endmodule
