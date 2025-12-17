/*
 * module to compare the "age" (distance from head) of two circular buffer
 * pointers.
 * result = 0 if a is older than b (a is closer to head than b)
 * result = 1 if a is younger than b (a is further from head than b)
 */
module age_comparator #(parameter N=32) (
	input logic [N-1:0] head,
	input logic [N-1:0] a,
	input logic [N-1:0] b,
	output logic result
	);

	logic [N-1:0] diff_a;
	logic [N-1:0] diff_b;

	assign diff_a = a - head;
	assign diff_b = b - head;

	assign result = diff_a < diff_b;
endmodule
