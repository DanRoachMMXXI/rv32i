`ifndef INSTRUCTION_DECODE_PKG_SV
`define INSTRUCTION_DECODE_PKG_SV

package instruction_decode_pkg;
	`include "instruction_decode_transaction.sv"
	`include "instruction_decode_sequence.sv"

	`include "instruction_decode_driver.sv"
	`include "instruction_decode_monitor.sv"
	`include "instruction_decode_agent.sv"
	`include "instruction_decode_scoreboard.sv"
	`include "instruction_decode_env.sv"
	`include "instruction_decode_test.sv"
endpackage

`endif
