`include "uvm_macros.svh"
import uvm_pkg::*;

import branch_evaluator_pkg::*;

module branch_evaluator_tb_top;
	branch_evaluator_if #(.XLEN(32)) virt_branch_evaluator_if();

	// DUT instantiation
	branch_evaluator #(.XLEN(32)) branch_evaluator(
		// inputs
		.pc_plus_four(virt_branch_evaluator_if.pc_plus_four),
		.predicted_next_instruction(virt_branch_evaluator_if.predicted_next_instruction),
		.evaluated_branch_target(virt_branch_evaluator_if.evaluated_branch_target),
		.jump(virt_branch_evaluator_if.jump),
		.branch(virt_branch_evaluator_if.branch),
		.branch_if_zero(virt_branch_evaluator_if.branch_if_zero),
		.zero(virt_branch_evaluator_if.zero),
		.branch_prediction(virt_branch_evaluator_if.branch_prediction),
		// outputs
		.next_instruction(virt_branch_evaluator_if.next_instruction),
		.branch_mispredicted(virt_branch_evaluator_if.branch_mispredicted));

	initial begin
		// provide the virtual interface to the driver via uvm_config_db
		uvm_config_db#(virtual branch_evaluator_if)::set(null, "*", "virt_branch_evaluator_if", virt_branch_evaluator_if);
		run_test("branch_evaluator_test");
	end
endmodule
