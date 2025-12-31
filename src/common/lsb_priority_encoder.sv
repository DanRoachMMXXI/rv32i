module lsb_priority_encoder #(parameter N=32) (
	input logic [N-1:0] in,
	output logic [$clog2(N)-1:0] out,
	output logic valid
);
	assign valid = |in;

	integer i;
	always_comb begin
		out = 0;	// default value to ensure combinational synthesis
		for (i = 0; i < N; i = i + 1) begin
			if (in[i]) begin
				out = i[$clog2(N)-1:0];
				break;
			end
		end
	end
endmodule
