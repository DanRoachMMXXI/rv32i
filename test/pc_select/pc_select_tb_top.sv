`include "uvm_macros.svh"
import uvm_pkg::*;

import pc_select_pkg::*;

module pc_select_tb_top;
	pc_select_if #(.XLEN(32)) virt_pc_select_if();

	// DUT instantiation
	pc_select #(.XLEN(32)) _pc_select(
		.pc_plus_four(virt_pc_select_if.pc_plus_four),
		.evaluated_next_instruction(virt_pc_select_if.evaluated_next_instruction),
		.predicted_next_instruction(virt_pc_select_if.predicted_next_instruction),
		.evaluated_branch_mispredicted(virt_pc_select_if.evaluated_branch_mispredicted),
		.predicted_branch_predicted_taken(virt_pc_select_if.predicted_branch_predicted_taken),
		.pc_next(virt_pc_select_if.pc_next)
	);

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual pc_select_if)::set(null, "*", "virt_pc_select_if", virt_pc_select_if);
		run_test("pc_select_test");
	end
endmodule
