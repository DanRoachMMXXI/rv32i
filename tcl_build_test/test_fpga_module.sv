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

	always_ff @(posedge (buttons[3] | buttons[0])) begin: RED_BUTTON
		if (buttons[3]) begin: CLEAR_RED
			led_r <= 0;
		end: CLEAR_RED
		else if (buttons[0]) begin: SET_RED
			led_r <= switches;
		end: SET_RED
	end: RED_BUTTON

	always_ff @(posedge (buttons[3] | buttons[1])) begin: GREEN_BUTTON
		if (buttons[3]) begin: CLEAR_GREEN
			led_g <= 0;
		end: CLEAR_GREEN
		else if (buttons[1]) begin: SET_GREEN
			led_g <= switches;
		end: SET_GREEN
	end: GREEN_BUTTON

	always_ff @(posedge (buttons[3] | buttons[2])) begin: BLUE_BUTTON
		if (buttons[3]) begin: CLEAR_BLUE
			led_b <= 0;
		end: CLEAR_BLUE
		else if (buttons[2]) begin: SET_BLUE
			led_b <= switches;
		end: SET_BLUE
	end: BLUE_BUTTON

	assign leds = switches;

	// RAM MACRO TEST
	// Note: the MEMORY_PRIMITIVE parameter can be used to specify which
	// type of memory is used.  "block" specifies Block RAM.  Other values
	// can be found in the documentation.
	logic		dbiterra;
	logic [31:0]	douta;
	logic		sbiterra;
	logic [5:0]	addra;
	logic		clka;
	logic [31:0]	dina;
	logic		ena;
	logic		injectdbiterra;
	logic		injectsbiterra;
	logic		regcea;
	logic		rsta;
	logic		sleep;
	logic		wea;
	
	// xpm_memory_spram: Single Port RAM
	// Xilinx Parameterized Macro, version 2025.2
	xpm_memory_spram #(
		.ADDR_WIDTH_A(6),              // DECIMAL
		.AUTO_SLEEP_TIME(0),           // DECIMAL
		.BYTE_WRITE_WIDTH_A(32),       // DECIMAL
		.CASCADE_HEIGHT(0),            // DECIMAL
		.ECC_BIT_RANGE("7:0"),         // String
		.ECC_MODE("no_ecc"),           // String
		.ECC_TYPE("none"),             // String
		.IGNORE_INIT_SYNTH(0),         // DECIMAL
		.MEMORY_INIT_FILE("none"),     // String
		.MEMORY_INIT_PARAM("0"),       // String
		.MEMORY_OPTIMIZATION("true"),  // String
		.MEMORY_PRIMITIVE("auto"),     // String
		.MEMORY_SIZE(2048),            // DECIMAL
		.MESSAGE_CONTROL(0),           // DECIMAL
		.RAM_DECOMP("auto"),           // String
		.READ_DATA_WIDTH_A(32),        // DECIMAL
		.READ_LATENCY_A(2),            // DECIMAL
		.READ_RESET_VALUE_A("0"),      // String
		.RST_MODE_A("SYNC"),           // String
		.SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
		.USE_MEM_INIT(1),              // DECIMAL
		.USE_MEM_INIT_MMI(0),          // DECIMAL
		.WAKEUP_TIME("disable_sleep"), // String
		.WRITE_DATA_WIDTH_A(32),       // DECIMAL
		.WRITE_MODE_A("read_first"),   // String
		.WRITE_PROTECT(1)              // DECIMAL
	)
	xpm_memory_spram_inst (
		.dbiterra(dbiterra),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
		.douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
		.sbiterra(sbiterra),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
		.addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
		.clka(clka),                     // 1-bit input: Clock signal for port A.
		.dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
		.ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
					    // are initiated. Pipelined internally.

		.injectdbiterra(injectdbiterra), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
					    // is not available in "decode_only" mode).

		.injectsbiterra(injectsbiterra), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
					    // is not available in "decode_only" mode).

		.regcea(regcea),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
		.rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage. Synchronously resets output port
					    // douta to the value specified by parameter READ_RESET_VALUE_A.

		.sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
		.wea(wea)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input data port dina. 1 bit
					    // wide when word-wide writes are used. In byte-wide write configurations, each bit controls the writing one
					    // byte of dina to address addra. For example, to synchronously write only bits [15-8] of dina when
					    // WRITE_DATA_WIDTH_A is 32, wea would be 4'b0010.
	);

// End of xpm_memory_spram_inst instantiation

endmodule
