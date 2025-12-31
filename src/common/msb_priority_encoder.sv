module msb_priority_encoder #(parameter N=32) (
	input logic [N-1:0] in,
	output logic [$clog2(N)-1:0] out,
	output logic valid
);
	assign valid = |in;

	integer i;
	always_comb begin
		out = 0;	// default value to ensure combinational synthesis
		for (i = N-1; i >= 0; i = i - 1) begin
			if (in[i]) begin
				out = i[$clog2(N)-1:0];
				break;
			end
		end
	end
endmodule
