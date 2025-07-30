`ifndef ALU_PKG_SV
`define ALU_PKG_SV

package alu_pkg;
	`include "uvm_macros.svh"
	import uvm_pkg::*;
	`include "alu_transaction.sv"
	`include "alu_driver.sv"
	`include "alu_monitor.sv"
	`include "alu_scoreboard.sv"
	`include "alu_agent.sv"
	`include "alu_env.sv"
	`include "alu_sequence.sv"
	`include "alu_test.sv"
endpackage

`endif
