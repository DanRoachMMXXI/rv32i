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
