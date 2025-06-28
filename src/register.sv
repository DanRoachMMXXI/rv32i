// Parameterized register to be used between pipeline stages instead of
// needing to write the same always blocks and assign each signal to the next
// stage
module register #(parameter N_BITS) (
	input logic clk,
	input logic reset,
	input logic [N_BITS-1:0] d,
	output logic [N_BITS-1:0] q
	);
	always @ (posedge clk) begin
		if (!reset)
			q <= 0;
		else
			q <= d;
	end
endmodule
