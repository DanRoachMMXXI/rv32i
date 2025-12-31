// MSB and LSB priority arbiters taken from
// https://www.edaplayground.com/x/k75i

module msb_fixed_priority_arbiter #(parameter N=32) (
	input logic [N-1:0]	in,
	output logic [N-1:0]	out
);
	logic [N-1:0] mask;
	assign mask[N-1] = 1'b0;
	assign mask[N-2:0] = mask[N-1:1] | in[N-1:1];
	assign out = in & ~mask;
endmodule

module lsb_fixed_priority_arbiter #(parameter N=32) (
	input logic [N-1:0]	in,
	output logic [N-1:0]	out
);
	logic [N-1:0] mask;
	assign mask[0] = 1'b0;
	assign mask[N-1:1] = mask[N-2:0] | in[N-2:0];
	assign out = in & ~mask;
endmodule
