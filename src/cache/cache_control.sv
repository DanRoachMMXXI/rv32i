`define	NOP	3'b000
`define	FILL	2'b01
`define	MISS	2'b10
`define	HIT	2'b11

module cache_control (
	input logic	fire_memory_op,
	input logic	memory_op_type,

	input logic	hit,	// from hit detection module

	input logic	fill_buffer_empty,
	// TODO: inputs from fill buffer and MSHR to figure out the fill operation

	input logic	fill_mshr_op_type,	// mshr_op_type[fill_mshr_index]

	// 3-bit encoded value
	// The two LSBs [1:0] encode hit/miss/fill/nop
	// - 'b00: nop
	// - 'b01: fill
	// - 'b10: miss
	// - 'b11: hit
	// encoding picked such that all 0s means nop, [0] == 0 means no access, [1]
	// = fire_memory_op, indicating whether or not an incoming request is being served
	// the MSB (bit index [2]) indicates whether the operation encoded by [1:0] is a read or
	// write
	// - 'b0: read
	// - 'b1: write
	output logic [2:0]	cache_operation
);
	always_comb begin
		if (!fire_memory_op && fill_buffer_empty) begin
			cache_operation[2:0] = `NOP;
		end else if (!fire_memory_op && !fill_buffer_empty) begin
			cache_operation[2] = fill_mshr_op_type;
			cache_operation[1:0] = `FILL;
		end else if (fire_memory_op && !hit) begin
			cache_operation[2] = memory_op_type;
			cache_operation[1:0] = `MISS;
		end else if (fire_memory_op && hit) begin
			cache_operation[2] = memory_op_type;
			cache_operation[1:0] = `HIT;
		end else begin	// invalid
			cache_operation[2:0] = `NOP;
		end
	end
endmodule
