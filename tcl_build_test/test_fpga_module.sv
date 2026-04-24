// the only reason the parameter is used is so that I can remember how to set
// these parameters in the TCL build scripts
module test_fpga_module #(parameter N=4) (
	input logic [N-1:0]	switches,
	input logic [N-1:0]	buttons,
	output logic [N-1:0]	led_r,
	output logic [N-1:0]	led_g,
	output logic [N-1:0]	led_b,
	output logic [N-1:0]	leds
);

	always_ff @(posedge |buttons) begin: RED_BUTTON
		if (buttons[3]) begin: CLEAR_RED
			led_r <= 0;
		end: CLEAR_RED
		else if (buttons[0]) begin: SET_RED
			led_r <= switches;
		end: SET_RED
	end: RED_BUTTON

	always_ff @(posedge |buttons) begin: GREEN_BUTTON
		if (buttons[3]) begin: CLEAR_GREEN
			led_g <= 0;
		end: CLEAR_GREEN
		else if (buttons[1]) begin: SET_GREEN
			led_g <= switches;
		end: SET_GREEN
	end: GREEN_BUTTON

	always_ff @(posedge |buttons) begin: BLUE_BUTTON
		if (buttons[3]) begin: CLEAR_BLUE
			led_b <= 0;
		end: CLEAR_BLUE
		else if (buttons[2]) begin: SET_BLUE
			led_b <= switches;
		end: SET_BLUE
	end: BLUE_BUTTON

	assign leds = switches;
endmodule
