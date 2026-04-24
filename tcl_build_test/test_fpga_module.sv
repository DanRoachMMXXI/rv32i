module test_fpga_module #(parameter N=4) (
	input logic [N-1:0]	switches,
	output logic [N-1:0]	leds
);
	assign leds = switches;
endmodule
