module rob_age_comparator_no_phase_bit #(parameter ROB_TAG_WIDTH) (
	input logic [ROB_TAG_WIDTH-1:0]	rob_head,
	input logic [ROB_TAG_WIDTH-1:0]	a,
	input logic [ROB_TAG_WIDTH-1:0]	b,
	// result: 0 if a is older than b, 1 if a is younger than b
	// it happens to be that if a == b, result is 0, but this condition
	// shouldn't be seen in the practical use cases of this module.
	output logic			result
);
	logic [ROB_TAG_WIDTH-1:0]	a_distance_to_head;
	logic [ROB_TAG_WIDTH-1:0]	b_distance_to_head;
	assign a_distance_to_head = a - rob_head;
	assign b_distance_to_head = b - rob_head;

	assign result = a_distance_to_head > b_distance_to_head;
endmodule

module rob_age_comparator_with_phase_bit #(parameter ROB_TAG_WIDTH) (
	// index [ROB_TAG_WIDTH] is the phase bit
	input logic [ROB_TAG_WIDTH:0]	a,
	input logic [ROB_TAG_WIDTH:0]	b,

	// result: 0 if a is older than b, 1 if a is younger than b
	output logic result
);
	logic [ROB_TAG_WIDTH-1:0]	a_tag;
	logic [ROB_TAG_WIDTH-1:0]	b_tag;
	assign a_tag = a[ROB_TAG_WIDTH-1:0];
	assign b_tag = b[ROB_TAG_WIDTH-1:0];

	logic out_of_phase;
	assign out_of_phase = a[ROB_TAG_WIDTH] ^ b[ROB_TAG_WIDTH];

	assign result = (a_tag > b_tag) ^ out_of_phase;
endmodule
